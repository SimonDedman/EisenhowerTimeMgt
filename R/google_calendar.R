library(dplyr)
library(lubridate)
library(readr)
library(stringr)

#' Parse task metadata from descriptions
#' 
#' Looks for patterns like #U1I5E7D6h in event descriptions
#' U = Urgency, I = Importance, E = Enjoyment, D = Duration
#'
#' @param description Character vector of event descriptions
#' @return data.frame with parsed metadata
parse_task_metadata <- function(description) {
  if (is.null(description) || all(is.na(description))) {
    return(data.frame(
      urgency = NA,
      importance = NA,
      enjoyment = NA,
      duration_tagged = NA,
      has_metadata = FALSE
    ))
  }
  
  # Pattern to match #U[digit]I[digit]E[digit]D[digit]h
  pattern <- "#U(\\d+)I(\\d+)E(\\d+)D(\\d+)h"
  
  # Extract matches
  matches <- stringr::str_match(description, pattern)
  
  # Create result data frame
  result <- data.frame(
    urgency = as.numeric(matches[, 2]),
    importance = as.numeric(matches[, 3]),
    enjoyment = as.numeric(matches[, 4]),
    duration_tagged = as.numeric(matches[, 5]),
    has_metadata = !is.na(matches[, 1])
  )
  
  return(result)
}

#' Helper function for null coalescing
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Extract manual Trello data
extract_manual_trello_data <- function(file_path = "data/manual_trello_data.csv") {
  
  if (!file.exists(file_path)) {
    message("❌ Manual Trello file not found: ", file_path)
    return(data.frame())
  }
  
  message("📁 Reading manual Trello data...")
  manual_data <- readr::read_csv(file_path, show_col_types = FALSE)
  
  # Process the manual data to match Trello structure
  processed <- manual_data %>%
    mutate(
      card_id = paste0("manual_", row_number()),
      due_date = lubridate::ymd(due_date),
      closed = FALSE,
      date_last_activity = Sys.Date()
    ) %>%
    select(card_id, board_name, card_name, description, due_date, closed, list_name, date_last_activity)
  
  # Parse metadata
  metadata <- parse_task_metadata(processed$description)
  
  result <- cbind(processed, metadata)
  
  message("✅ Processed ", nrow(result), " manual Trello cards")
  message("🏷️  Cards with #U1I5E7D6h tags: ", sum(result$has_metadata, na.rm = TRUE))
  
  return(result)
}