#' Extract Lemmas
#'
#' @param x List of YAP output
#'
#' @return
#' Lemma form of text x
#' @export 
#'
#' @examples
#' text <- "גנן גידל דגן בגן"
#' token <- "YourAPIToken"
#' yap_list <- yap(text, token)
#' yap_lemmas(yap_list)
yap_lemmas <- function(x){
  return(strsplit(x$lemmas, split = " ", )[[1]])
}
