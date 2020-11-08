[![Nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/h3rald/fae)

[![Release](https://img.shields.io/github/release/h3rald/fae.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/h3rald/fae/master/LICENSE)

# fae 🧚 Find & Edit Utility v1.0.0

```
  (c) 2020 Fabio Cevasco

  Usage:
    fae <pattern> <replacement> [option1 option2 ...]

  Where:
    <pattern>           A regular expression to search for
    <replacement>      An optional replacement string

  Options:
    -a, --apply         Substitute all occurrences of <pattern> with <replacement> in all files
                        without asking for confirmation.
    -d, --directory     Search in the specified directory (default: .)
    -f, --filter        Specify a regular expression to filter file paths.
    -h, --help          Display this message.
    -i, --insensitive   Case-insensitive matching.
    -r, --recursive     Search directories recursively.
    -s, --silent        Do not display matches.
    -t, --test          Do not perform substitutions, just print results.
    -v, --version       Display the program version.
```
