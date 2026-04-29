#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PRMINXML_VERSION="1.03.343"
DEFAULT_PRINCE_VERSION="15.4.1"
PRINCE_BASE_VERSION="15.4"

PRMINXML_VERSION="${INPUT_VERSION:-default}"
PRINCE_VERSION="${INPUT_PRINCE_VERSION:-default}"
PDF_GENERATOR="${INPUT_PDF_GENERATOR:-no}"

if [ "$PRMINXML_VERSION" = "default" ]; then
    PRMINXML_VERSION="$DEFAULT_PRMINXML_VERSION"
fi

if [ "$PRINCE_VERSION" = "default" ]; then
    PRINCE_VERSION="$DEFAULT_PRINCE_VERSION"
fi
PRINCE_BASE_VERSION="${PRINCE_VERSION%.*}"

SYSTEM="$(uname -s)"
DISTRO=""
DISTRO_RELEASE=""
PACKAGES_UPDATED="no"

detect_platform() {
    if [ "$SYSTEM" = "Darwin" ]; then
        DISTRO="macOS"
        DISTRO_RELEASE="unknown"
    elif [ -f /etc/lsb-release ]; then
        # shellcheck disable=SC1091
        . /etc/lsb-release
        DISTRO="$(printf '%s' "$DISTRIB_ID" | tr 'A-Z' 'a-z')"
        DISTRO_RELEASE="$DISTRIB_RELEASE"
    elif [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_RELEASE="$VERSION_ID"
    else
        echo "Unrecognised Linux version" >&2
        exit 1
    fi
}

run_root() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

update_packages() {
    if [ "$PACKAGES_UPDATED" = "yes" ]; then
        return
    fi

    if [ "$SYSTEM" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
        run_root apt-get update
        PACKAGES_UPDATED="yes"
    elif [ "$SYSTEM" = "Linux" ] && command -v yum >/dev/null 2>&1; then
        PACKAGES_UPDATED="yes"
    else
        echo "Cannot update package list on ${SYSTEM}" >&2
        exit 1
    fi
}

install_package() {
    command_name="$1"
    package_name="${2:-$1}"

    if command -v "$command_name" >/dev/null 2>&1; then
        return
    fi

    echo "+++ Obtaining ${package_name}"
    if [ "$SYSTEM" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
        update_packages
        run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$package_name"
    elif [ "$SYSTEM" = "Linux" ] && command -v yum >/dev/null 2>&1; then
        case "$package_name" in
            xsltproc) package_name="libxslt" ;;
            libtiff5|libtiff6) package_name="libtiff" ;;
            libpng16-16) package_name="libpng" ;;
            liblcms2-2) package_name="lcms2" ;;
            libfontconfig1) package_name="fontconfig" ;;
            libgif7) package_name="giflib" ;;
            libcurl4) package_name="libcurl" ;;
        esac
        update_packages
        run_root yum install -y "$package_name"
    else
        echo "Cannot install ${package_name} on ${SYSTEM}" >&2
        exit 1
    fi
}

download() {
    url="$1"
    output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$output" "$url"
    else
        wget -q -O "$output" "$url"
    fi
}

install_prminxml() {
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        install_package curl
    fi

    install_package perl
    install_package xsltproc
    install_package xmllint libxml2-utils
    install_package make

    if [ "$PRMINXML_VERSION" = "local" ]; then
        echo "+++ Using local version of riscos-prminxml"
        if ! command -v riscos-prminxml >/dev/null 2>&1; then
            echo "No 'riscos-prminxml' tool is available." >&2
            exit 1
        fi
        return
    fi

    tool_root="${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-/tmp}}/riscos-prminxml/${PRMINXML_VERSION}"
    tool_bin="${tool_root}/riscos-prminxml"
    if [ ! -x "$tool_bin" ]; then
        echo "+++ Obtaining riscos-prminxml ${PRMINXML_VERSION}"
        archive="${RUNNER_TEMP:-/tmp}/prminxml-${PRMINXML_VERSION}.tar.gz"
        url="https://github.com/gerph/riscos-prminxml-tool/releases/download/v${PRMINXML_VERSION}/POSIX-PRMinXML-${PRMINXML_VERSION}.tar.gz"
        rm -rf "$tool_root"
        mkdir -p "$tool_root"
        download "$url" "$archive"
        tar zxf "$archive" -C "$tool_root"
    fi

    export PATH="${tool_root}:$PATH"
    echo "$tool_root" >> "$GITHUB_PATH"
}

install_prince_libraries() {
    if [ "$SYSTEM" != "Linux" ]; then
        return
    fi

    if { [ "$DISTRO" = "ubuntu" ] && [[ "$DISTRO_RELEASE" =~ 24 ]]; } || \
       { [ "$DISTRO" = "debian" ] && [[ "$DISTRO_RELEASE" =~ 12 ]]; }; then
        install_package libtiff6
    else
        install_package libtiff5
    fi

    install_package libgif7
    install_package libpng16-16
    install_package liblcms2-2
    install_package libcurl4
    install_package libfontconfig1

    if [ "${PRINCE_BASE_VERSION%%.*}" -ge 15 ]; then
        if [ "$DISTRO" != "centos" ] || [ "$DISTRO_RELEASE" != "7" ]; then
            install_package libwebpdemux2
        fi
        if [ "$DISTRO" = "ubuntu" ] && [[ "$DISTRO_RELEASE" =~ 22 ]]; then
            install_package libavif13
        elif [ "$DISTRO" = "ubuntu" ] && [[ "$DISTRO_RELEASE" =~ 24 ]]; then
            install_package libavif16
        elif [ "$DISTRO" = "debian" ] && [[ "$DISTRO_RELEASE" =~ 12 ]]; then
            install_package libavif15
        fi
    fi
}

install_prince() {
    if [ "$PDF_GENERATOR" != "prince" ]; then
        return
    fi

    if command -v prince >/dev/null 2>&1; then
        return
    fi

    echo "+++ Obtaining Prince XML ${PRINCE_VERSION}"
    install_package unzip
    prince_root="${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-/tmp}}/prince/${PRINCE_VERSION}-${DISTRO}-${DISTRO_RELEASE}"

    if [ ! -x "${prince_root}/bin/prince" ]; then
        if [ "$SYSTEM" = "Darwin" ]; then
            url="https://www.princexml.com/download/prince-${PRINCE_VERSION}-macos.zip"
            extract_dir="prince-${PRINCE_VERSION}-macos"
            archive="${RUNNER_TEMP:-/tmp}/prince-${PRINCE_VERSION}.zip"
            download "$url" "$archive"
            unzip -q "$archive" -d "${RUNNER_TEMP:-/tmp}"
        elif [ "$SYSTEM" = "Linux" ]; then
            prince_distro="$DISTRO"
            prince_release="$DISTRO_RELEASE"
            prince_arch="amd64"
            if [ "$prince_distro" = "linuxmint" ]; then
                prince_distro="linux-generic"
                prince_release=""
                prince_arch="x86_64"
            elif [ "$prince_distro" = "ubuntu" ]; then
                if [[ "$DISTRO_RELEASE" =~ 22.10 ]]; then
                    prince_release="22.04"
                elif [[ "$DISTRO_RELEASE" =~ 20.10|21.04|21.10 ]]; then
                    prince_release="20.04"
                elif [[ "$DISTRO_RELEASE" =~ 18.10|19.04|19.10 ]]; then
                    prince_release="18.04"
                fi
            elif [ "$prince_distro" = "centos" ]; then
                prince_arch="x86_64"
                if [ "$DISTRO_RELEASE" = "8" ]; then
                    PRINCE_VERSION="14.2"
                    PRINCE_BASE_VERSION="14.2"
                fi
            fi
            extract_dir="prince-${PRINCE_VERSION}-${prince_distro}${prince_release}-${prince_arch}"
            archive="${RUNNER_TEMP:-/tmp}/prince-${PRINCE_VERSION}.tar.gz"
            url="https://www.princexml.com/download/prince-${PRINCE_VERSION}-${prince_distro}${prince_release}-${prince_arch}.tar.gz"
            download "$url" "$archive"
            tar zxf "$archive" -C "${RUNNER_TEMP:-/tmp}"
        else
            echo "Unrecognised OS" >&2
            exit 1
        fi

        printf '\n' | "${RUNNER_TEMP:-/tmp}/${extract_dir}/install.sh" "$prince_root"
    fi

    export PATH="${prince_root}/bin:$PATH"
    echo "${prince_root}/bin" >> "$GITHUB_PATH"
    install_prince_libraries
    prince --version >/dev/null
}

install_weasyprint() {
    if [ "$PDF_GENERATOR" != "weasyprint" ]; then
        return
    fi

    if command -v weasyprint >/dev/null 2>&1; then
        return
    fi

    echo "+++ Obtaining WeasyPrint"
    if [ "$SYSTEM" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
        install_package weasyprint
    elif [ "$SYSTEM" = "Linux" ] && command -v yum >/dev/null 2>&1; then
        install_package weasyprint
    else
        echo "Cannot install WeasyPrint on ${SYSTEM}" >&2
        exit 1
    fi

    weasyprint --version
}

detect_platform
install_prminxml
case "$PDF_GENERATOR" in
    no)
        ;;
    prince)
        install_prince
        ;;
    weasyprint)
        install_weasyprint
        ;;
    *)
        echo "Unsupported pdf-generator '${PDF_GENERATOR}'" >&2
        exit 1
        ;;
esac

echo
echo "+++ Environment configured"
echo "riscos-prminxml: $(command -v riscos-prminxml)"
riscos-prminxml --version
xmllint --version
xsltproc --version
if [ "$PDF_GENERATOR" = "prince" ]; then
    prince --version
elif [ "$PDF_GENERATOR" = "weasyprint" ]; then
    weasyprint --version
fi
