# Scripts Directory

This directory contains utility and setup scripts organized by purpose:

## 📁 `/setup/` - Setup and Configuration Scripts
- `setup_complete_google_auth.R` - Complete Google Calendar service account setup
- `setup_google_service_account.R` - Core service account configuration functions
- `setup_google_api.R` - Legacy OAuth setup (deprecated)
- `setup_google_calendar.R` - Legacy calendar setup (deprecated)
- `get_api_key_instructions.R` - API key setup instructions (deprecated)

## 📁 `/examples/` - Example and Demo Scripts  
- `run_simple_pipeline.R` - Example pipeline with mock data

## 📁 `/testing/` - Debugging and Testing Scripts
- `fix_google_auth.R` - Google authentication debugging
- `fix_trello_auth.R` - Trello authentication debugging
- `test_calendar_with_api_key.R` - Calendar API testing
- `test_public_calendar.R` - Public calendar testing
- `test_your_calendar.R` - Personal calendar testing

## 🚀 Main Entry Points (in project root)
- `_targets.R` - Main pipeline definition
- `run_pipeline.R` - Pipeline execution script

## ℹ️ Usage
Most users should only need:
1. `scripts/setup/setup_complete_google_auth.R` for initial setup
2. `_targets.R` / `tar_make()` for running the pipeline