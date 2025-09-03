#' Extract Events from Google Calendar
#' 
#' Connects to Google Calendar API and extracts events from specified calendar
#' Looks for Admin subcalendar and parses task metadata from event descriptions
#' 
#' @param calendar_name Name of the calendar to extract from (default: "Admin")
#' @param days_back Number of days back to look for events (default: 30)
#' @return data.frame with calendar events and parsed metadata
#' 
#' @import googledrive
#' @import googlesheets4
#' @import dplyr
#' @import lubridate
#' @import stringr

library(googledrive)
library(googlesheets4)
library(dplyr)
library(lubridate)
library(stringr)
library(httr)
library(jsonlite)

#' Authenticate with Google APIs
setup_google_auth <- function() {
  # Set up authentication - will prompt for browser auth on first run
  # Store credentials in .secrets/ directory
  if (!dir.exists(".secrets")) {
    dir.create(".secrets")
  }
  
  options(
    gargle_oauth_cache = ".secrets",
    gargle_oauth_email = TRUE
  )
  
  # Authenticate with Google Drive (which includes Calendar API access)
  googledrive::drive_auth()
  googlesheets4::gs4_auth(token = googledrive::drive_token())
  
  message("Google authentication setup complete")
}

#' Get Google Calendar events using Calendar API v3
#' 
#' @param calendar_id Calendar ID (use "primary" for main calendar)
#' @param time_min Start time (ISO 8601 format)
#' @param time_max End time (ISO 8601 format)
get_calendar_events <- function(calendar_id = "primary", 
                               time_min = format(Sys.Date() - 30, "%Y-%m-%dT00:00:00Z"),
                               time_max = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z")) {
  
  # Get the access token
  token <- googledrive::drive_token()
  
  # Calendar API endpoint
  url <- "https://www.googleapis.com/calendar/v3/calendars/{calendarId}/events"
  url <- stringr::str_replace(url, "\\{calendarId\\}", calendar_id)
  
  # Parameters for the API call
  params <- list(
    timeMin = time_min,
    timeMax = time_max,
    singleEvents = "true",
    orderBy = "startTime",
    maxResults = 2500
  )
  
  # Make the API call
  response <- httr::GET(
    url,
    query = params,
    httr::config(token = token)
  )
  
  # Check if request was successful
  if (httr::status_code(response) != 200) {
    stop("Failed to fetch calendar events. Status: ", httr::status_code(response))
  }
  
  # Parse the JSON response
  content <- httr::content(response, "text", encoding = "UTF-8")
  events_data <- jsonlite::fromJSON(content)
  
  if (is.null(events_data$items) || length(events_data$items) == 0) {
    message("No events found in the specified time range")
    return(data.frame())
  }
  
  # Extract relevant fields and return as data frame
  events_df <- data.frame(
    id = events_data$items$id %||% NA,
    summary = events_data$items$summary %||% NA,
    description = events_data$items$description %||% NA,
    start_time = events_data$items$start$dateTime %||% events_data$items$start$date %||% NA,
    end_time = events_data$items$end$dateTime %||% events_data$items$end$date %||% NA,
    calendar_id = calendar_id,
    stringsAsFactors = FALSE
  )
  
  # Convert times to POSIXct
  events_df$start_time <- lubridate::ymd_hms(events_df$start_time, quiet = TRUE)
  events_df$end_time <- lubridate::ymd_hms(events_df$end_time, quiet = TRUE)
  
  # Calculate duration in hours
  events_df$duration_calc <- as.numeric(difftime(events_df$end_time, events_df$start_time, units = "hours"))
  
  return(events_df)
}

#' Parse task metadata from event descriptions
#' 
#' Looks for patterns like #U1I5E7D6h in event descriptions
#' U = Urgency, I = Importance, E = Enjoyment, D = Duration
#' 
#' @param description Character vector of event descriptions
#' @return data.frame with parsed metadata
parse_task_metadata <- function(description) {
  if (is.null(description) || all(is.na(description))) {
    return(data.frame(
      urgency = NA,
      importance = NA, 
      enjoyment = NA,
      duration_tagged = NA,
      has_metadata = FALSE
    ))
  }
  
  # Pattern to match #U[digit]I[digit]E[digit]D[digit]h
  pattern <- "#U(\\d+)I(\\d+)E(\\d+)D(\\d+)h"
  
  # Extract matches
  matches <- stringr::str_match(description, pattern)
  
  # Create result data frame
  result <- data.frame(
    urgency = as.numeric(matches[, 2]),
    importance = as.numeric(matches[, 3]),
    enjoyment = as.numeric(matches[, 4]),
    duration_tagged = as.numeric(matches[, 5]),
    has_metadata = !is.na(matches[, 1]),
    stringsAsFactors = FALSE
  )
  
  return(result)
}

#' Main function to extract and process Google Calendar data
#' 
#' @param calendar_id Calendar ID to extract from
#' @param days_back Number of days back to look
#' @param days_forward Number of days forward to look
#' @return Processed data frame with events and parsed metadata
extract_google_calendar_data <- function(calendar_id = "primary", 
                                        days_back = 30, 
                                        days_forward = 7) {
  
  message("Extracting Google Calendar data...")
  
  # Define time range
  time_min <- format(Sys.Date() - days_back, "%Y-%m-%dT00:00:00Z")
  time_max <- format(Sys.Date() + days_forward, "%Y-%m-%dT23:59:59Z")
  
  # Get events
  events <- get_calendar_events(calendar_id, time_min, time_max)
  
  if (nrow(events) == 0) {
    message("No events found")
    return(data.frame())
  }
  
  # Parse metadata from descriptions
  metadata <- parse_task_metadata(events$description)
  
  # Combine events with metadata
  result <- cbind(events, metadata)
  
  # Filter for events with Admin-related content or metadata
  admin_keywords <- c("admin", "Admin", "ADMIN", "management", "planning", "review")
  admin_events <- result %>%
    filter(
      has_metadata | 
      stringr::str_detect(summary, stringr::str_c(admin_keywords, collapse = "|")) |
      stringr::str_detect(description %||% "", stringr::str_c(admin_keywords, collapse = "|"))
    )
  
  message(paste("Found", nrow(result), "total events,", nrow(admin_events), "admin/tagged events"))
  
  return(admin_events)
}

# Helper function for null coalescing
`%||%` <- function(a, b) if (is.null(a)) b else a