#' Alternative Google Calendar approach using calendR or direct CSV export
#' 
#' This provides alternative methods to get your calendar data

library(dplyr)
library(lubridate)
library(readr)

#' Method 1: CSV Export from Google Calendar
#' 
#' Instructions for manual CSV export:
#' 1. Go to Google Calendar (calendar.google.com)
#' 2. Click on your Admin calendar settings (3 dots)
#' 3. Select "Settings and sharing" 
#' 4. Scroll to "Export calendar" and download the .ics file
#' 5. Convert .ics to CSV using online tools or save this function
csv_import_method <- function() {
  cat("=== CSV Import Method ===\n")
  cat("To use this method:\n")
  cat("1. Export your Admin calendar from Google Calendar\n")
  cat("2. Save as 'admin_calendar.csv' in the data/ folder\n") 
  cat("3. Export your Marine calendar as 'marine_calendar.csv'\n")
  cat("4. Run: extract_from_csv_files()\n")
  cat("\nRequired CSV columns: Subject, Start Date, Start Time, End Date, End Time, Description\n")
}

#' Extract calendar data from CSV files
extract_from_csv_files <- function(admin_file = "data/admin_calendar.csv",
                                  marine_file = "data/marine_calendar.csv") {
  
  message("📁 Extracting calendar data from CSV files...")
  
  all_events <- list()
  
  # Process Admin calendar CSV
  if (file.exists(admin_file)) {
    message("📅 Reading Admin calendar CSV...")
    admin_data <- readr::read_csv(admin_file, show_col_types = FALSE)
    
    # Standardize column names (Google Calendar export format)
    admin_processed <- admin_data %>%
      mutate(
        id = paste0("admin_", row_number()),
        summary = Subject,
        description = Description %||% "",
        start_time = lubridate::mdy_hm(paste(Start.Date, Start.Time), quiet = TRUE),
        end_time = lubridate::mdy_hm(paste(End.Date, End.Time), quiet = TRUE),
        calendar_id = "admin_csv",
        calendar_name = "Admin"
      ) %>%
      select(id, summary, description, start_time, end_time, calendar_id, calendar_name)
    
    # Calculate duration
    admin_processed$duration_calc <- as.numeric(difftime(admin_processed$end_time, 
                                                       admin_processed$start_time, 
                                                       units = "hours"))
    
    all_events[["admin"]] <- admin_processed
    message("   ✅ Found ", nrow(admin_processed), " Admin events")
  }
  
  # Process Marine calendar CSV  
  if (file.exists(marine_file)) {
    message("📅 Reading Marine calendar CSV...")
    marine_data <- readr::read_csv(marine_file, show_col_types = FALSE)
    
    marine_processed <- marine_data %>%
      mutate(
        id = paste0("marine_", row_number()),
        summary = Subject,
        description = Description %||% "",
        start_time = lubridate::mdy_hm(paste(Start.Date, Start.Time), quiet = TRUE),
        end_time = lubridate::mdy_hm(paste(End.Date, End.Time), quiet = TRUE),
        calendar_id = "marine_csv", 
        calendar_name = "Marine"
      ) %>%
      select(id, summary, description, start_time, end_time, calendar_id, calendar_name)
    
    marine_processed$duration_calc <- as.numeric(difftime(marine_processed$end_time,
                                                        marine_processed$start_time,
                                                        units = "hours"))
    
    all_events[["marine"]] <- marine_processed
    message("   ✅ Found ", nrow(marine_processed), " Marine events")
  }
  
  if (length(all_events) == 0) {
    message("❌ No CSV files found. Expected files:")
    message("   ", admin_file)
    message("   ", marine_file)
    return(data.frame())
  }
  
  # Combine all events
  combined_events <- do.call(rbind, all_events)
  
  # Filter for recent events (last 30 days, next 7 days)
  date_range <- combined_events %>%
    filter(
      start_time >= (Sys.Date() - 30) & 
      start_time <= (Sys.Date() + 7)
    )
  
  message("📊 Total events in date range: ", nrow(date_range))
  
  # Parse metadata from descriptions
  source("R/google_calendar.R")  # For parse_task_metadata function
  metadata <- parse_task_metadata(date_range$description)
  
  # Combine with metadata
  result <- cbind(date_range, metadata)
  
  # Filter for relevant events
  subcalendar_filter <- c("Admin", "admin", "Marine", "marine", "management", "planning", "research")
  
  filtered_events <- result %>%
    dplyr::filter(
      has_metadata |  # Events with #U1I5E7D6h tags
      stringr::str_detect(summary, stringr::str_c(subcalendar_filter, collapse = "|")) |
      stringr::str_detect(description, stringr::str_c(subcalendar_filter, collapse = "|"))
    )
  
  message("🎯 Filtered to ", nrow(filtered_events), " relevant events")
  message("🏷️  Events with #U1I5E7D6h tags: ", sum(filtered_events$has_metadata, na.rm = TRUE))
  
  # Show breakdown by calendar
  if ("calendar_name" %in% colnames(filtered_events)) {
    cal_breakdown <- table(filtered_events$calendar_name)
    message("📋 Events by calendar:")
    for (cal in names(cal_breakdown)) {
      message("   ", cal, ": ", cal_breakdown[cal], " events")
    }
  }
  
  return(filtered_events)
}

#' Method 2: Manual data entry template
create_manual_data_template <- function(file_path = "data/manual_calendar_data.csv") {
  
  template_data <- data.frame(
    calendar_name = c("Admin", "Admin", "Marine", "Marine", "Admin"),
    summary = c(
      "Project Planning #U7I8E6D2h",
      "Team Meeting", 
      "Research Review #U4I9E8D3h",
      "Data Analysis #U6I7E9D4h",
      "Admin Tasks #U8I7E4D1h"
    ),
    description = c(
      "Strategic planning session #U7I8E6D2h",
      "Weekly team standup",
      "Literature review and analysis #U4I9E8D3h", 
      "Statistical analysis of survey data #U6I7E9D4h",
      "Weekly administrative tasks #U8I7E4D1h"
    ),
    start_date = c("2025-09-03", "2025-09-03", "2025-09-04", "2025-09-05", "2025-09-06"),
    start_time = c("09:00", "14:00", "10:00", "13:00", "11:00"),
    end_date = c("2025-09-03", "2025-09-03", "2025-09-04", "2025-09-05", "2025-09-06"),
    end_time = c("11:00", "15:00", "13:00", "17:00", "12:00")
  )
  
  readr::write_csv(template_data, file_path)
  message("📝 Template created: ", file_path)
  message("Edit this file with your actual calendar data, then run:")
  message("extract_from_manual_template('", file_path, "')")
  
  return(template_data)
}

#' Extract from manual template
extract_from_manual_template <- function(file_path = "data/manual_calendar_data.csv") {
  
  if (!file.exists(file_path)) {
    message("❌ Template file not found: ", file_path)
    message("Create it with: create_manual_data_template()")
    return(data.frame())
  }
  
  message("📁 Reading manual calendar data...")
  manual_data <- readr::read_csv(file_path, show_col_types = FALSE)
  
  # Process the manual data
  processed <- manual_data %>%
    mutate(
      id = paste0("manual_", row_number()),
      start_time = lubridate::ymd_hm(paste(start_date, start_time)),
      end_time = lubridate::ymd_hm(paste(end_date, end_time)),
      calendar_id = paste0(tolower(calendar_name), "_manual"),
      duration_calc = as.numeric(difftime(end_time, start_time, units = "hours"))
    ) %>%
    select(id, summary, description, start_time, end_time, calendar_id, calendar_name, duration_calc)
  
  # Parse metadata
  source("R/google_calendar.R")
  metadata <- parse_task_metadata(processed$description)
  
  result <- cbind(processed, metadata)
  
  message("✅ Processed ", nrow(result), " manual entries")
  message("🏷️  Events with #U1I5E7D6h tags: ", sum(result$has_metadata, na.rm = TRUE))
  
  return(result)
}

# Helper function
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a

cat("=== Alternative Calendar Data Methods ===\n")
cat("If Google Calendar API setup is difficult, try:\n\n")
cat("Method 1 - CSV Export:\n")
cat("  csv_import_method()  # Shows instructions\n") 
cat("  extract_from_csv_files()  # Processes CSV files\n\n")
cat("Method 2 - Manual Entry:\n")
cat("  create_manual_data_template()  # Creates template\n")
cat("  extract_from_manual_template()  # Processes template\n\n")
cat("Then update _targets.R to use the alternative method.\n")