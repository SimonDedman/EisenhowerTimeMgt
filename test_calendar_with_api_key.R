# Test Google Calendar with API Key
# This script helps you set up and test the Google Calendar API

library(googledrive)
library(googlesheets4) 
library(httr)
library(jsonlite)

cat("=== Google Calendar API Key Test ===\n\n")

# Step 1: Check for API key
cat("1. Checking for Google API key...\n")
api_key <- Sys.getenv("GOOGLE_API_KEY")

if (api_key == "") {
  cat("❌ No Google API key found!\n\n")
  cat("🔧 SETUP REQUIRED:\n")
  cat("1. Go to: https://console.cloud.google.com/\n")
  cat("2. Enable Google Calendar API\n") 
  cat("3. Create an API Key in Credentials\n")
  cat("4. Run ONE of these:\n\n")
  cat("   Option A - Set in current session:\n")
  cat('   Sys.setenv(GOOGLE_API_KEY = "your_api_key_here")\n\n')
  cat("   Option B - Add to .Renviron file:\n")
  cat('   GOOGLE_API_KEY=your_api_key_here\n\n')
  cat("   Option C - Use setup function:\n")
  cat('   source("setup_google_api.R")\n')
  cat('   setup_google_api_key("your_api_key_here")\n\n')
  cat("Then re-run this test script.\n")
  
  # Offer to create template
  cat("\n💡 ALTERNATIVE: Use CSV/Manual method instead:\n")
  cat('source("R/google_calendar_alternative.R")\n')
  cat('csv_import_method()  # Shows CSV export instructions\n')
  cat('create_manual_data_template()  # Creates manual entry template\n')
  
  stop("Google API key required")
} else {
  cat("✅ API key found (first 10 chars):", substr(api_key, 1, 10), "...\n")
}

# Step 2: Check OAuth authentication
cat("\n2. Checking Google OAuth authentication...\n")
tryCatch({
  token <- googledrive::drive_token()
  if (!is.null(token)) {
    cat("✅ OAuth token found\n")
  } else {
    cat("❌ No OAuth token - running authentication...\n")
    googledrive::drive_auth()
    token <- googledrive::drive_token()
  }
}, error = function(e) {
  cat("❌ OAuth error:", e$message, "\n")
  cat("💡 Run: googledrive::drive_auth() to authenticate\n")
  stop("Authentication required")
})

# Step 3: Test API key with simple request
cat("\n3. Testing API key with calendar list...\n")
tryCatch({
  url <- "https://www.googleapis.com/calendar/v3/users/me/calendarList"
  
  response <- httr::GET(
    url,
    query = list(key = api_key),
    httr::add_headers(Authorization = paste("Bearer", token$credentials$access_token))
  )
  
  if (httr::status_code(response) == 200) {
    cat("✅ API key working! Found accessible calendars\n")
    
    content <- httr::content(response, "text", encoding = "UTF-8") 
    calendar_list <- jsonlite::fromJSON(content)
    
    if (!is.null(calendar_list$items)) {
      cat("📅 Available calendars:\n")
      for (i in 1:min(5, nrow(calendar_list$items))) {
        cal <- calendar_list$items[i, ]
        cat("   -", cal$summary, "(", cal$id, ")\n")
      }
    }
  } else {
    cat("❌ API key test failed. Status:", httr::status_code(response), "\n")
    error_content <- httr::content(response, "text")
    cat("Response:", error_content, "\n")
    stop("API key authentication failed")
  }
  
}, error = function(e) {
  cat("❌ API test error:", e$message, "\n")
  stop("API test failed")
})

# Step 4: Test specific calendar access
cat("\n4. Testing specific calendar access...\n")

# Your calendar IDs
ADMIN_CALENDAR_ID <- "soglpfav6p301t36cj9aqpe79s@group.calendar.google.com"
MARINE_CALENDAR_ID <- "oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com"

test_calendar_access <- function(calendar_id, calendar_name) {
  
  cat("   Testing", calendar_name, "calendar...\n")
  
  tryCatch({
    # URL encode the calendar ID
    encoded_id <- utils::URLencode(calendar_id, reserved = TRUE)
    url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", encoded_id, "/events")
    
    # Parameters for a simple test (last 7 days)
    params <- list(
      timeMin = format(Sys.Date() - 7, "%Y-%m-%dT00:00:00Z"),
      timeMax = format(Sys.Date() + 1, "%Y-%m-%dT23:59:59Z"),
      maxResults = 5,
      key = api_key
    )
    
    response <- httr::GET(
      url,
      query = params,
      httr::add_headers(Authorization = paste("Bearer", token$credentials$access_token))
    )
    
    if (httr::status_code(response) == 200) {
      content <- httr::content(response, "text", encoding = "UTF-8")
      events_data <- jsonlite::fromJSON(content)
      
      event_count <- ifelse(is.null(events_data$items), 0, nrow(events_data$items))
      cat("     ✅", calendar_name, "- Found", event_count, "events\n")
      
      if (event_count > 0) {
        cat("     Sample events:\n")
        for (j in 1:min(2, event_count)) {
          event_title <- events_data$items$summary[j] %||% "No title"
          cat("       -", event_title, "\n")
        }
      }
      
      return(TRUE)
      
    } else {
      cat("     ❌", calendar_name, "- Access failed. Status:", httr::status_code(response), "\n")
      error_content <- httr::content(response, "text") 
      cat("     Error:", error_content, "\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("     ❌", calendar_name, "- Error:", e$message, "\n")
    return(FALSE)
  })
}

admin_ok <- test_calendar_access(ADMIN_CALENDAR_ID, "Admin")
marine_ok <- test_calendar_access(MARINE_CALENDAR_ID, "Marine")

# Step 5: Test the full pipeline function
if (admin_ok || marine_ok) {
  cat("\n5. Testing full pipeline function...\n")
  
  tryCatch({
    source("R/google_calendar_real.R")
    
    result <- extract_real_google_calendar_data(
      calendar_ids = c(ADMIN_CALENDAR_ID, MARINE_CALENDAR_ID),
      days_back = 7,
      days_forward = 7,
      subcalendar_filter = c("Admin", "admin", "Marine", "marine", "management", "planning")
    )
    
    if (nrow(result) > 0) {
      cat("✅ Pipeline function working! Found", nrow(result), "relevant events\n")
      cat("🏷️ Events with #U1I5E7D6h tags:", sum(result$has_metadata, na.rm = TRUE), "\n")
      cat("🎯 Ready to run full pipeline: source('run_pipeline.R')\n")
    } else {
      cat("⚠️ Pipeline returned no events - check date range and filters\n")
    }
    
  }, error = function(e) {
    cat("❌ Pipeline test error:", e$message, "\n")
  })
  
} else {
  cat("\n❌ Calendar access failed - check:\n")
  cat("   - Calendar IDs are correct\n") 
  cat("   - Calendars are shared with your Google account\n")
  cat("   - Google Calendar API is enabled\n")
}

cat("\n=== Test Complete ===\n")
if (admin_ok || marine_ok) {
  cat("🎉 SUCCESS! You can now run: source('run_pipeline.R')\n")
} else {
  cat("🔧 Setup needed - see error messages above\n")
  cat("💡 Alternative: Use CSV export method instead\n")
}

# Helper function
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a