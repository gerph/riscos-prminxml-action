# PRM-in-XML GitHub Action

A GitHub composite action that builds PRM-in-XML documentation pages in
GitHub Actions.

This action obtains the PRM-in-XML tooling, installs the packages needed by
the converter, lints your XML files, and writes generated documentation to an
output directory. It can also generate PDFs with Prince XML when requested.

## What it does

Your repository can contain one or more PRM-in-XML documents. This action:

- Installs the prerequisites needed by `riscos-prminxml`.
- Downloads the requested PRM-in-XML tool version.
- Runs the PRM-in-XML lint process.
- Generates output files, usually HTML and copied XML using `html5+xml`.
- Optionally generates PDF files with Prince XML.

### How it does it

The action wraps `riscos-prminxml`, the PRM-in-XML conversion tool. By default
it renders documents with:

```sh
riscos-prminxml -C 103 -f html5+xml -O output file.xml
```

The default format writes modern HTML and copies the source XML alongside it.
The output directory should be separate from the source directory, because
PRM-in-XML output can overwrite files with matching names.

## Prerequisites

Your repository must contain PRM-in-XML documents, such as `rtc.xml`.

The action is intended for Linux GitHub-hosted runners such as
`ubuntu-latest`. It installs packages with the system package manager, so the
runner must allow normal GitHub Actions package installation.

PDF output is only enabled when `pdf-generator` is set to `prince`. By doing
that, you confirm that your use of Prince XML is covered by an appropriate
licence.

## Usage

Add the action to a workflow step, referencing this repository and the desired
version:

```yaml
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Build PRM-in-XML documentation
        uses: gerph/riscos-prminxml-action@v1
        with:
          files: rtc.xml
          output: output/html
```

### Inputs

| Input | Description | Default |
|---|---|---|
| `files` | Whitespace-separated list of PRM-in-XML files to read | Required |
| `output` | Directory to write generated files to | Required |
| `lint` | `yes` to lint and fail on errors, `no` to skip linting, or `quiet` to report lint errors without failing | `yes` |
| `pdf-generator` | `prince` to generate PDFs with Prince XML, or `no` to skip PDF generation | `no` |
| `prince-version` | `default` for the default Prince XML version, or a version number | `default` |
| `version` | `default` for the default PRM-in-XML version, `local` to use an existing tool, or a version number | `default` |
| `format` | PRM-in-XML output format, such as `html5+xml`, `html+xml`, `html5`, `html`, `stronghelp`, `command`, or `header` | `html5+xml` |
| `catalog` | PRM-in-XML catalog version | `103` |

## Example

A typical workflow builds the documentation and uploads the generated files as
a GitHub Actions artifact:

```yaml
name: PRM-in-XML documentation

on: [push, pull_request]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Build documentation
        uses: gerph/riscos-prminxml-action@v1
        with:
          files: |
            rtc.xml
          output: output/html

      - name: Upload documentation
        uses: actions/upload-artifact@v4
        with:
          name: prminxml-html
          path: output/html
```

### Multiple Files

Use a whitespace-separated list for more than one document:

```yaml
- name: Build documentation
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: |
      docs/kernel.xml
      docs/fileswitch.xml
      docs/wimp.xml
    output: output/html
```

### PDF Generation

To generate PDFs, request Prince XML explicitly:

```yaml
- name: Build documentation and PDFs
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: rtc.xml
    output: output/html
    pdf-generator: prince
```

The action first generates HTML, then runs Prince XML over the generated HTML
files to create matching `.pdf` files in the same output directory.

### Lint Modes

The default `lint: yes` mode fails the workflow if the PRM-in-XML lint process
reports errors.

Use `lint: quiet` if you want lint messages in the log but still want output
generated:

```yaml
- name: Build documentation without failing on lint errors
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: rtc.xml
    output: output/html
    lint: quiet
```

Use `lint: no` only when you need to bypass linting completely.

## Versions

By default the action downloads the default PRM-in-XML release defined by the
action. You can pin a specific PRM-in-XML version:

```yaml
- name: Build with a specific PRM-in-XML version
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: rtc.xml
    output: output/html
    version: 1.03.343
```

For self-hosted runners that already provide `riscos-prminxml`, use
`version: local`.

## Output

With the default `html5+xml` format, each input XML file produces an HTML file
and a copied XML file in the output directory. For example:

```text
output/html/rtc.html
output/html/rtc.xml
```

When PDF generation is enabled, the same directory will also contain:

```text
output/html/rtc.pdf
```
