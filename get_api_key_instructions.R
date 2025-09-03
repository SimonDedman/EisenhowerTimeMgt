# Instructions to get your Google Calendar API Key
# You have the OAuth Client ID, but also need an API Key

cat("=== Getting Your Google Calendar API Key ===\n\n")

cat("✅ You already have OAuth Client ID:\n")
cat("   651027622722-4k5ufjf6drnln4uc32ms4vc0dul3n1jl.apps.googleusercontent.com\n\n")

cat("❌ You still need an API Key. Here's how to get it:\n\n")

cat("🔧 STEP-BY-STEP INSTRUCTIONS:\n\n")

cat("1. Go to Google Cloud Console:\n")
cat("   https://console.cloud.google.com/\n\n")

cat("2. Make sure you're in the same project where you created the OAuth client\n")
cat("   (The project should contain your OAuth client ID starting with 651027622722)\n\n")

cat("3. In the left sidebar, go to:\n")
cat("   'APIs & Services' > 'Credentials'\n\n")

cat("4. Click the '+ CREATE CREDENTIALS' button at the top\n\n")

cat("5. Select 'API Key' (NOT OAuth client ID - you already have that)\n\n")

cat("6. Copy the API key that appears (it will look like: AIzaSy...)\n\n")

cat("7. OPTIONAL but recommended: Click 'RESTRICT KEY'\n")
cat("   - Under 'API restrictions', select 'Restrict key'\n")
cat("   - Choose 'Google Calendar API' only\n")
cat("   - Click 'Save'\n\n")

cat("8. Set your API key in R:\n")
cat('   Sys.setenv(GOOGLE_API_KEY = "AIzaSy_your_actual_api_key_here")\n\n')

cat("9. Test your setup:\n")
cat('   source("test_calendar_with_api_key.R")\n\n')

cat("🔐 SECURITY NOTE:\n")
cat("- OAuth Client ID: Used for user authentication (can be public)\n") 
cat("- API Key: Used for API access (keep this secret!)\n\n")

cat("💡 ALTERNATIVE IF API KEY SETUP IS TOO COMPLEX:\n")
cat("Use the CSV export method instead:\n")
cat('source("R/google_calendar_alternative.R")\n')
cat('csv_import_method()  # Shows how to export your calendars to CSV\n\n')

# Function to test if user has both credentials
test_credentials_status <- function() {
  cat("=== Current Credentials Status ===\n")
  
  oauth_id <- "651027622722-4k5ufjf6drnln4uc32ms4vc0dul3n1jl.apps.googleusercontent.com"
  api_key <- Sys.getenv("GOOGLE_API_KEY")
  
  cat("OAuth Client ID: ✅ HAVE (", oauth_id, ")\n")
  
  if (api_key != "") {
    cat("API Key: ✅ HAVE (", substr(api_key, 1, 10), "...)\n")
    cat("🎉 Ready to test! Run: source('test_calendar_with_api_key.R')\n")
  } else {
    cat("API Key: ❌ MISSING\n")
    cat("🔧 Follow the instructions above to get your API key\n")
  }
}

cat("📋 CHECK YOUR STATUS:\n")
cat("Run: test_credentials_status()\n")