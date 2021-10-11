#' Yap
#'
#' @param x Text of type Character
#' @param token Your YAP API token
#'
#' @return
#' List of YAP output
#' @export
#'
#' @examples

yap <- function(x, token){
  
  Token <- token
  text  <-  x 
  verb<-"POST"
  headers <- c(
    'Content-Type' = "application/json"
  )
  
  data<-paste0('{"data": ','"',text,'"}')
  cat(data)
  url <- paste0('https://www.langndata.com/api/heb_parser?token=',Token)
  
  response  <- httr::VERB(verb=verb,
                          url = url,
                          body=data,
                          httr::add_headers(
                            headers
                            
                          )
  )
  
  if (response$status_code==200){
    a<-httr::content(response)
    return(a)
  }
  else{
    return ("API error")
  }
}
