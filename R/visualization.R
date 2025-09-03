#' Create Eisenhower Matrix Visualization
#' 
#' Creates scatter plots showing tasks plotted by urgency (x-axis) and importance (y-axis)
#' Points are sized by duration and colored by enjoyment level
#' 
#' @import ggplot2
#' @import dplyr
#' @import scales

library(ggplot2)
library(dplyr)
library(scales)
library(ggrepel)

#' Combine Google Calendar and Trello data
#' 
#' @param calendar_data Data frame from extract_google_calendar_data()
#' @param trello_data Data frame from extract_trello_data()
#' @return Combined and standardized data frame
combine_task_data <- function(calendar_data = NULL, trello_data = NULL) {
  
  combined_data <- list()
  
  # Process calendar data
  if (!is.null(calendar_data) && nrow(calendar_data) > 0) {
    cal_processed <- calendar_data %>%
      filter(has_metadata) %>%
      mutate(
        source = ifelse("calendar_name" %in% colnames(calendar_data), calendar_name, "Google Calendar"),
        task_title = summary,
        urgency_final = urgency,
        importance_final = importance,
        enjoyment_final = enjoyment,
        duration_final = ifelse(!is.na(duration_tagged), duration_tagged, duration_calc),
        due_date_final = end_time,
        status = "Scheduled",
        project_context = ifelse("calendar_name" %in% colnames(calendar_data), 
                               paste(calendar_name, "Calendar"), "Calendar"),
        # Preserve category if it exists
        category = ifelse("category" %in% colnames(calendar_data), category, NA)
      ) %>%
      select(source, task_title, urgency_final, importance_final, enjoyment_final, 
             duration_final, due_date_final, status, project_context, description, category)
    
    combined_data[["calendar"]] <- cal_processed
  }
  
  # Process Trello data  
  if (!is.null(trello_data) && nrow(trello_data) > 0) {
    trello_processed <- trello_data %>%
      filter(has_metadata | !is.na(urgency_final)) %>%
      mutate(
        source = "Trello",
        task_title = card_name,
        urgency_final = ifelse(!is.na(urgency), urgency, urgency_final),
        importance_final = ifelse(!is.na(importance), importance, 5), # Default to medium importance
        enjoyment_final = ifelse(!is.na(enjoyment), enjoyment, 5), # Default to neutral enjoyment
        duration_final = ifelse(!is.na(duration_tagged), duration_tagged, 2), # Default 2 hours
        due_date_final = due_date,
        status = ifelse("list_name" %in% colnames(trello_data) && !is.na(list_name), list_name, "Open"),
        project_context = board_name,
        # Preserve category if it exists
        category = ifelse("category" %in% colnames(trello_data), category, NA)
      ) %>%
      select(source, task_title, urgency_final, importance_final, enjoyment_final, 
             duration_final, due_date_final, status, project_context, description, category)
    
    combined_data[["trello"]] <- trello_processed
  }
  
  if (length(combined_data) == 0) {
    message("No data to combine")
    return(data.frame())
  }
  
  # Combine all sources
  result <- do.call(rbind, combined_data)
  
  # Clean and validate data
  result <- result %>%
    filter(
      !is.na(urgency_final) & urgency_final >= 0 & urgency_final <= 10,
      !is.na(importance_final) & importance_final >= 0 & importance_final <= 10,
      !is.na(enjoyment_final) & enjoyment_final >= 0 & enjoyment_final <= 10,
      !is.na(duration_final) & duration_final > 0
    ) %>%
    mutate(
      # Ensure values are in valid ranges
      urgency_final = pmax(0, pmin(10, urgency_final)),
      importance_final = pmax(0, pmin(10, importance_final)),
      enjoyment_final = pmax(0, pmin(10, enjoyment_final)),
      duration_final = pmax(0.1, duration_final),
      
      # Create quadrant labels
      quadrant = case_when(
        urgency_final >= 5 & importance_final >= 5 ~ "Do First\n(Urgent & Important)",
        urgency_final < 5 & importance_final >= 5 ~ "Schedule\n(Important, Not Urgent)",
        urgency_final >= 5 & importance_final < 5 ~ "Delegate\n(Urgent, Not Important)", 
        TRUE ~ "Eliminate\n(Not Urgent, Not Important)"
      ),
      
      # Create enjoyment categories
      enjoyment_category = case_when(
        enjoyment_final >= 7 ~ "High Enjoyment (7-10)",
        enjoyment_final >= 4 ~ "Medium Enjoyment (4-6)",
        TRUE ~ "Low Enjoyment (0-3)"
      )
    )
  
  return(result)
}

#' Combine work and home task data
#' 
#' @param work_data Work task data from work_task_data target
#' @param home_data Home task data from home_task_data target
#' @return Combined data frame with data_category column
combine_work_home_data <- function(work_data, home_data) {
  
  # Add category to work data
  if(nrow(work_data) > 0) {
    work_data$data_category <- "Work"
  } else {
    work_data <- data.frame()
  }
  
  # Add category to home data
  if(nrow(home_data) > 0) {
    home_data$data_category <- "Home"
  } else {
    home_data <- data.frame()
  }
  
  # Combine the data
  if(nrow(work_data) == 0 && nrow(home_data) == 0) {
    return(data.frame())
  } else if(nrow(work_data) == 0) {
    return(home_data)
  } else if(nrow(home_data) == 0) {
    return(work_data)
  } else {
    return(rbind(work_data, home_data))
  }
}

#' Create the main Eisenhower Matrix scatter plot
#' 
#' @param data Combined task data from combine_task_data()
#' @param title Plot title
#' @param size_range Range for point sizes (default: c(2, 12))
#' @param alpha_level Transparency level (default: 0.7)
#' @return ggplot object
create_eisenhower_plot <- function(data, 
                                  title = "Eisenhower Matrix - Task Management Dashboard",
                                  size_range = c(2, 12),
                                  alpha_level = 0.7) {
  
  if (nrow(data) == 0) {
    return(ggplot() + 
           annotate("text", x = 5, y = 5, label = "No data available", size = 6) +
           labs(title = title) +
           theme_minimal())
  }
  
  # Create the plot
  p <- ggplot(data, aes(x = urgency_final, y = importance_final)) +
    
    # Add quadrant background rectangles
    annotate("rect", xmin = 5, xmax = 10, ymin = 5, ymax = 10, 
             fill = "#ff9999", alpha = 0.2) + # Do First (red)
    annotate("rect", xmin = 0, xmax = 5, ymin = 5, ymax = 10, 
             fill = "#99ccff", alpha = 0.2) + # Schedule (blue)
    annotate("rect", xmin = 5, xmax = 10, ymin = 0, ymax = 5, 
             fill = "#ffcc99", alpha = 0.2) + # Delegate (orange)
    annotate("rect", xmin = 0, xmax = 5, ymin = 0, ymax = 5, 
             fill = "#cccccc", alpha = 0.2) + # Eliminate (gray)
    
    # Add quadrant lines
    geom_vline(xintercept = 5, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    geom_hline(yintercept = 5, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    
    # Add points - sized by duration, colored by enjoyment, shaped by data category
    geom_point(aes(size = duration_final, 
                   color = enjoyment_final,
                   shape = ifelse("data_category" %in% colnames(data), 
                                 data_category, 
                                 ifelse("category" %in% colnames(data), category, source))),
               alpha = alpha_level,
               stroke = 0.5) +
    
    # Add text labels for tasks with smart positioning to avoid overlap
    geom_text_repel(aes(label = ifelse(nchar(task_title) > 30, 
                                       paste0(substr(task_title, 1, 27), "..."),
                                       task_title)), 
                    size = 2.5, 
                    max.overlaps = Inf,
                    box.padding = 0.35,
                    point.padding = 0.25,
                    segment.color = "gray50",
                    segment.size = 0.25,
                    min.segment.length = 0.1,
                    force = 1.5,
                    max.iter = 4000,
                    seed = 42) +
    
    # Styling
    scale_size_continuous(name = "Duration\n(hours)", 
                         range = size_range,
                         breaks = c(1, 3, 6, 12, 24),
                         labels = c("1h", "3h", "6h", "12h", "24h+")) +
    
    scale_color_gradient2(name = "Enjoyment\nLevel", 
                         low = "#d73027", 
                         mid = "#ffffbf", 
                         high = "#1a9850",
                         midpoint = 5,
                         breaks = c(0, 2.5, 5, 7.5, 10),
                         labels = c("0", "2.5", "5", "7.5", "10")) +
    
    scale_shape_manual(name = "Category",
                      values = c("Work" = 15,  # Square for Work
                                 "Home" = 16,  # Circle for Home
                                 "Google Calendar" = 16, 
                                 "Trello" = 17, 
                                 "Admin" = 16,  # Circle for Admin (Home)
                                 "Marine" = 15), # Square for Marine (Work)
                      na.value = 16) +
    
    # Scales and labels
    scale_x_continuous(name = "Urgency →", 
                      limits = c(0, 10), 
                      breaks = c(0, 2.5, 5, 7.5, 10)) +
    
    scale_y_continuous(name = "Importance →", 
                      limits = c(0, 10), 
                      breaks = c(0, 2.5, 5, 7.5, 10)) +
    
    # Add quadrant labels
    annotate("text", x = 7.5, y = 9.5, label = "DO FIRST", 
             fontface = "bold", color = "#cc0000", size = 4) +
    annotate("text", x = 2.5, y = 9.5, label = "SCHEDULE", 
             fontface = "bold", color = "#0066cc", size = 4) +
    annotate("text", x = 7.5, y = 0.5, label = "DELEGATE", 
             fontface = "bold", color = "#cc6600", size = 4) +
    annotate("text", x = 2.5, y = 0.5, label = "ELIMINATE", 
             fontface = "bold", color = "#666666", size = 4) +
    
    # Theme
    labs(title = title,
         subtitle = paste0("Tasks plotted by urgency vs importance | ",
                          "Point size = duration, color = enjoyment | ",
                          "Data from: ", paste(unique(data$source), collapse = ", ")),
         caption = paste0("Generated on ", Sys.Date(), 
                         " | Total tasks: ", nrow(data))) +
    
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 12),
      plot.caption = element_text(hjust = 1, size = 10, color = "gray50"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal"
    )
  
  return(p)
}

#' Create summary statistics table
#' 
#' @param data Combined task data
#' @return data.frame with summary statistics
create_summary_stats <- function(data) {
  if (nrow(data) == 0) {
    return(data.frame(Metric = "No data", Value = ""))
  }
  
  quadrant_summary <- data %>%
    group_by(quadrant) %>%
    summarise(
      count = n(),
      avg_duration = round(mean(duration_final, na.rm = TRUE), 1),
      total_duration = round(sum(duration_final, na.rm = TRUE), 1),
      avg_enjoyment = round(mean(enjoyment_final, na.rm = TRUE), 1),
      .groups = "drop"
    )
  
  source_summary <- data %>%
    group_by(source) %>%
    summarise(
      count = n(),
      avg_urgency = round(mean(urgency_final, na.rm = TRUE), 1),
      avg_importance = round(mean(importance_final, na.rm = TRUE), 1),
      .groups = "drop"
    )
  
  overall_stats <- data.frame(
    Metric = c("Total Tasks", "Total Hours", "Avg Urgency", "Avg Importance", "Avg Enjoyment"),
    Value = c(
      nrow(data),
      round(sum(data$duration_final, na.rm = TRUE), 1),
      round(mean(data$urgency_final, na.rm = TRUE), 1),
      round(mean(data$importance_final, na.rm = TRUE), 1),
      round(mean(data$enjoyment_final, na.rm = TRUE), 1)
    )
  )
  
  return(list(
    overall = overall_stats,
    by_quadrant = quadrant_summary,
    by_source = source_summary
  ))
}

#' Create a time-based analysis plot
#' 
#' @param data Combined task data
#' @return ggplot object showing tasks over time
create_timeline_plot <- function(data) {
  if (nrow(data) == 0 || all(is.na(data$due_date_final))) {
    return(ggplot() + 
           annotate("text", x = Sys.Date(), y = 5, label = "No timeline data available", size = 6) +
           theme_minimal())
  }
  
  timeline_data <- data %>%
    filter(!is.na(due_date_final)) %>%
    mutate(due_date = as.Date(due_date_final))
  
  ggplot(timeline_data, aes(x = due_date, y = importance_final)) +
    geom_point(aes(size = duration_final, color = urgency_final), alpha = 0.7) +
    geom_text(aes(label = stringr::str_wrap(task_title, 15)), 
              size = 2, vjust = -0.5, check_overlap = TRUE) +
    scale_size_continuous(name = "Duration (h)", range = c(2, 10)) +
    scale_color_gradient(name = "Urgency", low = "blue", high = "red") +
    scale_x_date(date_labels = "%b %d", date_breaks = "1 week") +
    labs(title = "Task Timeline by Due Date",
         x = "Due Date", y = "Importance") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}