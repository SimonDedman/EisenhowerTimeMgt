# _targets.R file for automated time management pipeline
# This file defines the targets workflow for data extraction, processing, and visualization

library(targets)
library(tarchetypes)

# Source core R functions
source("R/google_calendar_service_account.R")  # Primary Google Calendar method
source("R/trello_data_fixed.R")                # Primary Trello method
source("R/visualization.R")                    # Plotting and data combination

# Source fallback methods
source("R/fallback_methods/google_calendar.R")
source("R/google_calendar_simple.R")
source("R/fallback_methods/google_calendar_real.R")
source("R/fallback_methods/google_calendar_alternative.R")
source("R/google_calendar_fixed.R")
source("R/fallback_methods/trello_data.R")

# Set target options
tar_option_set(
  packages = c(
    "googledrive", "googlesheets4", "trelloR", 
    "ggplot2", "dplyr", "tidyr", "lubridate", "stringr", 
    "rmarkdown", "httr", "jsonlite", "ggrepel"
  ),
  format = "rds",
  repository = "local"
)

# Define the pipeline
list(
  
  # Configuration targets
  tar_target(
    calendar_config,
    list(
      # Separate calendars for Work and Home categorization
      work_calendars = list(
        id = "oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com", # Marine calendar
        name = "Marine"
      ),
      home_calendars = list(
        id = "soglpfav6p301t36cj9aqpe79s@group.calendar.google.com", # Admin calendar  
        name = "Admin"
      ),
      days_back = 30,
      days_forward = 7,
      subcalendar_filter = c("Admin", "admin", "Marine", "marine", "management", "planning", "review", "research")
    )
  ),
  
  tar_target(
    trello_config, 
    list(
      # Specific boards for Work and Home categorization
      work_boards = c("MarSci Projects"),
      home_boards = c("Meg & Si Todo"), 
      include_closed = FALSE
    )
  ),
  
  # Data extraction targets
  # Work calendar data (Marine)
  tar_target(
    work_calendar_data,
    {
      calendar_ids <- calendar_config$work_calendars$id
      # Try SERVICE ACCOUNT extraction first (best for CLI)
      tryCatch({
        data <- extract_calendar_data_service_account(
          calendar_ids = calendar_ids,
          days_back = calendar_config$days_back,
          days_forward = calendar_config$days_forward,
          subcalendar_filter = calendar_config$subcalendar_filter
        )
        # Add category column
        if(nrow(data) > 0) data$category <- "Work"
        data
      }, error = function(e) {
        message("Service Account extraction failed: ", e$message)
        
        # Try FIXED Google Calendar extraction
        tryCatch({
          data <- extract_calendar_data_fixed(
            calendar_ids = calendar_ids,
            days_back = calendar_config$days_back,
            days_forward = calendar_config$days_forward,
            subcalendar_filter = calendar_config$subcalendar_filter
          )
          if(nrow(data) > 0) data$category <- "Work"
          data
        }, error = function(e2) {
          message("All calendar methods failed, trying manual template...")
          tryCatch({
            data <- extract_from_manual_template()
            # Filter for work calendar (Marine)
            work_data <- data[data$calendar_name == "Marine", ]
            if(nrow(work_data) > 0) work_data$category <- "Work"
            work_data
          }, error = function(e3) {
            message("Manual template also failed, returning empty data frame")
            data.frame(category = character(0))
          })
        })
      })
    },
    # Re-run every 6 hours
    cue = tar_cue(mode = "thorough")
  ),
  
  # Home calendar data (Admin)
  tar_target(
    home_calendar_data,
    {
      calendar_ids <- calendar_config$home_calendars$id
      # Try SERVICE ACCOUNT extraction first (best for CLI)
      tryCatch({
        data <- extract_calendar_data_service_account(
          calendar_ids = calendar_ids,
          days_back = calendar_config$days_back,
          days_forward = calendar_config$days_forward,
          subcalendar_filter = calendar_config$subcalendar_filter
        )
        # Add category column
        if(nrow(data) > 0) data$category <- "Home"
        data
      }, error = function(e) {
        message("Service Account extraction failed: ", e$message)
        
        # Try FIXED Google Calendar extraction
        tryCatch({
          data <- extract_calendar_data_fixed(
            calendar_ids = calendar_ids,
            days_back = calendar_config$days_back,
            days_forward = calendar_config$days_forward,
            subcalendar_filter = calendar_config$subcalendar_filter
          )
          if(nrow(data) > 0) data$category <- "Home"
          data
        }, error = function(e2) {
          message("All calendar methods failed, trying manual template...")
          tryCatch({
            data <- extract_from_manual_template()
            # Filter for home calendar (Admin)
            home_data <- data[data$calendar_name == "Admin", ]
            if(nrow(home_data) > 0) home_data$category <- "Home"
            home_data
          }, error = function(e3) {
            message("Manual template also failed, returning empty data frame")
            data.frame(category = character(0))
          })
        })
      })
    },
    # Re-run every 6 hours
    cue = tar_cue(mode = "thorough")
  ),
  
  # Work Trello data (MarSci Projects)
  tar_target(
    work_trello_data,
    {
      tryCatch({
        # Use FIXED Trello extraction with direct HTTP calls
        data <- extract_trello_data_fixed(
          board_names = trello_config$work_boards,
          include_closed = trello_config$include_closed
        )
        # Add category column
        if(nrow(data) > 0) data$category <- "Work"
        data
      }, error = function(e) {
        message("Fixed Trello extraction failed for work boards: ", e$message)
        message("Trying manual Trello data...")
        tryCatch({
          data <- extract_manual_trello_data()
          # Filter for work boards (MarSci Projects)
          work_data <- data[data$board_name == "MarSci Projects", ]
          if(nrow(work_data) > 0) work_data$category <- "Work"
          work_data
        }, error = function(e2) {
          message("Manual Trello data also failed, returning empty data frame")
          data.frame(category = character(0))
        })
      })
    },
    # Re-run every 6 hours  
    cue = tar_cue(mode = "thorough")
  ),
  
  # Home Trello data (Meg & Si Todo)
  tar_target(
    home_trello_data,
    {
      tryCatch({
        # Use FIXED Trello extraction with direct HTTP calls
        data <- extract_trello_data_fixed(
          board_names = trello_config$home_boards,
          include_closed = trello_config$include_closed
        )
        # Add category column
        if(nrow(data) > 0) data$category <- "Home"
        data
      }, error = function(e) {
        message("Fixed Trello extraction failed for home boards: ", e$message)
        message("Trying manual Trello data...")
        tryCatch({
          data <- extract_manual_trello_data()
          # Filter for home boards (Meg & Si Todo)
          home_data <- data[data$board_name == "Meg & Si Todo", ]
          if(nrow(home_data) > 0) home_data$category <- "Home"
          home_data
        }, error = function(e2) {
          message("Manual Trello data also failed, returning empty data frame")
          data.frame(category = character(0))
        })
      })
    },
    # Re-run every 6 hours  
    cue = tar_cue(mode = "thorough")
  ),
  
  # Data processing targets
  # Work data combination
  tar_target(
    work_task_data,
    combine_task_data(
      calendar_data = work_calendar_data,
      trello_data = work_trello_data
    )
  ),
  
  # Home data combination  
  tar_target(
    home_task_data,
    combine_task_data(
      calendar_data = home_calendar_data,
      trello_data = home_trello_data
    )
  ),
  
  # Combined data for overall view
  tar_target(
    combined_task_data,
    combine_work_home_data(work_task_data, home_task_data)
  ),
  
  # Analysis targets
  tar_target(
    summary_statistics,
    create_summary_stats(combined_task_data)
  ),
  
  # Visualization targets
  # Work Eisenhower Matrix
  tar_target(
    work_eisenhower_plot,
    {
      plot <- create_eisenhower_plot(
        work_task_data,
        title = "Work Eisenhower Matrix - Marine Calendar & MarSci Projects"
      )
      
      # Save plot
      ggsave(
        filename = "reports/eisenhower_matrix_work.png",
        plot = plot,
        width = 12, height = 8, dpi = 300, bg = "white"
      )
      
      plot
    }
  ),
  
  # Home Eisenhower Matrix
  tar_target(
    home_eisenhower_plot,
    {
      plot <- create_eisenhower_plot(
        home_task_data,
        title = "Home Eisenhower Matrix - Admin Calendar & Meg & Si Todo"
      )
      
      # Save plot
      ggsave(
        filename = "reports/eisenhower_matrix_home.png",
        plot = plot,
        width = 12, height = 8, dpi = 300, bg = "white"
      )
      
      plot
    }
  ),
  
  # Combined Eisenhower Matrix
  tar_target(
    combined_eisenhower_plot,
    {
      plot <- create_eisenhower_plot(
        combined_task_data,
        title = "Combined Eisenhower Matrix - Personal Time Management"
      )
      
      # Save plot
      ggsave(
        filename = "reports/eisenhower_matrix_combined.png",
        plot = plot,
        width = 12, height = 8, dpi = 300, bg = "white"
      )
      
      plot
    }
  ),
  
  tar_target(
    timeline_plot,
    {
      plot <- create_timeline_plot(combined_task_data)
      
      # Save plot
      ggsave(
        filename = "reports/task_timeline.png", 
        plot = plot,
        width = 12, height = 6, dpi = 300, bg = "white"
      )
      
      plot
    }
  ),
  
  # Export data targets
  tar_target(
    export_csv,
    {
      if (nrow(combined_task_data) > 0) {
        write.csv(
          combined_task_data, 
          file = "data/combined_tasks.csv", 
          row.names = FALSE
        )
        
        # Also create a summary CSV
        if (length(summary_statistics) > 0 && !is.null(summary_statistics$by_quadrant)) {
          write.csv(
            summary_statistics$by_quadrant,
            file = "data/quadrant_summary.csv",
            row.names = FALSE
          )
        }
      }
      
      "data/combined_tasks.csv"
    }
  ),
  
  # Report generation target
  tar_target(
    report,
    {
      # Ensure reports directory exists
      if (!dir.exists("reports")) dir.create("reports")
      
      # Save data objects for the report to use
      saveRDS(combined_task_data, "reports/combined_task_data.rds")
      saveRDS(summary_statistics, "reports/summary_statistics.rds")
      
      # Render the report with parameters
      rmarkdown::render(
        input = "reports/eisenhower_report.Rmd",
        output_file = "eisenhower_report.html",
        output_dir = "reports",
        params = list(
          data_file = "combined_task_data.rds",
          stats_file = "summary_statistics.rds"
        )
      )
      
      "reports/eisenhower_report.html"
    }
  ),
  
  # GitHub Pages deployment preparation
  tar_target(
    github_pages_files,
    {
      # Copy key files to docs/ for GitHub Pages
      if (!dir.exists("docs")) dir.create("docs")
      
      # Copy HTML report
      if (file.exists("reports/eisenhower_report.html")) {
        file.copy("reports/eisenhower_report.html", "docs/index.html", overwrite = TRUE)
      }
      
      # Copy plots
      if (file.exists("reports/eisenhower_matrix_work.png")) {
        file.copy("reports/eisenhower_matrix_work.png", "docs/", overwrite = TRUE)
      }
      
      if (file.exists("reports/eisenhower_matrix_home.png")) {
        file.copy("reports/eisenhower_matrix_home.png", "docs/", overwrite = TRUE)
      }
      
      if (file.exists("reports/eisenhower_matrix_combined.png")) {
        file.copy("reports/eisenhower_matrix_combined.png", "docs/", overwrite = TRUE)
      }
      
      if (file.exists("reports/task_timeline.png")) {
        file.copy("reports/task_timeline.png", "docs/", overwrite = TRUE) 
      }
      
      # Create a simple index if report doesn't exist
      if (!file.exists("docs/index.html")) {
        simple_html <- paste0(
          "<!DOCTYPE html>\n<html>\n<head>\n",
          "<title>Eisenhower Time Management Dashboard</title>\n",
          "</head>\n<body>\n",
          "<h1>Personal Time Management Dashboard</h1>\n",
          "<p>Last updated: ", Sys.time(), "</p>\n",
          "<h2>Work Tasks (Marine Calendar & MarSci Projects)</h2>\n",
          "<img src='eisenhower_matrix_work.png' alt='Work Eisenhower Matrix' style='max-width: 100%;'>\n",
          "<h2>Home Tasks (Admin Calendar & Meg & Si Todo)</h2>\n",
          "<img src='eisenhower_matrix_home.png' alt='Home Eisenhower Matrix' style='max-width: 100%;'>\n",
          "<h2>Combined Overview</h2>\n",
          "<img src='eisenhower_matrix_combined.png' alt='Combined Eisenhower Matrix' style='max-width: 100%;'>\n",
          "<img src='task_timeline.png' alt='Task Timeline' style='max-width: 100%;'>\n",
          "</body>\n</html>"
        )
        
        writeLines(simple_html, "docs/index.html")
      }
      
      "docs/index.html"
    }
  )
)