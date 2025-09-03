#' Google Calendar Service Account Implementation
#' Uses service account authentication for CLI compatibility

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(stringr)
library(openssl)

#' Authenticate using Google Service Account
get_service_account_token <- function() {
  
  service_account_file <- Sys.getenv("GOOGLE_SERVICE_ACCOUNT", ".secrets/google-service-account.json")
  
  if (!file.exists(service_account_file)) {
    cat("❌ Service account file not found:", service_account_file, "\n")
    cat("💡 Run: source('setup_google_service_account.R'); setup_service_account_instructions()\n")
    return(NULL)
  }
  
  cat("🔑 Using service account authentication...\n")
  
  tryCatch({
    # Check if jose package is available
    if (!requireNamespace("jose", quietly = TRUE)) {
      stop("jose package required: install.packages('jose')")
    }
    
    # Read service account credentials
    credentials <- jsonlite::fromJSON(service_account_file)
    
    # Create JWT claim using jose's jwt_claim structure
    now <- as.numeric(Sys.time())
    
    # Use jose::jwt_claim to create proper claim object
    claim <- jose::jwt_claim(
      iss = credentials$client_email,
      scope = "https://www.googleapis.com/auth/calendar.readonly",
      aud = "https://oauth2.googleapis.com/token",
      iat = now,
      exp = now + 3600  # 1 hour expiry
    )
    
    # Read private key using openssl
    private_key <- openssl::read_key(credentials$private_key)
    
    # Create JWT token
    jwt <- jose::jwt_encode_sig(claim, private_key)
    
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
      cat("❌ Service account authentication failed:", httr::status_code(response), "\n")
      error_content <- httr::content(response, as = "text")
      cat("   Error:", substr(error_content, 1, 200), "\n")
      return(NULL)
    }
    
  }, error = function(e) {
    cat("❌ Service account error:", e$message, "\n")
    cat("💡 Make sure jose package is installed and service account JSON is valid\n")
    return(NULL)
  })
}


#' Get Google Calendar events using service account
get_calendar_events_service_account <- function(calendar_id, 
                                               time_min = format(Sys.Date() - 30, "%Y-%m-%dT00:00:00Z"),
                                               time_max = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z")) {
  
  # Get service account token
  access_token <- get_service_account_token()
  
  if (is.null(access_token)) {
    return(data.frame())
  }
  
  cat("📅 Fetching events from:", substr(calendar_id, 1, 20), "...\n")
  
  # Build API URL
  encoded_id <- utils::URLencode(calendar_id, reserved = TRUE)
  url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", encoded_id, "/events")
  
  # Make API call with service account token
  response <- httr::GET(
    url,
    query = list(
      timeMin = time_min,
      timeMax = time_max,
      singleEvents = "true",
      orderBy = "startTime",
      maxResults = 500
    ),
    httr::add_headers(Authorization = paste("Bearer", access_token))
  )
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    events_data <- jsonlite::fromJSON(content)
    
    if (!is.null(events_data$items) && length(events_data$items) > 0) {
      cat("✅ Service account method successful -", nrow(events_data$items), "events\n")
      return(process_calendar_events(events_data$items, calendar_id))
    } else {
      cat("⚠️ No events found\n")
      return(data.frame())
    }
  } else {
    cat("❌ Service account method failed -", httr::status_code(response), "\n")
    error_content <- httr::content(response, as = "text")
    cat("   Error:", substr(error_content, 1, 200), "\n")
    return(data.frame())
  }
}

#' Extract calendar data using service account
extract_calendar_data_service_account <- function(calendar_ids,
                                                  days_back = 30, 
                                                  days_forward = 7,
                                                  subcalendar_filter = c("Admin", "admin", "Marine", "marine")) {
  
  message("🚀 Extracting Google Calendar data (SERVICE ACCOUNT METHOD)...")
  
  time_min <- format(Sys.Date() - days_back, "%Y-%m-%dT00:00:00Z")
  time_max <- format(Sys.Date() + days_forward, "%Y-%m-%dT23:59:59Z")
  
  all_events <- list()
  
  for (i in 1:length(calendar_ids)) {
    cal_id <- calendar_ids[i]
    cal_name <- ifelse(grepl("soglpfav6p", cal_id), "Admin", 
                      ifelse(grepl("oa9mb0k12r", cal_id), "Marine", paste("Calendar", i)))
    
    message("📅 Processing ", cal_name, " calendar...")
    
    events <- get_calendar_events_service_account(cal_id, time_min, time_max)
    
    if (nrow(events) > 0) {
      events$calendar_name <- cal_name
      all_events[[i]] <- events
      message("   ✅ ", cal_name, ": ", nrow(events), " events")
    } else {
      message("   ⚠️ ", cal_name, ": No events")
    }
  }
  
  if (length(all_events) == 0) {
    message("⚠️ No calendar events extracted")
    return(data.frame())
  }
  
  # Combine all events
  combined_events <- do.call(rbind, all_events[!sapply(all_events, is.null)])
  
  # Parse metadata (reuse existing function)
  source("R/google_calendar.R")
  metadata <- parse_task_metadata(combined_events$description)
  
  result <- cbind(combined_events, metadata)
  
  # Filter for relevant events
  admin_events <- result %>%
    dplyr::filter(
      has_metadata |
      stringr::str_detect(summary, stringr::str_c(subcalendar_filter, collapse = "|")) |
      stringr::str_detect(description, stringr::str_c(subcalendar_filter, collapse = "|"))
    )
  
  message("🎯 Total relevant events: ", nrow(admin_events))
  message("🏷️ Events with #U1I5E7D6h tags: ", sum(admin_events$has_metadata, na.rm = TRUE))
  
  return(admin_events)
}

# Helper function (reuse from fixed implementation)
process_calendar_events <- function(items, calendar_id) {
  
  events_df <- data.frame(
    id = items$id %||% NA,
    summary = items$summary %||% "",
    description = items$description %||% "",
    start_time = items$start$dateTime %||% items$start$date %||% NA,
    end_time = items$end$dateTime %||% items$end$date %||% NA,
    calendar_id = calendar_id,
    stringsAsFactors = FALSE
  )
  
  # Handle all-day events
  for (i in 1:nrow(events_df)) {
    if (!is.na(events_df$start_time[i]) && !grepl("T", events_df$start_time[i])) {
      events_df$start_time[i] <- paste0(events_df$start_time[i], "T09:00:00")
      events_df$end_time[i] <- paste0(events_df$end_time[i], "T17:00:00")
    }
  }
  
  # Convert times
  events_df$start_time <- lubridate::ymd_hms(events_df$start_time, quiet = TRUE)
  events_df$end_time <- lubridate::ymd_hms(events_df$end_time, quiet = TRUE)
  
  # Calculate duration
  events_df$duration_calc <- as.numeric(difftime(events_df$end_time, events_df$start_time, units = "hours"))
  
  return(events_df)
}

# Helper function
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a