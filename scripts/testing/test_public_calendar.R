# Test if making calendars public works with API key only

test_public_calendar_access <- function() {
  library(httr)
  library(jsonlite)
  
  api_key <- Sys.getenv("GOOGLE_API_KEY")
  calendar_ids <- c(
    "soglpfav6p301t36cj9aqpe79s@group.calendar.google.com", # Admin
    "oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com"  # Marine
  )
  
  cat("=== Testing Calendar Visibility ===\n")
  
  for (i in seq_along(calendar_ids)) {
    cal_id <- calendar_ids[i]
    cal_name <- c("Admin", "Marine")[i]
    
    cat("\nTesting", cal_name, "calendar...\n")
    
    # Test calendar metadata access
    url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", 
                  utils::URLencode(cal_id, reserved = TRUE))
    
    response <- httr::GET(url, query = list(key = api_key))
    
    if (httr::status_code(response) == 200) {
      cat("✅", cal_name, "calendar is accessible with API key\n")
      
      # Try to get events
      events_url <- paste0(url, "/events")
      events_response <- httr::GET(
        events_url,
        query = list(
          key = api_key,
          timeMin = format(Sys.Date() - 7, "%Y-%m-%dT00:00:00Z"),
          timeMax = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z"),
          maxResults = 10
        )
      )
      
      if (httr::status_code(events_response) == 200) {
        events_data <- httr::content(events_response)
        cat("   Events accessible:", length(events_data$items %||% 0), "\n")
      } else {
        cat("   ❌ Events require authentication\n")
      }
      
    } else {
      error_content <- httr::content(response)
      cat("❌", cal_name, "calendar error:", httr::status_code(response), "\n")
      if (!is.null(error_content$error$message)) {
        cat("   Message:", error_content$error$message, "\n")
      }
    }
  }
  
  cat("\n=== To make calendars public: ===\n")
  cat("1. Go to Google Calendar settings\n")
  cat("2. Select the calendar\n") 
  cat("3. Go to 'Access permissions'\n")
  cat("4. Check 'Make available to public'\n")
  cat("5. Set to 'See all event details'\n")
}

cat("Run: test_public_calendar_access()\n")