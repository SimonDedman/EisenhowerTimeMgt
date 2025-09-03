# Personal Time Management with Eisenhower Matrix

An automated R pipeline that extracts task data from Google Calendar and Trello, parses custom urgency/importance/enjoyment/duration tags, and creates interactive Eisenhower Matrix visualizations.

## Overview

This project helps you visualize and analyze your personal productivity using the Eisenhower Decision Matrix. Tasks are plotted on a scatter plot with:

- **X-axis**: Urgency (0-10)
- **Y-axis**: Importance (0-10) 
- **Point size**: Duration in hours
- **Point color**: Enjoyment level (0-10)

The system automatically categorizes tasks into four quadrants:
- **Do First** (Urgent & Important) - Red quadrant
- **Schedule** (Important, Not Urgent) - Blue quadrant  
- **Delegate** (Urgent, Not Important) - Orange quadrant
- **Eliminate** (Neither Urgent nor Important) - Gray quadrant

## Data Format

Add tags to your Google Calendar events or Trello card descriptions in this format:

```
#U[0-10]I[0-10]E[0-10]D[hours]h
```

Examples:
- `#U8I9E3D4h` - Urgency: 8, Importance: 9, Enjoyment: 3, Duration: 4 hours
- `#U2I7E8D1h` - Urgency: 2, Importance: 7, Enjoyment: 8, Duration: 1 hour

## Project Structure

```
EisenhowerTimeMgt/
├── R/                          # R source code
│   ├── google_calendar.R       # Google Calendar API functions
│   ├── trello_data.R          # Trello API functions  
│   └── visualization.R        # Plotting and analysis functions
├── reports/                    # Generated reports and plots
│   ├── eisenhower_report.Rmd  # R Markdown report template
│   └── *.png                  # Generated visualizations
├── data/                       # Exported data files
├── docs/                       # GitHub Pages files
├── .github/workflows/          # GitHub Actions for automation
├── _targets.R                  # Targets pipeline definition
├── run_pipeline.R             # Main execution script
└── README.md                  # This file
```

## Setup Instructions

### 1. R Environment Setup

```r
# Install required packages
install.packages(c(
  "targets", "tarchetypes", "googledrive", "googlesheets4", 
  "trelloR", "ggplot2", "dplyr", "tidyr", "lubridate", 
  "stringr", "rmarkdown", "httr", "jsonlite", "DT", "knitr"
))

# Or use renv for reproducible environment
renv::restore()
```

### 2. Google Calendar Setup

1. **Enable Google Calendar API**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable the Google Calendar API
   - Create credentials (OAuth 2.0 client ID)
   - Download credentials JSON file

2. **Authentication**:
   ```r
   # First run will prompt for browser authentication
   source("R/google_calendar.R")
   setup_google_auth()
   ```

3. **Calendar Configuration**:
   - By default, extracts from your primary calendar
   - Looks for events with Admin-related keywords or metadata tags
   - Modify `calendar_config` in `_targets.R` to customize

### 3. Trello Setup (Optional)

1. **Get API Credentials**:
   - Go to [https://trello.com/app-key](https://trello.com/app-key) 
   - Copy your API key
   - Get token from: `https://trello.com/1/authorize?expiration=never&scope=read&response_type=token&name=EisenhowerTimeMgt&key=YOUR_API_KEY`

2. **Set Environment Variables**:
   ```r
   # Add to .Renviron file
   TRELLO_API_KEY="your_api_key_here"
   TRELLO_TOKEN="your_token_here"
   ```

3. **Test Connection**:
   ```r
   source("R/trello_data.R")
   boards <- get_trello_boards()
   ```

### 4. Running the Pipeline

#### Manual Execution
```r
# Run complete pipeline
source("run_pipeline.R")

# Or run individual steps
library(targets)
tar_make()
```

#### Automated Execution
The pipeline includes a GitHub Actions workflow that:
- Runs every 6 hours automatically
- Updates visualizations with fresh data
- Deploys to GitHub Pages
- Commits updated data files

### 5. GitHub Pages Setup

1. **Repository Setup**:
   ```bash
   git init
   git add .
   git commit -m "Initial time management dashboard"
   git branch -M main
   git remote add origin https://github.com/yourusername/eisenhower-time-management.git
   git push -u origin main
   ```

2. **GitHub Secrets** (for automation):
   - `TRELLO_API_KEY` - Your Trello API key
   - `TRELLO_TOKEN` - Your Trello token
   - `GOOGLE_CREDENTIALS` - Google service account JSON (as single line)

3. **Enable GitHub Pages**:
   - Go to repository Settings > Pages
   - Source: Deploy from a branch
   - Branch: main, folder: /docs

## Usage Examples

### Basic Usage

```r
# Load the pipeline
library(targets)

# Extract data
tar_make(c(google_calendar_data, trello_data))

# Create visualizations
tar_make(eisenhower_plot)

# Generate full report
tar_make(report)
```

### Customizing Data Sources

```r
# Modify _targets.R to customize extraction:

# For specific Google Calendar
tar_target(
  calendar_config,
  list(
    calendar_id = "your_calendar_id@group.calendar.google.com",
    days_back = 60,
    days_forward = 14
  )
)

# For specific Trello boards
tar_target(
  trello_config,
  list(
    board_names = c("Work Projects", "Personal Tasks"),
    include_closed = TRUE
  )
)
```

### Custom Analysis

```r
# Load processed data
tar_load(combined_task_data)

# Custom analysis
high_priority <- combined_task_data %>%
  filter(urgency_final >= 7, importance_final >= 7)

# Time distribution by quadrant
library(ggplot2)
ggplot(combined_task_data, aes(x = quadrant, y = duration_final)) +
  geom_boxplot() +
  labs(title = "Time Distribution by Eisenhower Quadrant")
```

## Output Files

After running the pipeline, you'll get:

1. **Interactive HTML Report**: `reports/eisenhower_report.html`
   - Complete dashboard with plots and analysis
   - Interactive task table
   - Summary statistics

2. **Visualizations**:
   - `reports/eisenhower_matrix.png` - Main scatter plot
   - `reports/task_timeline.png` - Timeline view

3. **Data Exports**:
   - `data/combined_tasks.csv` - All task data
   - `data/quadrant_summary.csv` - Summary by quadrant

4. **GitHub Pages Site**: 
   - `docs/index.html` - Web-accessible dashboard
   - Auto-updates every 6 hours via GitHub Actions

## Troubleshooting

### Common Issues

1. **Google Authentication Fails**:
   ```r
   # Clear cached tokens
   googledrive::drive_deauth()
   googlesheets4::gs4_deauth()
   
   # Re-authenticate
   setup_google_auth()
   ```

2. **No Calendar Data Found**:
   - Check that events contain the `#U1I5E7D6h` format tags
   - Verify calendar ID is correct
   - Ensure events are within the date range

3. **Trello Connection Issues**:
   ```r
   # Test credentials
   Sys.getenv("TRELLO_API_KEY")  # Should not be empty
   Sys.getenv("TRELLO_TOKEN")    # Should not be empty
   ```

4. **Missing Dependencies**:
   ```r
   # Check for missing packages
   tar_renv()  # Updates renv.lock with pipeline dependencies
   renv::restore()
   ```

### Getting Help

- Check the GitHub Issues for common problems
- Use `tar_visnetwork()` to visualize the pipeline
- Enable verbose logging: `options(targets.verbose = TRUE)`

## Customization

### Adding New Data Sources

1. Create extraction function in new R file
2. Add to `_targets.R` pipeline
3. Update `combine_task_data()` function
4. Test with `tar_make()`

### Custom Visualizations

Add new visualization functions to `R/visualization.R`:

```r
create_custom_plot <- function(data) {
  # Your custom ggplot code
}

# Add to _targets.R
tar_target(
  custom_plot,
  create_custom_plot(combined_task_data)
)
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Credits

Built with:
- [targets](https://books.ropensci.org/targets/) - R pipeline framework
- [ggplot2](https://ggplot2.tidyverse.org/) - Data visualization
- [googledrive](https://googledrive.tidyverse.org/) - Google API integration
- [trelloR](https://cran.r-project.org/package=trelloR) - Trello API client
- [GitHub Actions](https://github.com/features/actions) - Automation
- [GitHub Pages](https://pages.github.com/) - Web hosting

---

**Happy time management! 📊⏰**