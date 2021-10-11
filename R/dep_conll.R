#' Dependency Tree CoNLL
#'
#' @param x List of YAP output
#'
#' @return
#' tibble of CoNLL dependency tree 
#'
#' @export 
#'
#' @examples
#' text <- "גנן גידל דגן בגן"
#' token <- "YourAPIToken"
#' yap_list <- yap(text, token)
#' dep_conll(yap_list)
dep_conll <- function(x){
  tbl <- tibble::as_tibble(t(tibble::as_tibble(x$dep_tree)), .name_repair = "minimal")
  names(tbl) <- tolower(c("ID", "FORM", "LEMMA", "CPOSTAG", "POSTAG",
                          "FEATS", "HEAD", "DEPREL", "PHEAD", "PDEPREL"))
  return(tbl %>% 
           dplyr::mutate(dplyr::across(dplyr::everything(), unlist)))
}
