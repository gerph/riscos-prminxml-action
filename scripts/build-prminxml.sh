#!/usr/bin/env bash
set -euo pipefail

FILES_INPUT="${INPUT_FILES:-}"
OUTPUT_DIR="${INPUT_OUTPUT:-}"
LINT_MODE="${INPUT_LINT:-yes}"
PDF_GENERATOR="${INPUT_PDF_GENERATOR:-no}"
FORMAT="${INPUT_FORMAT:-html5+xml}"
CATALOG="${INPUT_CATALOG:-103}"

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
    prince|no) ;;
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
riscos-prminxml -C "$CATALOG" -f "$FORMAT" -O "$OUTPUT_DIR" "${FILES[@]}"

if [ "$PDF_GENERATOR" = "prince" ]; then
    if ! command -v prince >/dev/null 2>&1; then
        echo "Prince XML was requested, but 'prince' is not available." >&2
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
        prince "$html_file" -o "$pdf_file"
    done
fi
