#' Fixed Google Calendar API Implementation
#' Uses service account or stored OAuth tokens for CLI compatibility

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(stringr)

#' Get Google Calendar events using service account or cached token
get_calendar_events_fixed <- function(calendar_id, 
                                     time_min = format(Sys.Date() - 30, "%Y-%m-%dT00:00:00Z"),
                                     time_max = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z")) {
  
  api_key <- Sys.getenv("GOOGLE_API_KEY")
  if (api_key == "") {
    stop("Google API key not found")
  }
  
  cat("📅 Fetching events from Google Calendar:", substr(calendar_id, 1, 20), "...\n")
  
  # Method 1: Try with stored OAuth token (if available)
  oauth_token <- get_stored_oauth_token()
  
  if (!is.null(oauth_token)) {
    cat("🔑 Using stored OAuth token\n")
    result <- try_calendar_with_oauth(calendar_id, oauth_token, time_min, time_max, api_key)
    if (!is.null(result)) {
      return(result)
    }
  }
  
  # Method 2: Try with API key only (works for public calendars)
  cat("🔑 Trying API key only approach\n")
  result <- try_calendar_api_key_only(calendar_id, api_key, time_min, time_max)
  if (!is.null(result)) {
    return(result)
  }
  
  # Method 3: Instructions for manual OAuth
  cat("❌ Automatic authentication failed\n")
  cat("💡 To fix this, you need to run in RStudio:\n")
  cat("   library(googledrive)\n")
  cat("   drive_auth()\n")
  cat("   # This will create cached credentials\n")
  
  return(data.frame())
}

#' Try to get stored OAuth token
get_stored_oauth_token <- function() {
  
  # Check various possible locations for cached tokens
  possible_paths <- c(
    ".secrets/google-token.rds",
    ".httr-oauth",
    "~/.R/gargle/gargle-oauth",
    ".secrets/googlesheets4_token.rds"
  )
  
  for (path in possible_paths) {
    if (file.exists(path)) {
      tryCatch({
        cat("📁 Found cached token at:", path, "\n")
        token_data <- readRDS(path)
        return(token_data)
      }, error = function(e) {
        # Try next path
      })
    }
  }
  
  return(NULL)
}

#' Try calendar access with OAuth token
try_calendar_with_oauth <- function(calendar_id, token, time_min, time_max, api_key) {
  
  # Build URL
  encoded_id <- utils::URLencode(calendar_id, reserved = TRUE) 
  url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", encoded_id, "/events")
  
  # Extract access token from various token formats
  access_token <- extract_access_token(token)
  if (is.null(access_token)) {
    return(NULL)
  }
  
  # Make API call
  response <- httr::GET(
    url,
    query = list(
      timeMin = time_min,
      timeMax = time_max,
      singleEvents = "true",
      orderBy = "startTime",
      maxResults = 500,
      key = api_key
    ),
    httr::add_headers(Authorization = paste("Bearer", access_token))
  )
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    events_data <- jsonlite::fromJSON(content)
    
    if (!is.null(events_data$items) && length(events_data$items) > 0) {
      cat("✅ OAuth method successful -", nrow(events_data$items), "events\n")
      return(process_calendar_events(events_data$items, calendar_id))
    }
  }
  
  cat("❌ OAuth method failed -", httr::status_code(response), "\n")
  return(NULL)
}

#' Try calendar access with API key only  
try_calendar_api_key_only <- function(calendar_id, api_key, time_min, time_max) {
  
  encoded_id <- utils::URLencode(calendar_id, reserved = TRUE)
  url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", encoded_id, "/events")
  
  response <- httr::GET(
    url,
    query = list(
      timeMin = time_min,
      timeMax = time_max,
      singleEvents = "true", 
      orderBy = "startTime",
      maxResults = 500,
      key = api_key
    )
  )
  
  if (httr::status_code(response) == 200) {
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    events_data <- jsonlite::fromJSON(content)
    
    if (!is.null(events_data$items) && length(events_data$items) > 0) {
      cat("✅ API key method successful -", nrow(events_data$items), "events\n")
      return(process_calendar_events(events_data$items, calendar_id))
    }
  }
  
  cat("❌ API key method failed -", httr::status_code(response), "\n")
  error_content <- httr::content(response, as = "text")
  cat("   Error:", substr(error_content, 1, 200), "\n")
  return(NULL)
}

#' Extract access token from various token formats
extract_access_token <- function(token) {
  
  if (is.null(token)) return(NULL)
  
  # Try different token formats
  if (is.character(token)) {
    return(token)
  }
  
  if (is.list(token)) {
    # httr token format
    if (!is.null(token$credentials$access_token)) {
      return(token$credentials$access_token)
    }
    
    # Direct access_token
    if (!is.null(token$access_token)) {
      return(token$access_token)
    }
  }
  
  # gargle token format
  if (inherits(token, "Token2.0")) {
    if (!is.null(token$credentials$access_token)) {
      return(token$credentials$access_token)
    }
  }
  
  return(NULL)
}

#' Process calendar events into standard format
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

#' Extract calendar data from multiple calendars using fixed authentication
extract_calendar_data_fixed <- function(calendar_ids,
                                        days_back = 30, 
                                        days_forward = 7,
                                        subcalendar_filter = c("Admin", "admin", "Marine", "marine")) {
  
  message("🚀 Extracting Google Calendar data (FIXED METHOD)...")
  
  time_min <- format(Sys.Date() - days_back, "%Y-%m-%dT00:00:00Z")
  time_max <- format(Sys.Date() + days_forward, "%Y-%m-%dT23:59:59Z")
  
  all_events <- list()
  
  for (i in 1:length(calendar_ids)) {
    cal_id <- calendar_ids[i]
    cal_name <- ifelse(grepl("soglpfav6p", cal_id), "Admin", 
                      ifelse(grepl("oa9mb0k12r", cal_id), "Marine", paste("Calendar", i)))
    
    message("📅 Processing ", cal_name, " calendar...")
    
    events <- get_calendar_events_fixed(cal_id, time_min, time_max)
    
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
  
  # Parse metadata
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

# Helper function
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a