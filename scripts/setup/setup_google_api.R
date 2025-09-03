# Google Calendar API Setup
# Follow these steps to enable proper API access

cat("=== Google Calendar API Setup Instructions ===\n\n")

cat("🔑 STEP 1: Enable Google Calendar API\n")
cat("1. Go to: https://console.cloud.google.com/\n")
cat("2. Create a new project or select existing project\n")
cat("3. Go to 'APIs & Services' > 'Library'\n")
cat("4. Search for 'Google Calendar API' and ENABLE it\n")
cat("5. Go to 'APIs & Services' > 'Credentials'\n\n")

cat("🔑 STEP 2: Create API Credentials\n")
cat("6. Click 'Create Credentials' > 'API Key'\n")
cat("7. Copy the API key (keep it secret!)\n")
cat("8. Optional: Restrict the API key to 'Google Calendar API' only\n\n")

cat("🔑 STEP 3: Set Up Authentication in R\n")
cat("Run the following commands in R:\n\n")

cat("# Set your API key (replace with your actual key)\n")
cat('Sys.setenv(GOOGLE_API_KEY = "your_api_key_here")\n\n')

cat("# Or add to your .Renviron file:\n")
cat('GOOGLE_API_KEY=your_api_key_here\n\n')

cat("🔑 STEP 4: Alternative - Service Account (More Secure)\n")
cat("For production use, consider a Service Account:\n")
cat("1. In Google Cloud Console > 'Credentials'\n")
cat("2. Create Credentials > 'Service Account'\n")
cat("3. Download the JSON credentials file\n")
cat("4. Share your calendars with the service account email\n\n")

# Function to set up API key
setup_google_api_key <- function(api_key = NULL) {
  
  if (is.null(api_key)) {
    api_key <- Sys.getenv("GOOGLE_API_KEY")
    if (api_key == "") {
      cat("❌ No API key found!\n")
      cat("Either:\n")
      cat("1. Run: setup_google_api_key('your_api_key_here')\n")
      cat("2. Or set environment variable: Sys.setenv(GOOGLE_API_KEY = 'your_key')\n")
      cat("3. Or add to .Renviron: GOOGLE_API_KEY=your_key\n")
      return(FALSE)
    }
  } else {
    # Set the API key
    Sys.setenv(GOOGLE_API_KEY = api_key)
  }
  
  cat("✅ Google API Key configured\n")
  cat("API Key (first 10 chars):", substr(Sys.getenv("GOOGLE_API_KEY"), 1, 10), "...\n")
  
  # Test the API key
  test_api_key()
  
  return(TRUE)
}

# Function to test API key
test_api_key <- function() {
  
  library(httr)
  library(jsonlite)
  
  api_key <- Sys.getenv("GOOGLE_API_KEY")
  if (api_key == "") {
    cat("❌ No API key set\n")
    return(FALSE)
  }
  
  cat("🧪 Testing API key with simple calendar list request...\n")
  
  tryCatch({
    # Simple test - list calendars
    url <- "https://www.googleapis.com/calendar/v3/users/me/calendarList"
    
    response <- httr::GET(
      url,
      query = list(key = api_key),
      httr::add_headers(Authorization = paste("Bearer", googledrive::drive_token()$credentials$access_token))
    )
    
    if (httr::status_code(response) == 200) {
      cat("✅ API key working! Calendar access confirmed\n")
      
      content <- httr::content(response, "text", encoding = "UTF-8")
      calendar_list <- jsonlite::fromJSON(content)
      
      if (!is.null(calendar_list$items)) {
        cat("📅 Found", nrow(calendar_list$items), "calendars accessible\n")
        return(TRUE)
      }
    } else {
      cat("❌ API test failed. Status:", httr::status_code(response), "\n")
      cat("Response:", httr::content(response, "text"), "\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("❌ API test error:", e$message, "\n")
    return(FALSE)
  })
}

cat("\n=== Usage Examples ===\n")
cat("# After getting your API key from Google Cloud Console:\n")
cat("setup_google_api_key('AIzaSy...')\n")
cat("\n# Or set permanently in .Renviron file:\n")
cat("GOOGLE_API_KEY=AIzaSy...\n")
cat("\n# Then test your calendars:\n")
cat("source('test_your_calendar.R')\n")