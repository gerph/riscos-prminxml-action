#!/usr/bin/env bash
set -euo pipefail

FILES_INPUT="${INPUT_FILES:-}"
OUTPUT_DIR="${INPUT_OUTPUT:-}"
LINT_MODE="${INPUT_LINT:-yes}"
PDF_GENERATOR="${INPUT_PDF_GENERATOR:-no}"
FORMAT="${INPUT_FORMAT:-html5+xml}"
CATALOG="${INPUT_CATALOG:-103}"
CREATE_CONTENTS="${INPUT_CREATE_CONTENTS:-}"
CREATE_BODY="${INPUT_CREATE_BODY:-}"
CREATE_CONTENTS_TARGET="${INPUT_CREATE_CONTENTS_TARGET:-}"
POSITION_WITH_NAMES="${INPUT_POSITION_WITH_NAMES:-}"
CSS_BASE="${INPUT_CSS_BASE:-}"
CSS_VARIANT="${INPUT_CSS_VARIANT:-}"
CSS_FILE="${INPUT_CSS_FILE:-}"
OVERRIDE_CHAPTER_NUMBER="${INPUT_OVERRIDE_CHAPTER_NUMBER:-}"
OVERRIDE_DOCGROUP="${INPUT_OVERRIDE_DOCGROUP:-}"
OVERRIDE_DOCGROUP_PART="${INPUT_OVERRIDE_DOCGROUP_PART:-}"
EDGEINDEX="${INPUT_EDGEINDEX:-}"
EDGEINDEX_MAX="${INPUT_EDGEINDEX_MAX:-}"
FRONT_MATTER="${INPUT_FRONT_MATTER:-}"

if [ -z "$FILES_INPUT" ]; then
    echo "Input 'files' is required." >&2
    exit 1
fi

if [ -z "$OUTPUT_DIR" ]; then
    echo "Input 'output' is required." >&2
    exit 1
fi

case "$LINT_MODE" in
    yes|no|quiet) ;;
    *)
        echo "Unsupported lint mode '${LINT_MODE}'." >&2
        exit 1
        ;;
esac

case "$PDF_GENERATOR" in
    prince|weasyprint|no) ;;
    *)
        echo "Unsupported pdf-generator '${PDF_GENERATOR}'." >&2
        exit 1
        ;;
esac

mapfile -t FILES < <(printf '%s\n' "$FILES_INPUT" | tr '[:space:]' '\n' | sed '/^$/d')
if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Input 'files' did not contain any filenames." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

PARAM_ARGS=()
add_param() {
    param_name="$1"
    param_value="$2"

    if [ -n "$param_value" ]; then
        PARAM_ARGS+=(--param "${param_name}=${param_value}")
    fi
}

add_param "create-contents" "$CREATE_CONTENTS"
add_param "create-body" "$CREATE_BODY"
add_param "create-contents-target" "$CREATE_CONTENTS_TARGET"
add_param "position-with-names" "$POSITION_WITH_NAMES"
add_param "css-base" "$CSS_BASE"
add_param "css-variant" "$CSS_VARIANT"
add_param "css-file" "$CSS_FILE"
add_param "override-chapter-number" "$OVERRIDE_CHAPTER_NUMBER"
add_param "override-docgroup" "$OVERRIDE_DOCGROUP"
add_param "override-docgroup-part" "$OVERRIDE_DOCGROUP_PART"
add_param "edgeindex" "$EDGEINDEX"
add_param "edgeindex-max" "$EDGEINDEX_MAX"
add_param "front-matter" "$FRONT_MATTER"

lint_status=0
if [ "$LINT_MODE" != "no" ]; then
    for file in "${FILES[@]}"; do
        echo "+++ Linting ${file}"
        if ! riscos-prminxml -C "$CATALOG" -f lint "$file"; then
            lint_status=1
        fi
    done
fi

if [ "$lint_status" -ne 0 ] && [ "$LINT_MODE" = "yes" ]; then
    echo "PRM-in-XML linting failed." >&2
    exit "$lint_status"
fi

if [ "$lint_status" -ne 0 ]; then
    echo "PRM-in-XML linting reported errors; continuing because lint=quiet."
fi

echo "+++ Generating ${FORMAT} files in ${OUTPUT_DIR}"
riscos-prminxml -C "$CATALOG" -f "$FORMAT" -O "$OUTPUT_DIR" "${PARAM_ARGS[@]}" "${FILES[@]}"

if [ "$PDF_GENERATOR" != "no" ]; then
    if ! command -v "$PDF_GENERATOR" >/dev/null 2>&1; then
        echo "'${PDF_GENERATOR}' PDF generation was requested, but '${PDF_GENERATOR}' is not available." >&2
        exit 1
    fi

    shopt -s nullglob
    html_files=("$OUTPUT_DIR"/*.html "$OUTPUT_DIR"/*.htm)
    shopt -u nullglob

    if [ "${#html_files[@]}" -eq 0 ]; then
        echo "No HTML files were found in ${OUTPUT_DIR}; cannot generate PDFs." >&2
        exit 1
    fi

    for html_file in "${html_files[@]}"; do
        pdf_file="${html_file%.*}.pdf"
        echo "+++ Generating ${pdf_file}"
        if [ "$PDF_GENERATOR" = "prince" ]; then
            prince "$html_file" -o "$pdf_file"
        else
            weasyprint "$html_file" "$pdf_file"
        fi
    done
fi
