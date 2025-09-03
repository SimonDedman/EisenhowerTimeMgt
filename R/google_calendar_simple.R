#' Simple Google Calendar Mock Function
#' 
#' Returns mock data for testing the pipeline
#' Replace this with real Google Calendar API calls once authentication is working

library(lubridate)

get_calendar_events_simple <- function(calendar_id = "primary", 
                                      time_min = format(Sys.Date() - 30, "%Y-%m-%dT00:00:00Z"),
                                      time_max = format(Sys.Date() + 7, "%Y-%m-%dT23:59:59Z")) {
  
  # Create sample data with the expected structure
  message("Using mock Google Calendar data for testing")
  
  sample_events <- data.frame(
    id = c("mock1", "mock2", "mock3", "mock4", "mock5"),
    summary = c(
      "Project Planning #U7I8E6D2h", 
      "Team Meeting", 
      "Research Task #U4I9E8D3h",
      "Admin Review #U8I7E4D1h",
      "Client Call #U6I5E7D2h"
    ),
    description = c(
      "Strategic planning session #U7I8E6D2h", 
      "Weekly standup meeting", 
      "Literature review #U4I9E8D3h",
      "Weekly admin tasks #U8I7E4D1h",
      "Client check-in #U6I5E7D2h"
    ),
    start_time = as.POSIXct(c(
      "2025-09-03 09:00:00", 
      "2025-09-03 14:00:00", 
      "2025-09-04 10:00:00",
      "2025-09-05 11:00:00",
      "2025-09-06 15:00:00"
    )),
    end_time = as.POSIXct(c(
      "2025-09-03 11:00:00", 
      "2025-09-03 15:00:00", 
      "2025-09-04 13:00:00",
      "2025-09-05 12:00:00",
      "2025-09-06 17:00:00"
    )),
    calendar_id = calendar_id,
    stringsAsFactors = FALSE
  )
  
  # Calculate duration in hours
  sample_events$duration_calc <- as.numeric(difftime(sample_events$end_time, sample_events$start_time, units = "hours"))
  
  return(sample_events)
}

extract_google_calendar_data_simple <- function(calendar_id = "primary", 
                                               days_back = 30, 
                                               days_forward = 7) {
  
  message("Extracting Google Calendar data (using mock data)...")
  
  # Define time range
  time_min <- format(Sys.Date() - days_back, "%Y-%m-%dT00:00:00Z")
  time_max <- format(Sys.Date() + days_forward, "%Y-%m-%dT23:59:59Z")
  
  # Get events
  events <- get_calendar_events_simple(calendar_id, time_min, time_max)
  
  if (nrow(events) == 0) {
    message("No events found")
    return(data.frame())
  }
  
  # Parse metadata from descriptions
  source("R/google_calendar.R")  # For parse_task_metadata function
  metadata <- parse_task_metadata(events$description)
  
  # Combine events with metadata
  result <- cbind(events, metadata)
  
  # Filter for events with Admin-related content or metadata
  admin_keywords <- c("admin", "Admin", "ADMIN", "management", "planning", "review")
  admin_events <- result %>%
    dplyr::filter(
      has_metadata |
      stringr::str_detect(ifelse(is.na(summary), "", summary), stringr::str_c(admin_keywords, collapse = "|")) |
      stringr::str_detect(ifelse(is.na(description), "", description), stringr::str_c(admin_keywords, collapse = "|"))
    )
  
  message(paste("Found", nrow(result), "total events,", nrow(admin_events), "admin/tagged events"))
  
  return(admin_events)
}