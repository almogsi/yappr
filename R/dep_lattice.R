#' Dependency Tree Lattice
#'
#' @param x List of YAP output
#'
#' @return
#' tibble of Lattice dependency tree 
#'
#' @export
#'
#' @examples
#' text <- "גנן גידל דגן בגן"
#' token <- "YourAPIToken"
#' yap_list <- yap(text, token)
#' dep_lattice(yap_list)
dep_lattice <- function(x){
  tbl <- tibble::as_tibble(t(tibble::as_tibble(x$md_lattice)), .name_repair = "minimal")
  names(tbl) <- tolower(c("empty", "gen",
                          "lemma", "num",
                          "num_2", "num_last",
                          "num_s_p", "per", "pos", "pos_2",
                          "tense", "word"))
  return(dplyr::`%>%`(tbl, 
           dplyr::mutate(dplyr::across(dplyr::everything(), unlist))))
}
