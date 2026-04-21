# yappr

**Hebrew NLP in R via YAP, in the `quanteda` workflow.**

`yappr` is a local-first R client for [YAP](https://github.com/OnlpLab/yap) — the ONLP Lab's open-source morphological analyzer, disambiguator, and dependency parser for Hebrew. Everything runs on your own machine over loopback HTTP; no text leaves your computer.

Output is a tidy, [`spacyr`](https://github.com/quanteda/spacyr)-style data frame that drops into a `quanteda::tokens` object or a Hebrew-aware `dfm` in one call.

---

## Installation

### 1. Install the R package

```r
# install.packages("remotes")
remotes::install_github("almogsi/yappr")

# also recommended
install.packages(c("quanteda", "quanteda.textstats", "stopwords", "processx"))
```

### 2. Install YAP

> **Windows users: use WSL.** As of 2026, upstream YAP built natively on Windows does not produce a working Hebrew tokenizer regardless of Go version, dependency pins, or path. WSL builds work correctly and `yappr` on Windows R talks to WSL-hosted YAP over loopback with zero extra setup. Scroll to "Windows (via WSL2)" below.

#### Prerequisites (Linux / macOS / WSL2 Ubuntu)

| tool     | minimum    | notes                                                                 |
|----------|------------|-----------------------------------------------------------------------|
| `git`    | any recent | just for cloning                                                       |
| `go`     | 1.17+      | Ubuntu's `apt install golang-go` default is new enough. No need to install a specific version. |
| `bunzip2`| —          | decompresses YAP's shipped models. On Ubuntu: `apt install bzip2`.    |
| Git LFS  | —          | **not required.** YAP ships models as `.bz2` files in the git tree, not via LFS. |

#### Linux / macOS (or WSL2 Ubuntu on Windows)

Copy this whole block into a terminal:

```bash
sudo apt update && sudo apt install -y golang-go git bzip2

git clone https://github.com/OnlpLab/yap.git ~/yap
cd ~/yap
rm -rf vendor                                    # YAP's vendor/ is stale; dropping it is required
bunzip2 -k data/*.bz2                            # decompress the shipped Hebrew models
go get github.com/gonuts/commander@91a7f0a       # the one version pin that matters (see below)
go mod tidy
go build .
./yap api                                        # server listens on http://localhost:8000
```

`./yap api` blocks and prints log lines as it loads models (~30 s). Leave the terminal open. `Ctrl+C` to stop.

**Why the commander pin?** Modern `gonuts/commander` expects stdlib `flag.FlagSet`, but YAP's source imports `"github.com/gonuts/flag"` and passes `gonuts/flag.FlagSet` into commander's struct. Commit `91a7f0a` is the last commander version that still uses `gonuts/flag`, and it's the single pin that turns a broken build into a working one. No other dependency needs pinning on modern Go; `go mod tidy` handles the rest.

#### Windows (via WSL2)

Three steps — don't stop after step 1.

**Step 1 — in Windows PowerShell (one-time):**

```powershell
wsl --install
```

This installs the WSL runtime + Ubuntu. Windows may reboot. When it finishes, an Ubuntu terminal opens; set a Linux username/password when prompted. If it doesn't open on its own, launch "Ubuntu" from the Start menu.

`wsl --install` alone does **not** build YAP. It only gets Linux onto your machine.

**Step 2 — in the Ubuntu terminal (one-time, ~5–10 min):**

Paste the Linux block above into the Ubuntu prompt. On Ubuntu 22.04/24.04 (what `wsl --install` gives you), `apt install golang-go` installs Go 1.22, which is fine.

At the end, `./yap api` is running and blocking. Leave the Ubuntu window open.

**Step 3 — in Windows R:**

```r
library(yappr)
yap_ping()                    # TRUE
```

WSL2 forwards `localhost` to Windows, so `yappr` talks to the WSL-hosted YAP over loopback with no extra configuration.

**Next session (reboot, next day, etc.):**

- Open Ubuntu from the Start menu.
- `cd ~/yap && ./yap api`
- Use R as usual.

---

## Quick start

```r
library(yappr)
library(quanteda)

docs <- c(
  doc1 = "הילדים הלכו לבית הספר.",
  doc2 = "היום יום יפה ואנחנו שמחים."
)

# Full parse: one row per morpheme, with dependency arcs
parsed <- yap_parse(docs, dependency = TRUE)
parsed

# One-shot Hebrew-aware DFM:
#   lemma + content POS filter + punct strip + Hebrew stopwords removed
d <- yap_to_dfm(docs, heb_lemma = TRUE)
topfeatures(d, 10)

# Manual quanteda path for more control
toks <- as.tokens(parsed, use_lemma = TRUE, remove_punct = TRUE)
dfm(toks)
```

---

## What you get back

`yap_parse()` returns a data frame with one row per **morpheme** (YAP segments clitics — definiteness, prepositions, possessive suffixes — into separate morphemes):

| column            | meaning                                                   |
|-------------------|-----------------------------------------------------------|
| `doc_id`          | document identifier                                       |
| `sentence_id`     | sentence index within the document                        |
| `token_id`        | morpheme index within the sentence                        |
| `token`           | surface form of the morpheme                              |
| `lemma`           | dictionary form                                           |
| `pos`             | coarse POS tag (YAP's CPOSTAG)                           |
| `xpos`            | fine-grained POS                                          |
| `feats`           | morphological features                                    |
| `head_token_id` † | syntactic head within the sentence                        |
| `deprel` †        | dependency relation to the head                           |

† only when `dependency = TRUE`.

The shape mirrors `spacyr::spacy_parse()` and `udpipe::udpipe_annotate()`.

---

## `heb_lemma` pipeline

`yap_to_dfm(text, heb_lemma = TRUE)` runs the full Hebrew-aware path in one call:

1. `yap_parse(text)` — morpho-syntactic analysis.
2. Switch to the `lemma` column so `הלכו` collapses to `הלך`, etc.
3. Drop morphemes whose POS isn't a content tag (`NN`, `NNT`, `NNP`, `VB`, `JJ`, `RB` by default).
4. Strip trailing punctuation that YAP attaches to sentence-final morphemes (e.g. `ספר.` → `ספר`).
5. Remove Hebrew stopwords via the `stopwords` package, if installed.

Any step can be toggled:

```r
yap_to_dfm(docs, heb_lemma = TRUE)                          # default
yap_to_dfm(docs, heb_lemma = TRUE, remove_stopwords = FALSE)
yap_to_dfm(docs, heb_lemma = TRUE, pos_keep = c("NN", "VB")) # nouns + verbs
yap_to_dfm(docs, heb_lemma = FALSE, use_lemma = TRUE)        # bare lemmas
```

---

## Design notes

- **Local-first.** `yappr` talks to YAP over `http://localhost:8000`. On Windows the "server" runs inside WSL; WSL2's automatic localhost forwarding means R on Windows uses loopback transparently.
- **Auto-tokenization before transport.** YAP's HTTP endpoint silently returns `{}` for space-separated input — it requires one token per line with a trailing blank line. `yap_parse()` pre-tokenizes on whitespace by default; pass `pre_tokenized = TRUE` if you already have YAP wire format.
- **Morphemes, not orthographic tokens.** Hebrew clitics (ה, ל, ב, ש, ו, ...) get separate rows. For bag-of-words work you usually want `use_lemma = TRUE` so inflectional variants collapse while clitics stay informative.

---

## Functions

| function                     | purpose                                             |
|------------------------------|-----------------------------------------------------|
| `yap_parse()` / `yap_dep()`  | joint MA + MD (+ optional dependency) parsing       |
| `yap_to_dfm()`               | one-step text → Hebrew-aware DFM                    |
| `yap_to_tokens()`            | non-S3 wrapper to build `tokens` from `yap_parsed`  |
| `as.tokens()` (S3)           | quanteda integration on `yap_parsed` objects        |
| `yap_start()` / `yap_stop()` | launch / terminate a local YAP server (Linux/macOS) |
| `yap_ping()` / `yap_status()`| liveness checks                                     |
| `yap_doctor()`               | check prerequisites before installing YAP           |
| `yap_install()`              | clone + LFS + decompress + build YAP (Linux/macOS)  |

On Windows, build YAP inside WSL and skip `yap_install()` / `yap_start()`; `yap_parse()` is all you need.

---

## Citation

If you use `yappr` for research, please cite YAP:

> More, A., Seker, A., Basmova, V., & Tsarfaty, R. (2019). Joint Transition-Based Models for Morpho-Syntactic Parsing: Parsing Strategies for MRLs and a Case Study from Modern Hebrew. *Transactions of the Association for Computational Linguistics*, 7, 33–48.

---

## License

MIT © 2026 Almog Simchon. See [LICENSE](./LICENSE.md). YAP itself is Apache 2.0 licensed; see the [YAP repository](https://github.com/OnlpLab/yap) for details.
