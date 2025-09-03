# Fix Trello Authentication
# The token works with curl, so let's fix the R implementation

library(httr)
library(jsonlite)

#' Test Trello connection with direct HTTP calls
test_trello_connection_direct <- function() {
  
  api_key <- Sys.getenv("TRELLO_API_KEY")
  token <- Sys.getenv("TRELLO_TOKEN")
  
  if (api_key == "" || token == "") {
    cat("❌ Missing Trello credentials\n")
    return(FALSE)
  }
  
  cat("🧪 Testing Trello connection directly...\n")
  cat("API Key:", substr(api_key, 1, 10), "...\n")
  cat("Token:", substr(token, 1, 20), "...\n")
  
  # Test member info
  url <- "https://api.trello.com/1/members/me"
  
  response <- httr::GET(
    url,
    query = list(
      key = api_key,
      token = token
    )
  )
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    user_info <- jsonlite::fromJSON(content)
    
    cat("✅ Trello connection successful!\n")
    cat("   User:", user_info$fullName %||% user_info$username, "\n")
    cat("   ID:", user_info$id, "\n")
    
    return(TRUE)
    
  } else {
    cat("❌ Trello connection failed\n")
    cat("   Status:", httr::status_code(response), "\n")
    cat("   Response:", httr::content(response, "text"), "\n")
    return(FALSE)
  }
}

#' Get Trello boards using direct HTTP (not trelloR package)
get_trello_boards_direct <- function() {
  
  api_key <- Sys.getenv("TRELLO_API_KEY")
  token <- Sys.getenv("TRELLO_TOKEN")
  
  cat("📋 Fetching Trello boards...\n")
  
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
      
      cat("✅ Found", nrow(boards_df), "Trello boards\n")
      
      # Show first few boards
      for (i in 1:min(5, nrow(boards_df))) {
        status <- ifelse(boards_df$closed[i], "(closed)", "(open)")
        cat("  ", i, ".", boards_df$board_name[i], status, "\n")
      }
      
      return(boards_df)
      
    } else {
      cat("⚠️ No boards found\n")
      return(data.frame())
    }
    
  } else {
    cat("❌ Failed to fetch boards\n")
    cat("   Status:", httr::status_code(response), "\n")
    return(data.frame())
  }
}

#' Get cards from a specific Trello board
get_trello_cards_direct <- function(board_id) {
  
  api_key <- Sys.getenv("TRELLO_API_KEY")
  token <- Sys.getenv("TRELLO_TOKEN")
  
  cat("📝 Fetching cards from board:", board_id, "\n")
  
  url <- paste0("https://api.trello.com/1/boards/", board_id, "/cards")
  
  response <- httr::GET(
    url,
    query = list(
      key = api_key,
      token = token,
      fields = "id,name,desc,due,closed,dateLastActivity,url",
      limit = 1000
    )
  )
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    cards_data <- jsonlite::fromJSON(content)
    
    if (length(cards_data) > 0) {
      cards_df <- data.frame(
        card_id = cards_data$id,
        card_name = cards_data$name,
        description = cards_data$desc %||% "",
        due_date = cards_data$due %||% NA,
        closed = cards_data$closed %||% FALSE,
        url = cards_data$url %||% "",
        board_id = board_id,
        stringsAsFactors = FALSE
      )
      
      cat("   ✅ Found", nrow(cards_df), "cards\n")
      return(cards_df)
      
    } else {
      cat("   ⚠️ No cards found\n")
      return(data.frame())
    }
    
  } else {
    cat("   ❌ Failed to fetch cards\n")
    return(data.frame())
  }
}

# Helper function
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

cat("=== Trello Authentication Fix ===\n")
cat("Test connection: test_trello_connection_direct()\n")
cat("Get boards: get_trello_boards_direct()\n")