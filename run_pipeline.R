# run_pipeline.R - Main script to execute the time management pipeline
# 
# This script runs the complete pipeline to extract data from Google Calendar
# and Trello, create visualizations, and generate reports.

# Load required packages
library(targets)

# Print pipeline status
cat("=== Personal Time Management Pipeline ===\n")
cat("Starting pipeline execution at:", as.character(Sys.time()), "\n\n")

# Check pipeline status
cat("Current pipeline status:\n")
tar_glimpse()

cat("\n=== Running Pipeline ===\n")

# Run the complete pipeline
result <- tar_make()

cat("\n=== Pipeline Complete ===\n")
cat("Finished at:", as.character(Sys.time()), "\n")

# Print summary of outputs
if (file.exists("reports/eisenhower_report.html")) {
  cat("✓ HTML report generated: reports/eisenhower_report.html\n")
}

if (file.exists("reports/eisenhower_matrix.png")) {
  cat("✓ Eisenhower matrix plot: reports/eisenhower_matrix.png\n")
}

if (file.exists("reports/task_timeline.png")) {
  cat("✓ Timeline plot: reports/task_timeline.png\n") 
}

if (file.exists("data/combined_tasks.csv")) {
  cat("✓ Task data exported: data/combined_tasks.csv\n")
}

if (file.exists("docs/index.html")) {
  cat("✓ GitHub Pages files ready: docs/index.html\n")
}

cat("\nTo view your dashboard:\n")
cat("1. Open reports/eisenhower_report.html in your browser\n")
cat("2. Or push to GitHub and enable GitHub Pages to view online\n")

# Load and print quick summary
if (tar_exist_objects("combined_task_data")) {
  tar_load(combined_task_data)
  
  if (nrow(combined_task_data) > 0) {
    cat(paste("\n📊 Found", nrow(combined_task_data), "tasks from", 
              length(unique(combined_task_data$source)), "data source(s)\n"))
    
    quadrant_counts <- table(combined_task_data$quadrant)
    cat("Quadrant distribution:\n")
    for (i in 1:length(quadrant_counts)) {
      cat(paste("-", names(quadrant_counts)[i], ":", quadrant_counts[i], "tasks\n"))
    }
  } else {
    cat("\n⚠️  No task data found. Check your API credentials and data sources.\n")
    cat("See README.md for setup instructions.\n")
  }
} else {
  cat("\n⚠️  Pipeline did not complete successfully. Check for errors above.\n")
}