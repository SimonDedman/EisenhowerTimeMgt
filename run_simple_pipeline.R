# Simple Pipeline - Bypasses Google OAuth Issues
# Uses manual template data to generate your Eisenhower Matrix

cat("=== Simple Time Management Pipeline ===\n")
cat("Using manual template data (no Google OAuth required)\n\n")

# Load required libraries
library(dplyr)
library(ggplot2)

# Step 1: Extract data from manual template
cat("1. Extracting calendar data...\n")
source("R/google_calendar_alternative.R")
calendar_data <- extract_from_manual_template()

if (nrow(calendar_data) == 0) {
  cat("❌ No data found. Creating template...\n")
  create_manual_data_template()
  calendar_data <- extract_from_manual_template()
}

cat("✅ Found", nrow(calendar_data), "events with", sum(calendar_data$has_metadata, na.rm=TRUE), "tagged events\n")

# Step 2: Combine and process data (skip Trello for now)
cat("\n2. Processing task data...\n")
source("R/visualization.R")

# Create mock Trello data as empty
trello_data <- data.frame()
combined_data <- combine_task_data(calendar_data, trello_data)

cat("✅ Combined data:", nrow(combined_data), "tasks\n")

# Step 3: Create visualizations
cat("\n3. Creating Eisenhower Matrix visualization...\n")
if (nrow(combined_data) > 0) {
  
  # Create main plot
  eisenhower_plot <- create_eisenhower_plot(
    combined_data,
    title = "Eisenhower Matrix - Your Time Management Dashboard"
  )
  
  # Save plot
  if (!dir.exists("reports")) dir.create("reports")
  ggsave(
    filename = "reports/eisenhower_matrix_simple.png",
    plot = eisenhower_plot,
    width = 12, height = 8, dpi = 300, bg = "white"
  )
  cat("✅ Eisenhower matrix saved: reports/eisenhower_matrix_simple.png\n")
  
  # Create timeline plot
  timeline_plot <- create_timeline_plot(combined_data)
  ggsave(
    filename = "reports/task_timeline_simple.png",
    plot = timeline_plot,
    width = 12, height = 6, dpi = 300, bg = "white"
  )
  cat("✅ Timeline plot saved: reports/task_timeline_simple.png\n")
  
} else {
  cat("⚠️ No data to visualize\n")
}

# Step 4: Export data
cat("\n4. Exporting data...\n")
if (nrow(combined_data) > 0) {
  if (!dir.exists("data")) dir.create("data")
  
  write.csv(combined_data, "data/combined_tasks_simple.csv", row.names = FALSE)
  cat("✅ Task data exported: data/combined_tasks_simple.csv\n")
  
  # Create summary
  summary_stats <- create_summary_stats(combined_data)
  if (length(summary_stats) > 0 && !is.null(summary_stats$by_quadrant)) {
    write.csv(summary_stats$by_quadrant, "data/quadrant_summary_simple.csv", row.names = FALSE)
    cat("✅ Quadrant summary: data/quadrant_summary_simple.csv\n")
  }
}

# Step 5: Display results
cat("\n=== RESULTS ===\n")
if (nrow(combined_data) > 0) {
  cat("🎯 Total tasks analyzed:", nrow(combined_data), "\n")
  cat("🏷️ Tasks with #U1I5E7D6h tags:", sum(combined_data$has_metadata %||% FALSE, na.rm=TRUE), "\n")
  
  # Show quadrant breakdown
  if ("quadrant" %in% colnames(combined_data)) {
    quadrant_counts <- table(combined_data$quadrant)
    cat("\n📊 Quadrant Distribution:\n")
    for (q in names(quadrant_counts)) {
      cat("  ", q, ":", quadrant_counts[q], "tasks\n")
    }
  }
  
  # Show calendar breakdown
  if ("source" %in% colnames(combined_data)) {
    source_counts <- table(combined_data$source)
    cat("\n📅 By Calendar:\n")
    for (s in names(source_counts)) {
      cat("  ", s, ":", source_counts[s], "tasks\n")
    }
  }
  
  cat("\n🖼️ View your visualizations:\n")
  cat("   reports/eisenhower_matrix_simple.png\n")
  cat("   reports/task_timeline_simple.png\n")
  
  cat("\n📈 Next steps:\n")
  cat("1. Edit data/manual_calendar_data.csv with your real calendar events\n")
  cat("2. Add #U7I8E6D2h tags to event descriptions\n") 
  cat("3. Re-run: source('run_simple_pipeline.R')\n")
  
} else {
  cat("❌ No tasks found to analyze\n")
  cat("💡 Edit data/manual_calendar_data.csv with your calendar events\n")
}

cat("\n=== Pipeline Complete ===\n")

# Helper function
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}