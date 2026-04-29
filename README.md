# PRM-in-XML GitHub Action

A GitHub composite action that builds PRM-in-XML documentation pages in
GitHub Actions.

This action obtains the PRM-in-XML tooling, installs the packages needed by
the converter, lints your XML files, and writes generated documentation to an
output directory. It can also generate PDFs with Prince XML or WeasyPrint when
requested.

## What it does

Your repository can contain one or more PRM-in-XML documents. This action:

- Installs the prerequisites needed by `riscos-prminxml`.
- Downloads the requested PRM-in-XML tool version.
- Runs the PRM-in-XML lint process.
- Generates output files, usually HTML and copied XML using `html5+xml`.
- Optionally generates PDF files with Prince XML or WeasyPrint.

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

PDF output is only enabled when `pdf-generator` is set to `prince` or
`weasyprint`. If you request Prince XML, you confirm that your use of Prince XML
is covered by an appropriate licence.

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
| `pdf-generator` | `prince` to generate PDFs with Prince XML, `weasyprint` to generate PDFs with WeasyPrint, or `no` to skip PDF generation | `no` |
| `prince-version` | `default` for the default Prince XML version, or a version number | `default` |
| `version` | `default` for the default PRM-in-XML version, `local` to use an existing tool, or a version number | `default` |
| `format` | PRM-in-XML output format, such as `html5+xml`, `html+xml`, `html5`, `html`, `index`, `stronghelp`, `command`, or `header` | `html5+xml` |
| `catalog` | PRM-in-XML catalog version | `103` |
| `log-directory` | Directory for PRM-in-XML log files; empty omits `-L` | Tool default |
| `create-contents` | `yes` or `no`; whether the contents part of the page is generated | Tool default |
| `create-body` | `yes` or `no`; whether the main body of the page is generated | Tool default |
| `create-contents-target` | `yes`, `no`, or a frame target name for contents links | Tool default |
| `position-with-names` | `yes` or `no`; whether diagnostics use longer named paths | Tool default |
| `css-base` | Built-in CSS style name, or `none` | Tool default |
| `css-variant` | Additional CSS variant names separated by spaces, or `none` | Tool default |
| `css-file` | Relative stylesheet filename, or `none` | Tool default |
| `override-chapter-number` | Chapter number to include in titles | Tool default |
| `override-docgroup` | Document group name override | Tool default |
| `override-docgroup-part` | Document group part override | Tool default |
| `edgeindex` | Edge index number to use | Tool default |
| `edgeindex-max` | Number of edge index spaces | Tool default |
| `front-matter` | Front matter type, or `no` | Tool default |

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

To generate PDFs with Prince XML, request it explicitly:

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

To generate PDFs with WeasyPrint instead:

```yaml
- name: Build documentation and PDFs with WeasyPrint
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: rtc.xml
    output: output/html
    pdf-generator: weasyprint
```

The action installs WeasyPrint dependencies, generates HTML, then processes the
generated HTML files into matching `.pdf` files.

### Indexed Documentation

For indexed document sets, set `format: index` and supply exactly one file in
`files`: the index XML file.

```yaml
- name: Build indexed documentation
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: indexed/index.xml
    output: indexed/output
    format: index
    pdf-generator: prince
    log-directory: indexed/logs
```

The index file controls the source and output locations with its `<dirs>`
element:

```xml
<dirs output="output/html"
      index="output/index"
      input="src"
      temp="tmp" />
```

Those paths are interpreted relative to the directory containing the index
file. The action therefore runs the indexed build from that directory. The
`output` input is still required by the action interface, but for `format:
index` the actual generated HTML location comes from `<dirs output="...">`.

If the index contains `<make-filelist/>`, PRM-in-XML writes `filelist.txt` in
the generated HTML directory. When `pdf-generator: prince` is selected, the
action uses that list to create a single PDF:

```sh
prince -l filelist.txt -o indexed.pdf
```

Without `<make-filelist/>`, PDFs are generated individually from the HTML files
in the indexed output directory. WeasyPrint can generate individual PDFs for
indexed output, but filelist-based single-PDF generation is only supported with
Prince XML.

### PRM-in-XML Parameters

The action exposes common PRM-in-XML stylesheet parameters as optional inputs.
When an input is empty, it is not passed to `riscos-prminxml`, so the tool
performs its default operation.

```yaml
- name: Build documentation with custom styling
  uses: gerph/riscos-prminxml-action@v1
  with:
    files: rtc.xml
    output: output/html
    css-base: standard
    css-variant: prm-modern
    override-docgroup: RISC OS Programmer's Reference Manuals
    edgeindex: 1
    edgeindex-max: 4
```

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
