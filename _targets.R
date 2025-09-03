# _targets.R file for automated time management pipeline
# This file defines the targets workflow for data extraction, processing, and visualization

library(targets)
library(tarchetypes)

# Source all R functions
source("R/google_calendar.R")
source("R/trello_data.R") 
source("R/visualization.R")

# Set target options
tar_option_set(
  packages = c(
    "googledrive", "googlesheets4", "trelloR", 
    "ggplot2", "dplyr", "tidyr", "lubridate", "stringr", 
    "rmarkdown", "httr", "jsonlite"
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
      calendar_id = "primary",
      days_back = 30,
      days_forward = 7
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
      # Set up authentication
      tryCatch({
        setup_google_auth()
        extract_google_calendar_data(
          calendar_id = calendar_config$calendar_id,
          days_back = calendar_config$days_back,
          days_forward = calendar_config$days_forward
        )
      }, error = function(e) {
        message("Google Calendar extraction failed: ", e$message)
        data.frame() # Return empty data frame on error
      })
    },
    # Re-run every 6 hours
    cue = tar_cue(mode = "thorough", age = as.difftime(6, units = "hours"))
  ),
  
  tar_target(
    trello_data,
    {
      tryCatch({
        extract_trello_data(
          board_names = trello_config$board_names,
          include_closed = trello_config$include_closed
        )
      }, error = function(e) {
        message("Trello extraction failed: ", e$message)
        data.frame() # Return empty data frame on error
      })
    },
    # Re-run every 6 hours  
    cue = tar_cue(mode = "thorough", age = as.difftime(6, units = "hours"))
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
  tar_render(
    report,
    "reports/eisenhower_report.Rmd",
    output_file = "reports/eisenhower_report.html"
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