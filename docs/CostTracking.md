# Cost Tracking & Budget Management

## Overview

The TranslationFiesta applications include a comprehensive Cost Tracking and Budget Management system to help you monitor your API usage and control your expenses. This feature is available in the Python, Go, and WinUI implementations.

## Core Features

- **Real-time Cost Calculation**: Tracks the number of characters translated and calculates the cost based on the Google Cloud Translation API pricing ($20 per 1 million characters).
- **Monthly Budgets**: Set a monthly spending limit to prevent unexpected charges.
- **Budget Alerts**: Receive alerts when you reach 80% and 100% of your monthly budget.
- **Usage Monitoring**: View detailed reports on your translation usage, including characters translated, cost per translation, and total cost over time.
- **Persistent Storage**: All cost data is saved to a local JSON file, so your history is preserved across sessions.
- **Multi-implementation Tracking**: The system can track costs across different implementations, allowing you to compare the efficiency of each.

## How It Works

The Cost Tracking system works by intercepting each translation request and recording the number of characters being translated. It then calculates the cost of the translation and adds it to a running total for the current month.

### Budgeting

You can set a monthly budget in the application's settings. The Cost Tracker will then monitor your usage and trigger alerts if you approach or exceed your budget.

### Reporting

The Cost Dashboard provides a detailed view of your spending, including:
- **Current Month's Usage**: A real-time view of your spending for the current month.
- **Historical Data**: A history of your translation costs over time.
- **Cost Breakdown**: A breakdown of your costs by language pair and implementation.

## Usage

### Enabling Cost Tracking

Cost tracking is enabled by default when you use the official Google Cloud Translation API. To use this feature, you will need to provide your Google Cloud API key in the application's settings.

### Setting a Budget

1. Open the application's settings or Cost Dashboard.
2. Enter your desired monthly budget in the appropriate field.
3. Save your settings.

### Viewing Reports

1. Open the Cost Dashboard from the application's main menu or toolbar.
2. View the real-time and historical cost data.
3. Generate and export reports as needed.

## Implementation Details

### Python (`TranslationFiestaPy`)
- **`cost_tracker.py`**: Contains the `CostTracker` class, which handles the core logic for tracking costs and managing budgets.
- **`cost_dashboard.py`**: Implements the Tkinter-based UI for the Cost Dashboard.

### Go (`TranslationFiestaGo`)
- **`internal/costtracker/cost_tracker.go`**: Implements the core cost tracking logic.
- **`internal/costtracker/cost_dashboard.go`**: Implements the GUI for the Cost Dashboard (using Fyne).

### WinUI (`TranslationFiesta.WinUI`)
- **`CostTracker.cs`**: Implements the core cost tracking logic.
- **`AnalyticsDashboard.xaml`**: The XAML-based UI for the Cost Dashboard.