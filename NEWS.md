# yappr 0.1.0

Initial public release (rewritten from scratch; replaces the earlier `HebrewNLP` / prior `yappr` skeleton).

## Features

- `yap_parse()` / `yap_dep()`: send Hebrew text to a local YAP server and
  receive a tidy, `spacyr`-style data frame with one row per morpheme.
  Supports joint morphological analysis, disambiguation, and optional
  dependency parsing.
- `yap_to_dfm(..., heb_lemma = TRUE)`: one-call Hebrew-aware DFM builder that
  lemmatizes, filters to content POS (`NN`, `NNT`, `NNP`, `VB`, `JJ`, `RB`),
  strips trailing punctuation, and removes Hebrew stopwords via the
  `stopwords` package.
- `as.tokens.yap_parsed()` S3 method for the `quanteda::as.tokens` generic,
  registered at runtime via `registerS3method()` so `quanteda` can stay a
  Suggests-only dependency.
- `yap_start()` / `yap_stop()` / `yap_ping()` / `yap_status()` /
  `yap_available()`: local server lifecycle for Linux and macOS.
- `yap_doctor()` / `yap_install()`: prerequisite check and one-command
  clone + LFS pull + model `.bz2` extraction + `go build` for Linux/macOS.

## Known limitations

- **Windows native YAP does not work.** On Windows, install and run YAP inside
  WSL; `yappr` on Windows R talks to WSL-hosted YAP over loopback with no
  extra setup.
- YAP attaches sentence-final punctuation (e.g. "ספר.") to
  the last morpheme. `yap_to_dfm(heb_lemma = TRUE)` strips it; the
  underlying `as.tokens.yap_parsed()` does not.
- Only the joint endpoint is currently exposed. Raw MA lattices
  (`/yap/heb/ma`) and standalone MD can be added on request.

## yappr 0.1.1 (unreleased)

### Bug fixes

- `yap_to_dfm(heb_lemma = TRUE)` was inadvertently dropping tokens that ended
  with a punctuation character (e.g. a sentence-final `"ספר."`). The
  `tokens_replace(pattern = "[[:punct:]]+$", ..., valuetype = "regex")` call
  matched whole tokens, so the entire token was replaced with `""` instead of
  just the trailing dot being stripped. The fix moves the strip to a plain
  `base::sub()` on the `lemma` / `token` column of the parsed data frame,
  before the tokens object is built. Covered by a regression test.
