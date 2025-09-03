# Test Your Real Google Calendar Connection
# Run this to test access to your Admin calendar

# Load required libraries
library(googledrive)
library(googlesheets4)
library(httr)
library(jsonlite)

# Your calendar IDs
ADMIN_CALENDAR_ID <- "soglpfav6p301t36cj9aqpe79s@group.calendar.google.com"
MARINE_CALENDAR_ID <- "oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com"
CALENDAR_IDS <- c(ADMIN_CALENDAR_ID, MARINE_CALENDAR_ID)

cat("=== Testing Google Calendar Connection ===\n")
cat("Admin Calendar ID: ", ADMIN_CALENDAR_ID, "\n")
cat("Marine Calendar ID:", MARINE_CALENDAR_ID, "\n\n")

# Step 1: Check authentication
cat("1. Checking authentication...\n")
tryCatch({
  token <- googledrive::drive_token()
  if (!is.null(token)) {
    cat("✅ Google authentication token found\n")
  } else {
    cat("❌ No authentication token - run googledrive::drive_auth() first\n")
    stop("Authentication required")
  }
}, error = function(e) {
  cat("❌ Authentication error:", e$message, "\n")
  cat("💡 Run: googledrive::drive_auth() to authenticate\n")
  stop("Authentication failed")
})

# Step 2: Test calendar access
cat("\n2. Testing calendar access...\n")
source("R/google_calendar_real.R")

tryCatch({
  # Test with a small date range first
  time_min <- format(Sys.Date() - 7, "%Y-%m-%dT00:00:00Z")
  time_max <- format(Sys.Date() + 1, "%Y-%m-%dT23:59:59Z")
  
  cat("   Date range:", as.Date(time_min), "to", as.Date(time_max), "\n")
  
  events <- get_real_calendar_events(
    calendar_id = ADMIN_CALENDAR_ID,
    time_min = time_min,
    time_max = time_max,
    subcalendar_filter = c("Admin", "admin")
  )
  
  if (nrow(events) > 0) {
    cat("✅ Successfully retrieved", nrow(events), "events from your Admin calendar\n")
    cat("\n📅 Sample events found:\n")
    for (i in 1:min(3, nrow(events))) {
      cat("  -", events$summary[i], "\n")
      if (!is.na(events$description[i]) && events$description[i] != "") {
        desc_preview <- substr(events$description[i], 1, 50)
        cat("    Description:", desc_preview, "...\n")
      }
    }
    
    # Check for metadata tags
    tagged_events <- grepl("#U\\d+I\\d+E\\d+D\\d+h", events$description)
    cat("\n🏷️  Events with #U1I5E7D6h tags:", sum(tagged_events), "\n")
    
    if (sum(tagged_events) > 0) {
      cat("✅ Found events with your custom metadata format!\n")
    } else {
      cat("💡 No events found with #U1I5E7D6h format tags yet\n")
      cat("   Add tags like #U7I8E6D2h to your calendar event descriptions\n")
    }
    
  } else {
    cat("⚠️  No events found in your Admin calendar for this date range\n")
    cat("   Try extending the date range or check if events exist\n")
  }
  
}, error = function(e) {
  cat("❌ Error accessing calendar:", e$message, "\n")
  cat("💡 Common issues:\n")
  cat("   - Calendar ID might be incorrect\n")
  cat("   - Calendar might not be shared with your Google account\n")
  cat("   - Google Calendar API might need to be enabled\n")
})

# Step 3: Test the full pipeline function with both calendars
cat("\n3. Testing full pipeline function with both calendars...\n")
tryCatch({
  result <- extract_real_google_calendar_data(
    calendar_ids = CALENDAR_IDS,
    days_back = 14,
    days_forward = 7,
    subcalendar_filter = c("Admin", "admin", "Marine", "marine", "management", "planning", "research")
  )
  
  if (nrow(result) > 0) {
    cat("✅ Pipeline function working! Found", nrow(result), "relevant events total\n")
    if ("calendar_name" %in% colnames(result)) {
      breakdown <- table(result$calendar_name)
      for (cal in names(breakdown)) {
        cat("   ", cal, ":", breakdown[cal], "events\n")
      }
    }
    cat("🎯 Ready to run the full pipeline with: source('run_pipeline.R')\n")
  } else {
    cat("⚠️  Pipeline function returned no events\n")
  }
  
}, error = function(e) {
  cat("❌ Pipeline function error:", e$message, "\n")
})

cat("\n=== Test Complete ===\n")
cat("If successful, you can now run: source('run_pipeline.R')\n")
cat("Your Eisenhower matrix will use REAL data from both Admin and Marine calendars!\n")