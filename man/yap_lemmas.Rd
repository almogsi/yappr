% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/yap_lemmas.R
\name{yap_lemmas}
\alias{yap_lemmas}
\title{Extract Lemmas}
\usage{
yap_lemmas(x)
}
\arguments{
\item{x}{List of YAP output}
}
\value{
Lemma form of text x
}
\description{
Extract Lemmas
}
\examples{
text <- "×’× ×Ÿ ×’×™×“×œ ×“×’×Ÿ ×‘×’×Ÿ"
token <- "YourAPIToken"
yap_list <- yap(text, token)
yap_lemmas(yap_list)
}
