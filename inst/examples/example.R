# yappr example: Hebrew text from parse to DFM --------------------------------
#
# Prerequisite: a running YAP server on http://localhost:8000.
# On Linux/macOS:   yap_install() then yap_start(path)
# On Windows:       build YAP inside WSL (see README), leave `./yap api`
#                   running in the Ubuntu terminal.

library(yappr)
library(quanteda)

texts <- c(
  review1 = "\u05D4\u05E1\u05E4\u05E8 \u05D4\u05D9\u05D4 \u05DE\u05E8\u05EA\u05E7 \u05D1\u05DE\u05D9\u05D5\u05D7\u05D3, \u05D0\u05DA \u05D4\u05E1\u05D9\u05D5\u05DD \u05D4\u05D9\u05D4 \u05DE\u05D0\u05DB\u05D6\u05D1.",
  review2 = "\u05D0\u05D4\u05D1\u05EA\u05D9 \u05D0\u05EA \u05D4\u05D3\u05DE\u05D5\u05D9\u05D5\u05EA \u05D5\u05D0\u05EA \u05D4\u05E2\u05DC\u05D9\u05DC\u05D4, \u05DE\u05DE\u05DC\u05D9\u05E5 \u05D1\u05D7\u05D5\u05DD!",
  review3 = "\u05DC\u05D0 \u05D4\u05E6\u05DC\u05D7\u05EA\u05D9 \u05DC\u05D4\u05EA\u05D7\u05D1\u05E8 \u05DC\u05E1\u05D2\u05E0\u05D5\u05DF \u05D4\u05DB\u05EA\u05D9\u05D1\u05D4."
)

# Full parse \u2192 morpheme table
parsed <- yap_parse(texts, dependency = TRUE)
head(parsed, 15)

# Lemma-based tokens, manually
toks <- as.tokens(parsed, use_lemma = TRUE, remove_punct = TRUE)
toks

# One-shot Hebrew-lemma DFM (lemma + content-POS + stopwords + punct strip)
d <- yap_to_dfm(texts, heb_lemma = TRUE)
topfeatures(d, 10)

# Or skip the whole pipeline and just get raw lemmas as tokens
yap_to_dfm(texts, heb_lemma = FALSE, use_lemma = TRUE)
