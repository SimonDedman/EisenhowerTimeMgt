# Google Calendar Service Account Setup
# This approach works better for CLI/automated environments

#' Instructions for creating a Google Service Account
#' 
#' 1. Go to Google Cloud Console: https://console.cloud.google.com/
#' 2. Create a new project or select existing one
#' 3. Enable Google Calendar API
#' 4. Go to "Credentials" > "Create Credentials" > "Service Account"
#' 5. Download the JSON key file
#' 6. Share your calendars with the service account email

setup_service_account_instructions <- function() {
  cat("=== Google Service Account Setup ===\n\n")
  
  cat("Step 1: Create Service Account\n")
  cat("- Go to: https://console.cloud.google.com/iam-admin/serviceaccounts\n")
  cat("- Click 'Create Service Account'\n")
  cat("- Name: 'eisenhower-calendar'\n")
  cat("- Download JSON key file\n\n")
  
  cat("Step 2: Enable APIs\n")
  cat("- Go to: https://console.cloud.google.com/apis/library\n")
  cat("- Enable 'Google Calendar API'\n\n")
  
  cat("Step 3: Share Calendars\n")
  cat("- In Google Calendar, go to calendar settings\n")
  cat("- Share with service account email (ends with @[project].iam.gserviceaccount.com)\n")
  cat("- Give 'See all event details' permission\n\n")
  
  cat("Step 4: Set up credentials\n")
  cat("- Save JSON file as: .secrets/google-service-account.json\n")
  cat("- Set environment variable: GOOGLE_SERVICE_ACCOUNT='.secrets/google-service-account.json'\n\n")
}

#' Use service account for authentication
authenticate_with_service_account <- function() {
  library(httr)
  library(jose)
  
  service_account_file <- Sys.getenv("GOOGLE_SERVICE_ACCOUNT", ".secrets/google-service-account.json")
  
  if (!file.exists(service_account_file)) {
    cat("❌ Service account file not found:", service_account_file, "\n")
    setup_service_account_instructions()
    return(NULL)
  }
  
  # Read service account credentials
  credentials <- jsonlite::fromJSON(service_account_file)
  
  # Create JWT for authentication
  now <- as.numeric(Sys.time())
  
  claim <- list(
    iss = credentials$client_email,
    scope = "https://www.googleapis.com/auth/calendar.readonly",
    aud = "https://oauth2.googleapis.com/token",
    iat = now,
    exp = now + 3600  # 1 hour expiry
  )
  
  # Sign JWT with private key
  jwt <- jose::jwt_encode_sig(claim, jose::read_key(credentials$private_key))
  
  # Exchange JWT for access token
  response <- httr::POST(
    "https://oauth2.googleapis.com/token",
    body = list(
      grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion = jwt
    ),
    encode = "form"
  )
  
  if (httr::status_code(response) == 200) {
    token_data <- httr::content(response)
    cat("✅ Service account authentication successful!\n")
    return(token_data$access_token)
  } else {
    cat("❌ Service account authentication failed\n")
    return(NULL)
  }
}

cat("Run: setup_service_account_instructions()\n")