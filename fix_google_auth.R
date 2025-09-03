# Fix Google Calendar Authentication
# Creates a working authentication method for CLI environments

library(httr)
library(jsonlite)

#' Create OAuth token for Google Calendar API
#' This approach works better in CLI environments
setup_google_calendar_auth_fixed <- function() {
  
  api_key <- Sys.getenv("GOOGLE_API_KEY")
  if (api_key == "") {
    stop("Google API key not found. Set GOOGLE_API_KEY environment variable.")
  }
  
  cat("🔧 Setting up Google Calendar authentication...\n")
  
  # Try to use cached credentials first
  if (file.exists(".secrets/google-token.rds")) {
    cat("📁 Found cached Google token\n")
    token_info <- readRDS(".secrets/google-token.rds")
    return(token_info)
  }
  
  # For first time setup, we'll create a simplified token approach
  cat("⚠️ First time setup required:\n")
  cat("1. This will open a browser for Google authentication\n")
  cat("2. Grant calendar access permissions\n")
  cat("3. Token will be cached for future use\n\n")
  
  # Use httr OAuth for Google Calendar
  google_app <- httr::oauth_app(
    appname = "eisenhower-time-mgmt",
    key = "651027622722-4k5ufjf6drnln4uc32ms4vc0dul3n1jl.apps.googleusercontent.com",
    secret = Sys.getenv("GOOGLE_CLIENT_SECRET", "")
  )
  
  # Google Calendar API scope
  scope <- "https://www.googleapis.com/auth/calendar.readonly"
  
  # Create endpoint
  google_endpoints <- httr::oauth_endpoints("google")
  
  # Get token (this should work in RStudio but may fail in pure CLI)
  tryCatch({
    token <- httr::oauth2.0_token(
      endpoint = google_endpoints,
      app = google_app,
      scope = scope,
      cache = ".secrets/google-token"
    )
    
    cat("✅ Google authentication successful!\n")
    return(token)
    
  }, error = function(e) {
    cat("❌ OAuth failed in CLI environment\n")
    cat("💡 Alternative: Use service account or run in RStudio\n")
    return(NULL)
  })
}

#' Alternative: Use API key only approach (more limited but works)
get_calendar_events_api_key_only <- function(calendar_id, api_key) {
  
  # This approach is more limited but doesn't need OAuth
  # It only works with public calendars or service accounts
  
  url <- paste0(
    "https://www.googleapis.com/calendar/v3/calendars/",
    utils::URLencode(calendar_id, reserved = TRUE),
    "/events"
  )
  
  params <- list(
    key = api_key,
    timeMin = format(Sys.Date() - 30, "%Y-%m-%dT00:00:00Z"),
    timeMax = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z"),
    singleEvents = "true",
    orderBy = "startTime",
    maxResults = 250
  )
  
  response <- httr::GET(url, query = params)
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, "text", encoding = "UTF-8")
    events_data <- jsonlite::fromJSON(content)
    return(events_data)
  } else {
    cat("❌ API Key only approach failed. Status:", httr::status_code(response), "\n")
    cat("Response:", httr::content(response, "text"), "\n")
    return(NULL)
  }
}

cat("=== Google Calendar Authentication Fix ===\n")
cat("Run: setup_google_calendar_auth_fixed()\n")
cat("This will attempt OAuth authentication with caching\n")