# R Functions Directory

This directory contains the core R functions used by the targets pipeline.

## 🎯 Core Functions (Primary Methods)
- `google_calendar_service_account.R` - **PRIMARY**: Google Calendar via service account
- `trello_data_fixed.R` - **PRIMARY**: Trello via direct HTTP API
- `visualization.R` - Data combination, plotting, and Eisenhower Matrix creation

## 🔄 Active Fallback Methods
- `google_calendar_simple.R` - Mock data generation for testing
- `google_calendar_fixed.R` - OAuth token caching method

## 📁 `/fallback_methods/` - Legacy Fallback Methods
- `google_calendar.R` - Original Google Calendar implementation
- `google_calendar_real.R` - Real OAuth implementation  
- `google_calendar_alternative.R` - Alternative authentication approaches
- `trello_data.R` - Original trelloR package implementation

## 🚀 Function Loading Order (in _targets.R)
1. **Primary methods** loaded first (service account + fixed Trello)
2. **Fallback methods** loaded as backup options
3. **Pipeline tries methods in order**: Service Account → Fixed → Real → Alternative → Simple/Mock

## ℹ️ Usage
The targets pipeline automatically tries methods in order of reliability:
- Service Account (most reliable for CLI)
- Fixed methods (cached tokens)  
- Real methods (interactive OAuth)
- Simple methods (mock data fallback)