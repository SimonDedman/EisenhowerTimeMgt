#' Fixed Trello Data Extraction
#' Uses direct HTTP calls instead of trelloR package

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(stringr)

#' Get Trello boards using direct HTTP
get_trello_boards_fixed <- function() {
  
  api_key <- Sys.getenv("TRELLO_API_KEY")
  token <- Sys.getenv("TRELLO_TOKEN")
  
  if (api_key == "" || token == "") {
    stop("Trello credentials not found. Check TRELLO_API_KEY and TRELLO_TOKEN environment variables.")
  }
  
  message("📋 Fetching Trello boards...")
  
  url <- "https://api.trello.com/1/members/me/boards"
  
  response <- httr::GET(
    url,
    query = list(
      key = api_key,
      token = token,
      fields = "id,name,closed,url,desc",
      limit = 100
    )
  )
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    boards_data <- jsonlite::fromJSON(content)
    
    if (length(boards_data) > 0) {
      boards_df <- data.frame(
        board_id = boards_data$id,
        board_name = boards_data$name,
        closed = boards_data$closed %||% FALSE,
        url = boards_data$url %||% "",
        stringsAsFactors = FALSE
      )
      
      message("✅ Found ", nrow(boards_df), " Trello boards")
      return(boards_df)
      
    } else {
      message("⚠️ No boards found")
      return(data.frame())
    }
    
  } else {
    message("❌ Failed to fetch boards. Status: ", httr::status_code(response))
    return(data.frame())
  }
}

#' Get cards from specific Trello boards
get_trello_cards_fixed <- function(board_names = NULL, include_closed = FALSE) {
  
  api_key <- Sys.getenv("TRELLO_API_KEY")
  token <- Sys.getenv("TRELLO_TOKEN")
  
  # Get all boards first
  boards <- get_trello_boards_fixed()
  
  if (nrow(boards) == 0) {
    message("No boards available")
    return(data.frame())
  }
  
  # Filter boards if names specified
  if (!is.null(board_names)) {
    boards <- boards %>%
      filter(board_name %in% board_names)
    
    if (nrow(boards) == 0) {
      message("No boards found matching: ", paste(board_names, collapse = ", "))
      return(data.frame())
    }
  }
  
  all_cards <- list()
  
  # Get cards from each board
  for (i in 1:nrow(boards)) {
    board_id <- boards$board_id[i]
    board_name <- boards$board_name[i]
    
    message("📝 Fetching cards from: ", board_name)
    
    url <- paste0("https://api.trello.com/1/boards/", board_id, "/cards")
    
    response <- httr::GET(
      url,
      query = list(
        key = api_key,
        token = token,
        fields = "id,name,desc,due,closed,dateLastActivity,url,idList",
        limit = 1000
      )
    )
    
    if (httr::status_code(response) == 200) {
      content <- httr::content(response, as = "text", encoding = "UTF-8")
      cards_data <- jsonlite::fromJSON(content)
      
      if (length(cards_data) > 0) {
        cards_df <- data.frame(
          card_id = cards_data$id,
          board_id = board_id,
          board_name = board_name,
          card_name = cards_data$name,
          description = cards_data$desc %||% "",
          due_date = cards_data$due %||% NA,
          closed = cards_data$closed %||% FALSE,
          list_id = cards_data$idList %||% "",
          url = cards_data$url %||% "",
          date_last_activity = cards_data$dateLastActivity %||% NA,
          stringsAsFactors = FALSE
        )
        
        # Filter closed cards if requested
        if (!include_closed) {
          cards_df <- cards_df %>%
            filter(!closed)
        }
        
        all_cards[[i]] <- cards_df
        message("   ✅ ", nrow(cards_df), " cards")
        
      } else {
        message("   ⚠️ No cards in ", board_name)
      }
      
    } else {
      message("   ❌ Failed to fetch cards from ", board_name)
    }
  }
  
  if (length(all_cards) == 0) {
    message("No cards found in any boards")
    return(data.frame())
  }
  
  # Combine all cards
  combined_cards <- do.call(rbind, all_cards[!sapply(all_cards, is.null)])
  
  # Convert dates
  combined_cards$due_date <- lubridate::ymd_hms(combined_cards$due_date, quiet = TRUE)
  combined_cards$date_last_activity <- lubridate::ymd_hms(combined_cards$date_last_activity, quiet = TRUE)
  
  return(combined_cards)
}

#' Parse Trello metadata and infer urgency from due dates
parse_trello_metadata_fixed <- function(cards_df) {
  
  if (nrow(cards_df) == 0) {
    return(cards_df)
  }
  
  # Parse metadata from descriptions (reuse existing function)
  source("R/google_calendar.R")
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
        if (days_until <= 0) {
          metadata$urgency_inferred[i] <- 10  # Overdue
        } else if (days_until <= 1) {
          metadata$urgency_inferred[i] <- 9   # Due tomorrow
        } else if (days_until <= 3) {
          metadata$urgency_inferred[i] <- 7   # Due this week
        } else if (days_until <= 7) {
          metadata$urgency_inferred[i] <- 5   # Due next week
        } else if (days_until <= 14) {
          metadata$urgency_inferred[i] <- 3   # Due in 2 weeks
        } else {
          metadata$urgency_inferred[i] <- 1   # Due later
        }
      }
    }
  }
  
  # Use inferred urgency if no explicit urgency
  metadata$urgency_final <- ifelse(is.na(metadata$urgency), metadata$urgency_inferred, metadata$urgency)
  
  # Set default importance if not specified
  metadata$importance_final <- ifelse(is.na(metadata$importance), 5, metadata$importance)
  
  # Set default enjoyment if not specified
  metadata$enjoyment_final <- ifelse(is.na(metadata$enjoyment), 5, metadata$enjoyment)
  
  # Use tagged duration or default to 2 hours
  metadata$duration_final <- ifelse(is.na(metadata$duration_tagged), 2, metadata$duration_tagged)
  
  # Combine with original data
  result <- cbind(cards_df, metadata)
  
  return(result)
}

#' Main function to extract and process Trello data with fixed authentication
extract_trello_data_fixed <- function(board_names = NULL, include_closed = FALSE) {
  
  message("🚀 Extracting Trello data (FIXED METHOD)...")
  
  # Get cards
  cards <- get_trello_cards_fixed(board_names, include_closed)
  
  if (nrow(cards) == 0) {
    message("No cards found")
    return(data.frame())
  }
  
  # Parse metadata
  cards_with_metadata <- parse_trello_metadata_fixed(cards)
  
  message("📊 Found ", nrow(cards_with_metadata), " cards total")
  
  # Show breakdown by board
  if ("board_name" %in% colnames(cards_with_metadata)) {
    board_breakdown <- table(cards_with_metadata$board_name)
    message("📋 Cards by board:")
    for (board in names(board_breakdown)) {
      message("   ", board, ": ", board_breakdown[board], " cards")
    }
  }
  
  # Show metadata stats
  tagged_count <- sum(cards_with_metadata$has_metadata, na.rm = TRUE)
  due_count <- sum(!is.na(cards_with_metadata$due_date))
  
  message("🏷️ Cards with #U1I5E7D6h tags: ", tagged_count)
  message("📅 Cards with due dates: ", due_count)
  
  return(cards_with_metadata)
}

# Helper function
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a