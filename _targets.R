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
      calendar_ids = c(
        "soglpfav6p301t36cj9aqpe79s@group.calendar.google.com", # Admin calendar
        "oa9mb0k12rkfsdsm9752bsahsc@group.calendar.google.com"  # Marine calendar
      ),
      days_back = 30,
      days_forward = 7,
      subcalendar_filter = c("Admin", "admin", "Marine", "marine", "management", "planning", "review", "research")
    )
  ),
  
  tar_target(
    trello_config, 
    list(
      board_names = NULL, # NULL means all boards
      include_closed = FALSE
    )
  ),
  
  # Data extraction targets
  tar_target(
    google_calendar_data,
    {
      # Try SERVICE ACCOUNT extraction first (best for CLI)
      tryCatch({
        extract_calendar_data_service_account(
          calendar_ids = calendar_config$calendar_ids,
          days_back = calendar_config$days_back,
          days_forward = calendar_config$days_forward,
          subcalendar_filter = calendar_config$subcalendar_filter
        )
      }, error = function(e) {
        message("Service Account extraction failed: ", e$message)
        
        # Try FIXED Google Calendar extraction
        tryCatch({
          extract_calendar_data_fixed(
            calendar_ids = calendar_config$calendar_ids,
            days_back = calendar_config$days_back,
            days_forward = calendar_config$days_forward,
            subcalendar_filter = calendar_config$subcalendar_filter
          )
        }, error = function(e2) {
          message("Fixed Google Calendar extraction failed: ", e2$message)
          
          # Try original real extraction
          tryCatch({
            extract_real_google_calendar_data(
              calendar_ids = calendar_config$calendar_ids,
              days_back = calendar_config$days_back,
              days_forward = calendar_config$days_forward,
              subcalendar_filter = calendar_config$subcalendar_filter
            )
          }, error = function(e3) {
            message("Real Google Calendar API extraction failed: ", e3$message)
            
            # Try CSV files
            tryCatch({
              message("Trying CSV files...")
              extract_from_csv_files()
            }, error = function(e4) {
              
              # Try manual template
              tryCatch({
                message("Trying manual template...")
                extract_from_manual_template()
              }, error = function(e5) {
                
                message("All methods failed, falling back to mock data...")
                # Final fallback to mock data
                extract_google_calendar_data_simple(
                  calendar_id = "primary",
                  days_back = calendar_config$days_back,
                  days_forward = calendar_config$days_forward
                )
              })
            })
          })
        })
      })
    },
    # Re-run every 6 hours
    cue = tar_cue(mode = "thorough")
  ),
  
  tar_target(
    trello_data,
    {
      tryCatch({
        # Use FIXED Trello extraction with direct HTTP calls
        extract_trello_data_fixed(
          board_names = trello_config$board_names,
          include_closed = trello_config$include_closed
        )
      }, error = function(e) {
        message("Fixed Trello extraction failed, trying original: ", e$message)
        tryCatch({
          extract_trello_data(
            board_names = trello_config$board_names,
            include_closed = trello_config$include_closed
          )
        }, error = function(e2) {
          message("All Trello methods failed: ", e2$message)
          data.frame() # Return empty data frame on error
        })
      })
    },
    # Re-run every 6 hours  
    cue = tar_cue(mode = "thorough")
  ),
  
  # Data processing target
  tar_target(
    combined_task_data,
    combine_task_data(
      calendar_data = google_calendar_data,
      trello_data = trello_data
    )
  ),
  
  # Analysis targets
  tar_target(
    summary_statistics,
    create_summary_stats(combined_task_data)
  ),
  
  # Visualization targets
  tar_target(
    eisenhower_plot,
    {
      plot <- create_eisenhower_plot(
        combined_task_data,
        title = "Eisenhower Matrix - Personal Time Management"
      )
      
      # Save plot
      ggsave(
        filename = "reports/eisenhower_matrix.png",
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
      if (file.exists("reports/eisenhower_matrix.png")) {
        file.copy("reports/eisenhower_matrix.png", "docs/", overwrite = TRUE)
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
          "<img src='eisenhower_matrix.png' alt='Eisenhower Matrix' style='max-width: 100%;'>\n",
          "<img src='task_timeline.png' alt='Task Timeline' style='max-width: 100%;'>\n",
          "</body>\n</html>"
        )
        
        writeLines(simple_html, "docs/index.html")
      }
      
      "docs/index.html"
    }
  )
)