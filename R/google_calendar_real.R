#' Real Google Calendar API Integration
#' 
#' This replaces the mock data version once you provide your calendar details

library(googledrive)
library(googlesheets4)
library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(stringr)

#' Get real Google Calendar events
#' 
#' @param calendar_id Your calendar ID (find this in Google Calendar settings)
#' @param time_min Start time for event search
#' @param time_max End time for event search
#' @param subcalendar_filter Keywords to filter for specific subcalendars
get_real_calendar_events <- function(calendar_id = "primary", 
                                    time_min = format(Sys.Date() - 30, "%Y-%m-%dT00:00:00Z"),
                                    time_max = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z"),
                                    subcalendar_filter = c("Admin", "admin", "ADMIN")) {
  
  message("Fetching real Google Calendar events...")
  
  tryCatch({
    # Get the access token from googledrive
    token <- googledrive::drive_token()
    
    # Build the Calendar API URL
    if (calendar_id == "primary") {
      url <- "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    } else {
      # URL encode the calendar ID
      encoded_id <- utils::URLencode(calendar_id, reserved = TRUE)
      url <- paste0("https://www.googleapis.com/calendar/v3/calendars/", encoded_id, "/events")
    }
    
    # Parameters for the API call
    params <- list(
      timeMin = time_min,
      timeMax = time_max,
      singleEvents = "true",
      orderBy = "startTime",
      maxResults = 2500
    )
    
    # Make the API call with proper token handling
    response <- httr::GET(
      url,
      query = params,
      httr::add_headers(Authorization = paste("Bearer", token$credentials$access_token))
    )
    
    # Check if request was successful
    if (httr::status_code(response) != 200) {
      message("❌ API call failed. Status: ", httr::status_code(response))
      message("Response: ", httr::content(response, "text"))
      return(data.frame())
    }
    
    # Parse the JSON response
    content <- httr::content(response, "text", encoding = "UTF-8")
    events_data <- jsonlite::fromJSON(content)
    
    if (is.null(events_data$items) || length(events_data$items) == 0) {
      message("No events found in the specified time range")
      return(data.frame())
    }
    
    message("📅 Found ", nrow(events_data$items), " total calendar events")
    
    # Extract relevant fields and return as data frame
    events_df <- data.frame(
      id = events_data$items$id %||% NA,
      summary = events_data$items$summary %||% "",
      description = events_data$items$description %||% "",
      start_time = events_data$items$start$dateTime %||% events_data$items$start$date %||% NA,
      end_time = events_data$items$end$dateTime %||% events_data$items$end$date %||% NA,
      calendar_id = calendar_id,
      stringsAsFactors = FALSE
    )
    
    # Handle all-day events (dates without times)
    for (i in 1:nrow(events_df)) {
      if (!is.na(events_df$start_time[i]) && !grepl("T", events_df$start_time[i])) {
        # All-day event - add default times
        events_df$start_time[i] <- paste0(events_df$start_time[i], "T09:00:00")
        events_df$end_time[i] <- paste0(events_df$end_time[i], "T17:00:00")
      }
    }
    
    # Convert times to POSIXct
    events_df$start_time <- lubridate::ymd_hms(events_df$start_time, quiet = TRUE)
    events_df$end_time <- lubridate::ymd_hms(events_df$end_time, quiet = TRUE)
    
    # Calculate duration in hours
    events_df$duration_calc <- as.numeric(difftime(events_df$end_time, events_df$start_time, units = "hours"))
    
    # Filter for subcalendar if specified
    if (!is.null(subcalendar_filter) && length(subcalendar_filter) > 0) {
      filter_pattern <- stringr::str_c(subcalendar_filter, collapse = "|")
      
      filtered_events <- events_df %>%
        filter(
          stringr::str_detect(summary, filter_pattern) |
          stringr::str_detect(description, filter_pattern)
        )
      
      message("🎯 Filtered to ", nrow(filtered_events), " events matching: ", paste(subcalendar_filter, collapse = ", "))
      return(filtered_events)
    }
    
    return(events_df)
    
  }, error = function(e) {
    message("❌ Error fetching calendar events: ", e$message)
    return(data.frame())
  })
}

#' Extract and process real Google Calendar data from multiple calendars
#' 
#' @param calendar_ids Vector of calendar IDs (Admin, Marine, etc.)
#' @param days_back Number of days back to search
#' @param days_forward Number of days forward to search  
#' @param subcalendar_filter Keywords to identify your admin/management events
extract_real_google_calendar_data <- function(calendar_ids = "primary",
                                             days_back = 30, 
                                             days_forward = 7,
                                             subcalendar_filter = c("Admin", "admin", "Marine", "marine", "management", "planning")) {
  
  message("🚀 Extracting REAL Google Calendar data from ", length(calendar_ids), " calendar(s)...")
  
  # Define time range
  time_min <- format(Sys.Date() - days_back, "%Y-%m-%dT00:00:00Z")
  time_max <- format(Sys.Date() + days_forward, "%Y-%m-%dT23:59:59Z")
  
  message("📅 Date range: ", as.Date(time_min), " to ", as.Date(time_max))
  
  # Handle single calendar ID (backward compatibility)
  if (length(calendar_ids) == 1 && !is.vector(calendar_ids)) {
    calendar_ids <- c(calendar_ids)
  }
  
  all_events <- list()
  
  # Extract events from each calendar
  for (i in 1:length(calendar_ids)) {
    cal_id <- calendar_ids[i]
    cal_name <- ifelse(grepl("soglpfav6p", cal_id), "Admin", 
                      ifelse(grepl("oa9mb0k12r", cal_id), "Marine", paste("Calendar", i)))
    
    message("📅 Processing ", cal_name, " calendar...")
    
    tryCatch({
      events <- get_real_calendar_events(cal_id, time_min, time_max, subcalendar_filter)
      
      if (nrow(events) > 0) {
        events$calendar_name <- cal_name
        all_events[[i]] <- events
        message("   ✅ Found ", nrow(events), " events in ", cal_name, " calendar")
      } else {
        message("   ⚠️  No events found in ", cal_name, " calendar")
      }
      
    }, error = function(e) {
      message("   ❌ Error accessing ", cal_name, " calendar: ", e$message)
    })
  }
  
  # Combine all events
  if (length(all_events) == 0) {
    message("⚠️  No events found in any calendar")
    return(data.frame())
  }
  
  combined_events <- do.call(rbind, all_events[!sapply(all_events, is.null)])
  
  if (nrow(combined_events) == 0) {
    message("⚠️  No events found - check your calendar IDs and date range")
    return(data.frame())
  }
  
  message("📊 Total events across all calendars: ", nrow(combined_events))
  
  # Parse metadata from descriptions using the existing function
  source("R/google_calendar.R")  # For parse_task_metadata function
  metadata <- parse_task_metadata(combined_events$description)
  
  # Combine events with metadata
  result <- cbind(combined_events, metadata)
  
  # Filter for events with metadata tags OR admin-related content
  admin_events <- result %>%
    dplyr::filter(
      has_metadata |  # Events with #U1I5E7D6h tags
      stringr::str_detect(summary, stringr::str_c(subcalendar_filter, collapse = "|")) |
      stringr::str_detect(description, stringr::str_c(subcalendar_filter, collapse = "|"))
    )
  
  message("🎯 Filtered to ", nrow(admin_events), " relevant events")
  message("🏷️  Events with #U1I5E7D6h tags: ", sum(admin_events$has_metadata, na.rm = TRUE))
  
  # Show breakdown by calendar
  if ("calendar_name" %in% colnames(admin_events)) {
    cal_breakdown <- table(admin_events$calendar_name)
    message("📋 Events by calendar:")
    for (cal in names(cal_breakdown)) {
      message("   ", cal, ": ", cal_breakdown[cal], " events")
    }
  }
  
  return(admin_events)
}

# Helper function for null coalescing (if not already defined)
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}