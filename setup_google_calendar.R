# Google Calendar Setup Instructions
# Run this script to set up real Google Calendar API access

# Step 1: Enable Google Calendar API
# 1. Go to https://console.cloud.google.com/
# 2. Create a new project or select existing
# 3. Enable "Google Calendar API"
# 4. Go to "Credentials" > "Create Credentials" > "OAuth 2.0 Client ID"
# 5. Application type: "Desktop application"
# 6. Download the JSON credentials file

# Step 2: Set up authentication
library(googledrive)
library(googlesheets4)

# First time setup - this will open browser for authentication
setup_google_calendar_auth <- function(credentials_file = NULL) {
  
  # Create .secrets directory if it doesn't exist
  if (!dir.exists(".secrets")) {
    dir.create(".secrets")
  }
  
  # If you have a credentials JSON file, use it
  if (!is.null(credentials_file) && file.exists(credentials_file)) {
    options(
      gargle_oauth_cache = ".secrets",
      gargle_oauth_email = TRUE
    )
    
    # Set the path to your downloaded credentials
    Sys.setenv(GOOGLE_APPLICATION_CREDENTIALS = credentials_file)
  }
  
  # This will open a browser window for authentication
  googledrive::drive_auth()
  googlesheets4::gs4_auth(token = googledrive::drive_token())
  
  message("✅ Google Calendar authentication complete!")
  message("You can now run the pipeline with real calendar data.")
}

# Step 3: Configure your calendar settings
configure_calendar_settings <- function(calendar_id, 
                                      days_back = 30, 
                                      days_forward = 7,
                                      subcalendar_name = "Admin") {
  
  # Update the calendar configuration in _targets.R
  cat("📝 Updating calendar configuration...\n")
  cat("Calendar ID:", calendar_id, "\n")
  cat("Subcalendar filter:", subcalendar_name, "\n")
  cat("Date range:", days_back, "days back,", days_forward, "days forward\n")
  
  # You'll need to manually update _targets.R with these values
  # Or we can create a config file
  
  config <- list(
    calendar_id = calendar_id,
    days_back = days_back,
    days_forward = days_forward,
    subcalendar_keywords = c(subcalendar_name, "admin", "Admin", "ADMIN", "management", "planning", "review")
  )
  
  saveRDS(config, "calendar_config.rds")
  message("✅ Calendar configuration saved to calendar_config.rds")
  
  return(config)
}

# Step 4: Test calendar connection
test_calendar_connection <- function(calendar_id = "primary") {
  
  library(httr)
  library(jsonlite)
  
  tryCatch({
    # Get the access token
    token <- googledrive::drive_token()
    
    # Simple test API call
    url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", calendar_id)
    
    response <- httr::GET(
      url,
      httr::config(token = token)
    )
    
    if (httr::status_code(response) == 200) {
      content <- httr::content(response, "text", encoding = "UTF-8")
      calendar_info <- jsonlite::fromJSON(content)
      
      message("✅ Successfully connected to calendar:")
      message("   Name: ", calendar_info$summary)
      message("   ID: ", calendar_info$id)
      message("   Time Zone: ", calendar_info$timeZone)
      
      return(TRUE)
    } else {
      message("❌ Failed to connect. Status:", httr::status_code(response))
      message("Check your calendar ID and authentication.")
      return(FALSE)
    }
    
  }, error = function(e) {
    message("❌ Error testing connection: ", e$message)
    return(FALSE)
  })
}

# Usage Examples:
cat("=== Google Calendar Setup Instructions ===\n")
cat("1. First time setup:\n")
cat("   setup_google_calendar_auth()\n")
cat("\n")
cat("2. Configure your calendar:\n")
cat('   configure_calendar_settings(\n')
cat('     calendar_id = "your_admin_calendar_id@group.calendar.google.com",\n')
cat('     subcalendar_name = "Admin"\n')
cat('   )\n')
cat("\n")
cat("3. Test connection:\n")
cat('   test_calendar_connection("your_calendar_id")\n')
cat("\n")
cat("4. Then run the main pipeline:\n")
cat("   source('run_pipeline.R')\n")