#!/usr/bin/env python3
"""
cost_dashboard.py

Cost management dashboard for TranslationFiesta.
Provides UI components for viewing and managing translation costs.
"""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
from typing import Optional, Callable
import threading
import time
from datetime import datetime, timedelta

from cost_tracker import get_cost_tracker, CostEntry
from enhanced_logger import get_logger


class CostDashboard:
    """Cost management dashboard with budget monitoring and reporting"""

    def __init__(self, parent_window: tk.Tk, on_budget_alert: Optional[Callable[[str, float], None]] = None):
        self.parent = parent_window
        self.logger = get_logger()
        self.cost_tracker = get_cost_tracker()
        self.on_budget_alert = on_budget_alert

        # Register budget alert callback
        if self.on_budget_alert:
            self.cost_tracker.add_alert_callback(self.on_budget_alert)

        # Create dashboard window
        self.window = tk.Toplevel(parent_window)
        self.window.title("TranslationFiesta - Cost Management")
        self.window.geometry("800x600")
        self.window.resizable(True, True)

        # Initialize UI
        self._setup_ui()

        # Start periodic updates
        self._start_update_timer()

        self.logger.info("Cost dashboard initialized")

    def _setup_ui(self) -> None:
        """Setup the dashboard UI components"""
        # Main container
        main_frame = ttk.Frame(self.window, padding="10")
        main_frame.pack(fill=tk.BOTH, expand=True)

        # Title
        title_label = ttk.Label(
            main_frame,
            text="Translation Cost Management",
            font=("Arial", 16, "bold")
        )
        title_label.pack(pady=(0, 10))

        # Create notebook for tabs
        notebook = ttk.Notebook(main_frame)
        notebook.pack(fill=tk.BOTH, expand=True)

        # Budget tab
        budget_tab = ttk.Frame(notebook)
        notebook.add(budget_tab, text="Budget & Alerts")

        # Reports tab
        reports_tab = ttk.Frame(notebook)
        notebook.add(reports_tab, text="Cost Reports")

        # History tab
        history_tab = ttk.Frame(notebook)
        notebook.add(history_tab, text="Transaction History")

        # Settings tab
        settings_tab = ttk.Frame(notebook)
        notebook.add(settings_tab, text="Settings")

        # Setup each tab
        self._setup_budget_tab(budget_tab)
        self._setup_reports_tab(reports_tab)
        self._setup_history_tab(history_tab)
        self._setup_settings_tab(settings_tab)

    def _setup_budget_tab(self, parent: ttk.Frame) -> None:
        """Setup budget monitoring tab"""
        # Budget status section
        status_frame = ttk.LabelFrame(parent, text="Current Budget Status", padding="10")
        status_frame.pack(fill=tk.X, pady=(0, 10))

        # Budget display
        self.budget_label = ttk.Label(status_frame, text="Loading...", font=("Arial", 12))
        self.budget_label.pack(anchor=tk.W)

        self.usage_bar = ttk.Progressbar(status_frame, orient=tk.HORIZONTAL, length=400, mode='determinate')
        self.usage_bar.pack(fill=tk.X, pady=(5, 0))

        self.alert_label = ttk.Label(status_frame, text="", foreground="red")
        self.alert_label.pack(anchor=tk.W, pady=(5, 0))

        # Quick actions
        actions_frame = ttk.LabelFrame(parent, text="Quick Actions", padding="10")
        actions_frame.pack(fill=tk.X, pady=(10, 0))

        ttk.Button(
            actions_frame,
            text="Refresh Status",
            command=self._update_budget_display
        ).pack(side=tk.LEFT, padx=(0, 10))

        ttk.Button(
            actions_frame,
            text="Reset Monthly Usage",
            command=self._reset_budget
        ).pack(side=tk.LEFT)

    def _setup_reports_tab(self, parent: ttk.Frame) -> None:
        """Setup cost reports tab"""
        # Report options
        options_frame = ttk.Frame(parent)
        options_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(options_frame, text="Report Period:").pack(side=tk.LEFT, padx=(0, 5))

        self.report_period = tk.StringVar(value="30")
        period_combo = ttk.Combobox(
            options_frame,
            textvariable=self.report_period,
            values=["7", "30", "90", "365"],
            state="readonly",
            width=10
        )
        period_combo.pack(side=tk.LEFT, padx=(0, 10))

        ttk.Button(
            options_frame,
            text="Generate Report",
            command=self._generate_report
        ).pack(side=tk.LEFT)

        # Report display
        self.report_text = scrolledtext.ScrolledText(parent, wrap=tk.WORD, height=20)
        self.report_text.pack(fill=tk.BOTH, expand=True)

        # Initial report
        self._generate_report()

    def _setup_history_tab(self, parent: ttk.Frame) -> None:
        """Setup transaction history tab"""
        # History controls
        controls_frame = ttk.Frame(parent)
        controls_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(controls_frame, text="Show last:").pack(side=tk.LEFT, padx=(0, 5))

        self.history_limit = tk.StringVar(value="50")
        limit_combo = ttk.Combobox(
            controls_frame,
            textvariable=self.history_limit,
            values=["10", "25", "50", "100", "500"],
            state="readonly",
            width=10
        )
        limit_combo.pack(side=tk.LEFT, padx=(0, 10))

        ttk.Button(
            controls_frame,
            text="Refresh History",
            command=self._update_history_display
        ).pack(side=tk.LEFT, padx=(0, 10))

        ttk.Button(
            controls_frame,
            text="Clear Old Entries",
            command=self._clear_old_entries
        ).pack(side=tk.LEFT)

        # History display
        columns = ("Timestamp", "Characters", "Cost", "Languages", "Implementation")
        self.history_tree = ttk.Treeview(parent, columns=columns, show="headings", height=15)

        for col in columns:
            self.history_tree.heading(col, text=col)
            self.history_tree.column(col, width=120)

        scrollbar = ttk.Scrollbar(parent, orient=tk.VERTICAL, command=self.history_tree.yview)
        self.history_tree.configure(yscrollcommand=scrollbar.set)

        self.history_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Initial history load
        self._update_history_display()

    def _setup_settings_tab(self, parent: ttk.Frame) -> None:
        """Setup settings tab"""
        # Budget settings
        budget_frame = ttk.LabelFrame(parent, text="Budget Settings", padding="10")
        budget_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(budget_frame, text="Monthly Budget ($):").grid(row=0, column=0, sticky=tk.W, pady=2)
        self.budget_entry = ttk.Entry(budget_frame, width=15)
        self.budget_entry.grid(row=0, column=1, sticky=tk.W, padx=(10, 0), pady=2)

        ttk.Label(budget_frame, text="Alert Threshold (%):").grid(row=1, column=0, sticky=tk.W, pady=2)
        self.alert_threshold_entry = ttk.Entry(budget_frame, width=15)
        self.alert_threshold_entry.grid(row=1, column=1, sticky=tk.W, padx=(10, 0), pady=2)

        ttk.Button(
            budget_frame,
            text="Update Budget",
            command=self._update_budget_settings
        ).grid(row=2, column=0, columnspan=2, pady=(10, 0))

        # Load current settings
        self._load_budget_settings()

        # Cost calculation info
        info_frame = ttk.LabelFrame(parent, text="Pricing Information", padding="10")
        info_frame.pack(fill=tk.X, pady=(10, 0))

        info_text = f"""
Google Cloud Translation API Pricing:
• $20.00 per 1 million characters
• Standard and Advanced editions use the same base pricing
• Characters are counted in the translated text
• No minimum fee or setup costs

Current Cost Calculation:
• 1 character = ${20.00 / 1_000_000:.8f}
• 1,000 characters = ${20.00 / 1_000:.4f}
• 10,000 characters = ${20.00 / 100:.4f}
• 100,000 characters = ${20.00 / 10:.4f}
        """.strip()

        info_label = ttk.Label(info_frame, text=info_text, justify=tk.LEFT)
        info_label.pack(anchor=tk.W)

    def _update_budget_display(self) -> None:
        """Update budget status display"""
        try:
            status = self.cost_tracker.get_budget_status()

            # Update budget label
            budget_text = (
                f"Monthly Budget: ${status['monthly_limit_usd']:.2f} | "
                f"Current Usage: ${status['current_month_usage_usd']:.2f} | "
                f"Remaining: ${status['remaining_budget_usd']:.2f}"
            )
            self.budget_label.config(text=budget_text)

            # Update progress bar
            if status['monthly_limit_usd'] > 0:
                progress = min(100, (status['current_month_usage_usd'] / status['monthly_limit_usd']) * 100)
                self.usage_bar.config(value=progress)

                # Color coding
                if status['is_over_limit']:
                    self.usage_bar.config(style="Red.Horizontal.TProgressbar")
                elif status['is_near_limit']:
                    self.usage_bar.config(style="Orange.Horizontal.TProgressbar")
                else:
                    self.usage_bar.config(style="Green.Horizontal.TProgressbar")

            # Update alert label
            if status['is_over_limit']:
                self.alert_label.config(text="⚠️ BUDGET EXCEEDED!", foreground="red")
            elif status['is_near_limit']:
                self.alert_label.config(text="⚠️ Approaching budget limit", foreground="orange")
            else:
                self.alert_label.config(text="", foreground="black")

        except Exception as e:
            self.logger.error(f"Failed to update budget display: {e}")
            self.budget_label.config(text=f"Error loading budget status: {e}")

    def _generate_report(self) -> None:
        """Generate and display cost report"""
        try:
            days = int(self.report_period.get())
            report = self.cost_tracker.get_cost_report(days=days)

            report_text = f"""
TRANSLATION COST REPORT
{'='*50}
Period: Last {days} days
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

SUMMARY
-------
Total Cost: ${report['total_cost_usd']:.4f}
Total Characters: {report['total_characters']:,}
Average Cost per Character: ${report['average_cost_per_char']:.8f}
Number of Translations: {report['entry_count']:,}

Google Cloud Pricing: ${report['cost_per_million_chars']:.2f} per 1M characters

IMPLEMENTATION BREAKDOWN
{'-'*30}
"""

            if 'by_implementation' in report:
                for impl, stats in report['by_implementation'].items():
                    report_text += f"""
{impl.upper()}:
  • Cost: ${stats['total_cost_usd']:.4f}
  • Characters: {stats['total_characters']:,}
  • Translations: {stats['entry_count']:,}
"""

            self.report_text.delete(1.0, tk.END)
            self.report_text.insert(tk.END, report_text.strip())

        except Exception as e:
            self.logger.error(f"Failed to generate report: {e}")
            self.report_text.delete(1.0, tk.END)
            self.report_text.insert(tk.END, f"Error generating report: {e}")

    def _update_history_display(self) -> None:
        """Update transaction history display"""
        try:
            limit = int(self.history_limit.get())
            entries = self.cost_tracker.get_recent_entries(limit=limit)

            # Clear existing items
            for item in self.history_tree.get_children():
                self.history_tree.delete(item)

            # Add new items
            for entry in entries:
                timestamp = datetime.fromtimestamp(entry.timestamp).strftime('%Y-%m-%d %H:%M:%S')
                cost_str = f"${entry.cost_usd:.6f}"
                languages = f"{entry.source_lang}→{entry.target_lang}"

                self.history_tree.insert("", tk.END, values=(
                    timestamp,
                    f"{entry.characters:,}",
                    cost_str,
                    languages,
                    entry.implementation
                ))

        except Exception as e:
            self.logger.error(f"Failed to update history display: {e}")

    def _clear_old_entries(self) -> None:
        """Clear old cost entries"""
        if messagebox.askyesno(
            "Confirm",
            "This will permanently delete cost entries older than 365 days.\nContinue?"
        ):
            try:
                removed_count = self.cost_tracker.clear_old_entries(days_to_keep=365)
                messagebox.showinfo("Success", f"Cleared {removed_count} old entries")
                self._update_history_display()
                self._generate_report()
            except Exception as e:
                messagebox.showerror("Error", f"Failed to clear old entries: {e}")

    def _reset_budget(self) -> None:
        """Reset monthly budget usage"""
        if messagebox.askyesno(
            "Confirm",
            "This will reset the current month's budget usage to $0.00.\nContinue?"
        ):
            try:
                self.cost_tracker.reset_budget()
                self._update_budget_display()
                messagebox.showinfo("Success", "Monthly budget usage has been reset")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to reset budget: {e}")

    def _load_budget_settings(self) -> None:
        """Load current budget settings into UI"""
        try:
            status = self.cost_tracker.get_budget_status()
            self.budget_entry.delete(0, tk.END)
            self.budget_entry.insert(0, str(status['monthly_limit_usd']))

            self.alert_threshold_entry.delete(0, tk.END)
            self.alert_threshold_entry.insert(0, str(status['alert_threshold_percent']))
        except Exception as e:
            self.logger.error(f"Failed to load budget settings: {e}")

    def _update_budget_settings(self) -> None:
        """Update budget settings from UI"""
        try:
            monthly_limit = float(self.budget_entry.get())
            alert_threshold = float(self.alert_threshold_entry.get())

            if monthly_limit <= 0:
                messagebox.showerror("Error", "Monthly budget must be greater than $0.00")
                return

            if not (0 < alert_threshold <= 100):
                messagebox.showerror("Error", "Alert threshold must be between 0 and 100")
                return

            self.cost_tracker.set_budget(monthly_limit, alert_threshold)
            self._update_budget_display()
            messagebox.showinfo("Success", "Budget settings updated successfully")

        except ValueError:
            messagebox.showerror("Error", "Please enter valid numeric values")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to update budget settings: {e}")

    def _start_update_timer(self) -> None:
        """Start periodic UI updates"""
        def update_loop():
            while True:
                try:
                    # Update budget display on main thread
                    self.window.after(0, self._update_budget_display)
                except:
                    break
                time.sleep(30)  # Update every 30 seconds

        thread = threading.Thread(target=update_loop, daemon=True)
        thread.start()

    def show(self) -> None:
        """Show the cost dashboard window"""
        self.window.deiconify()
        self.window.focus()

    def hide(self) -> None:
        """Hide the cost dashboard window"""
        self.window.withdraw()


def show_cost_dashboard(parent_window: tk.Tk, on_budget_alert: Optional[Callable[[str, float], None]] = None) -> CostDashboard:
    """
    Convenience function to create and show cost dashboard

    Args:
        parent_window: Parent Tkinter window
        on_budget_alert: Optional callback for budget alerts

    Returns:
        CostDashboard instance
    """
    dashboard = CostDashboard(parent_window, on_budget_alert)
    dashboard.show()
    return dashboard


# Example usage
if __name__ == "__main__":
    # Create a simple test window
    root = tk.Tk()
    root.title("Cost Dashboard Test")
    root.geometry("400x200")

    def budget_alert_handler(alert_type, current_usage):
        print(f"Budget Alert: {alert_type} - Usage: ${current_usage:.2f}")

    # Create dashboard button
    ttk.Button(
        root,
        text="Open Cost Dashboard",
        command=lambda: show_cost_dashboard(root, budget_alert_handler)
    ).pack(pady=20)

    root.mainloop()