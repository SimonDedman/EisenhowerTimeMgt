# Complete Google Calendar Authentication Setup
# Run this after creating the service account

#' Complete setup process
setup_google_calendar_complete <- function() {
  
  cat("=== Complete Google Calendar Setup ===\n\n")
  
  # Step 1: Check if jose package is installed
  if (!requireNamespace("jose", quietly = TRUE)) {
    cat("📦 Installing required packages...\n")
    install.packages(c("jose", "httr", "jsonlite"))
  }
  
  # Step 2: Check for service account file
  service_account_file <- ".secrets/google-service-account.json"
  
  if (!file.exists(service_account_file)) {
    cat("❌ Service account file not found!\n")
    cat("Please follow these steps:\n\n")
    
    cat("1. Go to Google Cloud Console:\n")
    cat("   https://console.cloud.google.com/iam-admin/serviceaccounts\n\n")
    
    cat("2. Create a new service account:\n")
    cat("   - Name: 'eisenhower-calendar'\n")
    cat("   - Description: 'Calendar access for time management'\n")
    cat("   - Download JSON key file\n\n")
    
    cat("3. Enable Google Calendar API:\n")
    cat("   https://console.cloud.google.com/apis/library/calendar-json.googleapis.com\n\n")
    
    cat("4. Share your calendars:\n")
    cat("   - In Google Calendar, go to calendar settings\n")
    cat("   - Share with the service account email\n")
    cat("   - Give 'See all event details' permission\n\n")
    
    cat("5. Save the JSON file as:", service_account_file, "\n\n")
    
    return(FALSE)
  }
  
  # Step 3: Test service account authentication
  cat("🧪 Testing service account authentication...\n")
  
  tryCatch({
    source("R/google_calendar_service_account.R")
    
    # Test authentication
    token <- get_service_account_token()
    
    if (!is.null(token)) {
      cat("✅ Service account authentication successful!\n\n")
      
      # Test calendar access
      cat("🧪 Testing calendar access...\n")
      
      calendar_ids <- c(
        "soglpfav6p301t36cj9aqpe79s@group.calendar.google.com", # Admin
        "oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com"  # Marine
      )
      
      result <- extract_calendar_data_service_account(calendar_ids)
      
      if (nrow(result) > 0) {
        cat("🎉 SUCCESS! Google Calendar extraction is working!\n")
        cat("   Events found:", nrow(result), "\n")
        cat("   Tagged events:", sum(result$has_metadata, na.rm = TRUE), "\n")
        
        # Set environment variable for future use
        Sys.setenv(GOOGLE_SERVICE_ACCOUNT = service_account_file)
        
        return(TRUE)
      } else {
        cat("⚠️ No events found. Check calendar sharing permissions.\n")
        return(FALSE)
      }
      
    } else {
      cat("❌ Service account authentication failed\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("❌ Setup error:", e$message, "\n")
    return(FALSE)
  })
}

#' Quick test of current setup
test_current_setup <- function() {
  
  cat("=== Testing Current Google Calendar Setup ===\n\n")
  
  # Test 1: Check service account
  service_account_file <- ".secrets/google-service-account.json"
  if (file.exists(service_account_file)) {
    cat("✅ Service account file found\n")
    
    # Read and show service account email
    tryCatch({
      creds <- jsonlite::fromJSON(service_account_file)
      cat("   Email:", creds$client_email, "\n")
      cat("   Project:", creds$project_id, "\n\n")
    }, error = function(e) {
      cat("⚠️ Could not read service account file\n")
    })
    
  } else {
    cat("❌ Service account file missing:", service_account_file, "\n\n")
  }
  
  # Test 2: Try authentication
  tryCatch({
    source("R/google_calendar_service_account.R")
    token <- get_service_account_token()
    
    if (!is.null(token)) {
      cat("✅ Authentication successful\n")
      
      # Test calendar access
      events <- get_calendar_events_service_account("soglpfav6p301t36cj9aqpe79s@group.calendar.google.com")
      cat("   Admin calendar events:", nrow(events), "\n")
      
      events2 <- get_calendar_events_service_account("oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com")
      cat("   Marine calendar events:", nrow(events2), "\n")
      
    }
  }, error = function(e) {
    cat("❌ Authentication test failed:", e$message, "\n")
  })
}

cat("=== Google Calendar Service Account Setup ===\n")
cat("1. Run: setup_google_calendar_complete()  # Full setup\n")
cat("2. Run: test_current_setup()             # Test existing setup\n\n")

cat("Remember to:\n")
cat("- Create service account in Google Cloud Console\n")
cat("- Enable Google Calendar API\n")
cat("- Share calendars with service account email\n")
cat("- Save JSON key as .secrets/google-service-account.json\n")