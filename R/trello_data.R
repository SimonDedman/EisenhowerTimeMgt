#' Extract Data from Trello Boards
#' 
#' Connects to Trello API and extracts cards/tasks from specified boards
#' Looks for task metadata in card descriptions or comments
#' 
#' @import trelloR
#' @import dplyr
#' @import lubridate
#' @import stringr

library(trelloR)
library(dplyr)
library(lubridate)
library(stringr)

#' Set up Trello authentication
#' 
#' You'll need to:
#' 1. Go to https://trello.com/app-key to get your API key
#' 2. Get your token by visiting the URL provided by this function
#' 3. Store both in environment variables or .Renviron file
setup_trello_auth <- function() {
  # Check for API credentials
  api_key <- Sys.getenv("TRELLO_API_KEY")
  token <- Sys.getenv("TRELLO_TOKEN")
  
  if (api_key == "" || token == "") {
    message("Trello credentials not found in environment variables.")
    message("Please set up:")
    message("1. Go to https://trello.com/app-key to get your API key")
    message("2. Set TRELLO_API_KEY environment variable")
    message("3. Get token from: https://trello.com/1/authorize?expiration=never&scope=read&response_type=token&name=EisenhowerTimeMgt&key=YOUR_API_KEY")
    message("4. Set TRELLO_TOKEN environment variable")
    stop("Missing Trello credentials")
  }
  
  # Set up trelloR authentication
  trelloR::set_trello_creds(key = api_key, token = token)
  
  message("Trello authentication setup complete")
  return(TRUE)
}

#' Get all boards accessible to the user
#' 
#' @return data.frame with board information
get_trello_boards <- function() {
  setup_trello_auth()
  
  boards <- trelloR::get_boards(member = "me")
  
  boards_df <- data.frame(
    board_id = boards$id,
    board_name = boards$name,
    closed = boards$closed,
    url = boards$url,
    stringsAsFactors = FALSE
  )
  
  return(boards_df)
}

#' Get cards from specific Trello boards
#' 
#' @param board_names Vector of board names to extract from (NULL = all boards)
#' @param include_closed Include closed cards (default: FALSE)
#' @return data.frame with card information
get_trello_cards <- function(board_names = NULL, include_closed = FALSE) {
  setup_trello_auth()
  
  # Get all boards
  boards <- get_trello_boards()
  
  # Filter boards if names specified
  if (!is.null(board_names)) {
    boards <- boards %>%
      filter(board_name %in% board_names)
  }
  
  if (nrow(boards) == 0) {
    message("No matching boards found")
    return(data.frame())
  }
  
  # Get cards from each board
  all_cards <- list()
  
  for (i in 1:nrow(boards)) {
    board_id <- boards$board_id[i]
    board_name <- boards$board_name[i]
    
    message(paste("Extracting cards from board:", board_name))
    
    tryCatch({
      cards <- trelloR::get_board_cards(board_id)
      
      if (length(cards) > 0 && nrow(cards) > 0) {
        cards_df <- data.frame(
          card_id = cards$id,
          board_id = board_id,
          board_name = board_name,
          card_name = cards$name,
          description = cards$desc,
          due_date = cards$due,
          closed = cards$closed,
          list_id = cards$idList,
          url = cards$url,
          date_last_activity = cards$dateLastActivity,
          stringsAsFactors = FALSE
        )
        
        all_cards[[i]] <- cards_df
      }
    }, error = function(e) {
      message(paste("Error extracting from board", board_name, ":", e$message))
    })
  }
  
  if (length(all_cards) == 0) {
    message("No cards found in any boards")
    return(data.frame())
  }
  
  # Combine all cards
  combined_cards <- do.call(rbind, all_cards)
  
  # Filter closed cards if requested
  if (!include_closed) {
    combined_cards <- combined_cards %>%
      filter(!closed)
  }
  
  # Convert dates
  combined_cards$due_date <- lubridate::ymd_hms(combined_cards$due_date, quiet = TRUE)
  combined_cards$date_last_activity <- lubridate::ymd_hms(combined_cards$date_last_activity, quiet = TRUE)
  
  return(combined_cards)
}

#' Get list information for cards (to identify project status)
#' 
#' @param board_id Trello board ID
#' @return data.frame with list information
get_board_lists <- function(board_id) {
  setup_trello_auth()
  
  lists <- trelloR::get_board_lists(board_id)
  
  lists_df <- data.frame(
    list_id = lists$id,
    list_name = lists$name,
    closed = lists$closed,
    pos = lists$pos,
    stringsAsFactors = FALSE
  )
  
  return(lists_df)
}

#' Parse task metadata from Trello card descriptions
#' 
#' Looks for patterns like #U1I5E7D6h in card descriptions
#' Also checks for due dates to infer urgency
#' 
#' @param cards_df data.frame of Trello cards
#' @return data.frame with parsed metadata added
parse_trello_metadata <- function(cards_df) {
  if (nrow(cards_df) == 0) {
    return(cards_df)
  }
  
  # Parse metadata from descriptions (same pattern as calendar)
  metadata <- parse_task_metadata(cards_df$description)
  
  # Infer urgency from due dates if not explicitly tagged
  metadata$urgency_inferred <- NA
  metadata$days_until_due <- NA
  
  current_date <- Sys.Date()
  
  for (i in 1:nrow(cards_df)) {
    if (!is.na(cards_df$due_date[i])) {
      days_until <- as.numeric(difftime(as.Date(cards_df$due_date[i]), current_date, units = "days"))
      metadata$days_until_due[i] <- days_until
      
      # Infer urgency based on due date if not tagged
      if (is.na(metadata$urgency[i])) {
        if (days_until <= 1) {
          metadata$urgency_inferred[i] <- 10
        } else if (days_until <= 3) {
          metadata$urgency_inferred[i] <- 8
        } else if (days_until <= 7) {
          metadata$urgency_inferred[i] <- 6
        } else if (days_until <= 14) {
          metadata$urgency_inferred[i] <- 4
        } else {
          metadata$urgency_inferred[i] <- 2
        }
      }
    }
  }
  
  # Use inferred urgency if no explicit urgency
  metadata$urgency_final <- ifelse(is.na(metadata$urgency), metadata$urgency_inferred, metadata$urgency)
  
  # Combine with original data
  result <- cbind(cards_df, metadata)
  
  return(result)
}

#' Main function to extract and process Trello data
#' 
#' @param board_names Vector of board names to extract from (NULL = all boards)
#' @param include_closed Include closed cards
#' @return Processed data frame with cards and metadata
extract_trello_data <- function(board_names = NULL, include_closed = FALSE) {
  message("Extracting Trello data...")
  
  # Get cards
  cards <- get_trello_cards(board_names, include_closed)
  
  if (nrow(cards) == 0) {
    message("No cards found")
    return(data.frame())
  }
  
  # Parse metadata
  cards_with_metadata <- parse_trello_metadata(cards)
  
  # Get list information for context
  boards <- unique(cards_with_metadata[c("board_id", "board_name")])
  all_lists <- list()
  
  for (i in 1:nrow(boards)) {
    tryCatch({
      lists <- get_board_lists(boards$board_id[i])
      lists$board_id <- boards$board_id[i]
      lists$board_name <- boards$board_name[i]
      all_lists[[i]] <- lists
    }, error = function(e) {
      message(paste("Error getting lists for board", boards$board_name[i]))
    })
  }
  
  if (length(all_lists) > 0) {
    combined_lists <- do.call(rbind, all_lists)
    
    # Add list information to cards
    cards_with_metadata <- cards_with_metadata %>%
      left_join(combined_lists[c("list_id", "list_name")], by = "list_id")
  }
  
  message(paste("Found", nrow(cards_with_metadata), "cards from", 
                length(unique(cards_with_metadata$board_name)), "boards"))
  
  return(cards_with_metadata)
}

#' Helper function already defined in google_calendar.R
if (!exists("parse_task_metadata")) {
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
      has_metadata = !is.na(matches[, 1]),
      stringsAsFactors = FALSE
    )
    
    return(result)
  }
}