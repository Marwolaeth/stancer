#' Programming Tweets Dataset
#'
#' A collection of 35 fictional tweets about Julia, Python, and R
#' for testing stance analysis.
#'
#' @format A tibble with 35 rows and 1 column:
#' \describe{
#'   \item{tweet}{Text of the tweet}
#'   \item{primary_target}{Suggested target for the stance analysis}
#'   \item{target_type}{Type of the suggested target: either object (one of the programming languages) or claim}
#'   \item{stance}{The text's stance towards the suggested target}
#'   \item{approval}{Likert scale degree to which the text supports the suggested target}
#' }
"programming_tweets"
