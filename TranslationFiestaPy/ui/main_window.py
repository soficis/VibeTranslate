#!/usr/bin/env python3
"""
TranslationFiesta - Back-translation using Google's unofficial API
A Python port of FreeTranslateWin with enhanced features and festive flair

Features:
- Back-translation: English -> Japanese -> English
- Simple GUI with tkinter
- Async translation using threading
- Error handling for network issues
- Status updates during translation
- Input validation
- Cross-platform support
"""

import os
import platform
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext, ttk

import requests

if platform.system() == "Windows":
    import ctypes
try:
    from tkinterweb import HtmlFrame
except ImportError:
    # Fallback if tkinterweb is not available or doesn't have HtmlFrame
    HtmlFrame = None

from app_paths import get_exports_dir
from batch_processor import BatchProcessor
from enhanced_logger import get_logger
from epub_processor import EpubProcessor
from exceptions import get_user_friendly_message
from file_utils import load_text_from_path
from provider_ids import (
    PROVIDER_GOOGLE_UNOFFICIAL,
    PROVIDER_LABELS,
    normalize_provider_id,
)
from settings_storage import get_settings_storage
from translation_services import TranslationService

from .theme import build_themes, toggle_button_label

APP_DISPLAY_NAME = "TranslationFiesta Python"


class TranslationFiesta:
    def __init__(self, root):
        self.root = root
        self.root.title(APP_DISPLAY_NAME)

        # DPI Awareness and Scaling
        self.dpi_factor = self.get_dpi_factor()
        self.scale_factor = self.dpi_factor / 96.0 if self.dpi_factor else 1.0

        # Initialize storage modules
        self.settings = get_settings_storage()

        # Load window geometry from settings
        geometry = self.settings.get_window_geometry()
        self.root.geometry(geometry)
        self.root.resizable(True, True)

        # Configure grid weights for responsive layout
        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_rowconfigure(6, weight=1)

        # Theme management
        self.themes = build_themes()

        # Load theme from settings — default to dark
        saved_theme = self.settings.get_theme()
        self.current_theme = saved_theme if saved_theme in self.themes else "dark"

        # Enhanced logging
        self.logger = get_logger()

        # HTTP session for connection reuse
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })

        # Translation settings - load from storage
        provider_id = self.settings.get_provider_id()
        provider_label = PROVIDER_LABELS.get(
            normalize_provider_id(provider_id),
            PROVIDER_LABELS[PROVIDER_GOOGLE_UNOFFICIAL],
        )
        self.provider_labels = [
            PROVIDER_LABELS[PROVIDER_GOOGLE_UNOFFICIAL],
        ]
        self.provider_label_to_id = {label: pid for pid, label in PROVIDER_LABELS.items()}
        self.provider_var = tk.StringVar(value=provider_label)

        # Threading/UI state
        self.translation_thread = None
        self.is_translating = False
        self.progress_bar = None

        # Translation service with enhanced error handling
        self.translation_service = TranslationService(session=self.session)

        # Initialize UI text labels
        self.lbl_input_text = "Input (English):"
        self.lbl_ja_text = "Japanese (intermediate):"
        self.lbl_back_text = "Back to English:"
        self.btn_translate_text = "Backtranslate"
        self.lbl_status_text = "Ready"
        self.output_format_var = tk.StringVar(value="HTML") # Default output format

        # Create GUI elements
        self.create_widgets()
        self.bind_shortcuts()

        # Bind window close event to save settings
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

        # UI initialization complete

    def get_dpi_factor(self):
        """Get the DPI scaling factor for the current display."""
        try:
            # The `winfo_fpixels` method converts a distance to a number of pixels.
            # '1i' represents one inch. The result is the number of pixels per inch, i.e., DPI.
            return self.root.winfo_fpixels('1i')
        except Exception:
            return 96.0  # Default DPI for safety

    def scale_font(self, size):
        """Scale font size based on DPI."""
        return int(size * self.scale_factor)

    def create_widgets(self):
        """Create and layout all GUI widgets — unified 3-panel design."""
        theme = self.themes[self.current_theme]
        font_family = "Segoe UI" if platform.system() == "Windows" else "Helvetica"

        # Apply theme to root window
        self.root.configure(bg=theme['bg'])

        # Configure grid: header, input-label, input, action-row, output-label-row, output, status
        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_columnconfigure(1, weight=1)
        self.root.grid_rowconfigure(5, weight=1)  # output row expands

        # Menu
        self.build_menu()

        # === Row 0: Header (title + provider) ===
        header_frame = tk.Frame(self.root, bg=theme['bg'])
        header_frame.grid(row=0, column=0, columnspan=2, sticky="ew", padx=24, pady=(16, 8))
        header_frame.grid_columnconfigure(1, weight=1)

        tk.Label(
            header_frame, text=APP_DISPLAY_NAME,
            bg=theme['bg'], fg=theme['fg'],
            font=(font_family, self.scale_font(16), "bold"),
        ).grid(row=0, column=0, sticky="w")

        self.cmb_provider = ttk.Combobox(
            header_frame,
            textvariable=self.provider_var,
            values=self.provider_labels,
            state="readonly",
            width=36,
        )
        self.cmb_provider.grid(row=0, column=1, sticky="e")
        self.cmb_provider.bind("<<ComboboxSelected>>", lambda _event: self.on_provider_changed())

        # === Row 1: Input label ===
        self.lbl_input = tk.Label(
            self.root, text="INPUT", anchor="w",
            bg=theme['label_bg'], fg=theme['label_fg'],
            font=(font_family, self.scale_font(8), "bold"),
        )
        self.lbl_input.grid(row=1, column=0, columnspan=2, sticky="ew", padx=24, pady=(4, 0))

        # === Row 2: Input text area ===
        self.txt_input = scrolledtext.ScrolledText(
            self.root, height=6, wrap=tk.WORD,
            font=(font_family, self.scale_font(10)),
            bg=theme['text_bg'], fg=theme['text_fg'],
            insertbackground=theme['text_fg'],
            relief="flat", bd=0, highlightthickness=1,
            highlightcolor=theme.get('accent', '#3B82F6'),
            highlightbackground=theme.get('border', '#2E3648'),
        )
        self.txt_input.grid(row=2, column=0, columnspan=2, sticky="ew", padx=24, pady=(2, 8))

        # === Row 3: Action row ===
        action_frame = tk.Frame(self.root, bg=theme['bg'])
        action_frame.grid(row=3, column=0, columnspan=2, sticky="ew", padx=24, pady=(0, 8))

        # Hero button
        self.btn_translate = tk.Button(
            action_frame, text="\u29BF Backtranslate", command=self.start_translation,
            font=(font_family, self.scale_font(10), "bold"),
            bg=theme.get('accent', '#3B82F6'),
            fg=theme.get('accent_fg', '#FFFFFF'),
            activebackground=theme.get('accent_hover', '#2563EB'),
            activeforeground=theme.get('accent_fg', '#FFFFFF'),
            relief="flat", bd=0, padx=16, pady=6,
        )
        self.btn_translate.pack(side=tk.LEFT, padx=(0, 8))

        # Secondary buttons
        for text, cmd in [
            ("Import", self.load_file),
            ("Save", self.save_results),
            ("Copy", self.copy_results),
            ("Batch", self.show_batch_processor),
        ]:
            tk.Button(
                action_frame, text=text, command=cmd,
                font=(font_family, self.scale_font(9)),
                bg=theme['button_bg'], fg=theme['button_fg'],
                activebackground=theme['text_bg'],
                activeforeground=theme['button_fg'],
                relief="flat", bd=0, padx=10, pady=6,
            ).pack(side=tk.LEFT, padx=(0, 4))

        # Status label (right side of action row)
        self.lbl_status = tk.Label(
            action_frame, text=self.lbl_status_text, anchor="e",
            bg=theme['bg'], fg=theme['label_fg'],
            font=(font_family, self.scale_font(9)),
        )
        self.lbl_status.pack(side=tk.RIGHT)

        self.on_provider_changed()

        # Progress bar (hidden by default)
        self.progress_bar = ttk.Progressbar(action_frame, mode='indeterminate')
        self.progress_bar.pack(side=tk.RIGHT, padx=(0, 8))
        self.progress_bar.pack_forget()

        # === Row 4: Output labels (side by side) ===
        self.lbl_ja = tk.Label(
            self.root, text="INTERMEDIATE (JA)", anchor="w",
            bg=theme['label_bg'], fg=theme['label_fg'],
            font=(font_family, self.scale_font(8), "bold"),
        )
        self.lbl_ja.grid(row=4, column=0, sticky="ew", padx=(24, 6), pady=(4, 0))

        self.lbl_back = tk.Label(
            self.root, text="RESULT (EN)", anchor="w",
            bg=theme['label_bg'], fg=theme['label_fg'],
            font=(font_family, self.scale_font(8), "bold"),
        )
        self.lbl_back.grid(row=4, column=1, sticky="ew", padx=(6, 24), pady=(4, 0))

        # === Row 5: Side-by-side output text areas ===
        self.txt_ja = scrolledtext.ScrolledText(
            self.root, height=8, wrap=tk.WORD, state="disabled",
            font=(font_family, self.scale_font(10)),
            bg=theme['text_bg'], fg=theme['text_fg'],
            relief="flat", bd=0, highlightthickness=1,
            highlightbackground=theme.get('border', '#2E3648'),
        )
        self.txt_ja.grid(row=5, column=0, sticky="nsew", padx=(24, 6), pady=(2, 16))

        self.txt_back = scrolledtext.ScrolledText(
            self.root, height=8, wrap=tk.WORD, state="disabled",
            font=(font_family, self.scale_font(10)),
            bg=theme['text_bg'], fg=theme['text_fg'],
            relief="flat", bd=0, highlightthickness=1,
            highlightbackground=theme.get('border', '#2E3648'),
        )
        self.txt_back.grid(row=5, column=1, sticky="nsew", padx=(6, 24), pady=(2, 16))

        # Hidden controls kept for compatibility
        self.lbl_file_info = tk.Label(self.root, text="", bg=theme['bg'], fg=theme['fg'])
        self.lbl_file_info.grid_forget()
        self.btn_theme = tk.Button(self.root, text="", command=self.toggle_theme)
        self.btn_theme.grid_forget()
        self.webview = None  # preview removed
        self.output_format_var = tk.StringVar(value="Plain Text")

        # Configure padding for grid-managed widgets only
        for child in self.root.winfo_children():
            try:
                child.grid_configure(padx=5, pady=2)
            except tk.TclError:
                # Some widgets (e.g., Menu) are not grid-managed
                pass
            except Exception:
                pass

    def toggle_theme(self):
        """Toggle between light and dark themes"""
        self.current_theme = 'dark' if self.current_theme == 'light' else 'light'

        # Save theme setting
        self.settings.set_theme(self.current_theme)

        theme = self.themes[self.current_theme]

        # Update button text
        self.btn_theme.config(
            text=toggle_button_label(self.current_theme),
            bg=theme['button_bg'], fg=theme['button_fg']
        )

        # Rebuild widgets with new theme
        self.rebuild_widgets()

    def rebuild_widgets(self):
        """Rebuild all widgets with current theme"""
        # Clear existing widgets
        for widget in self.root.winfo_children():
            widget.destroy()

        # Recreate all widgets
        self.create_widgets()

    def load_file(self):
        """Load content from .txt, .md, .html, or .epub file"""
        filetypes = [
            ('Text files', '*.txt'),
            ('Markdown files', '*.md'),
            ('HTML files', '*.html'),
            ('EPUB files', '*.epub'),
            ('All supported files', '*.txt;*.md;*.html;*.epub')
        ]

        filename = filedialog.askopenfilename(
            title="Select file to translate",
            filetypes=filetypes
        )

        if filename:
            try:
                if filename.lower().endswith('.epub'):
                    processor = EpubProcessor(filename)
                    title = processor.get_book_title()
                    chapters = processor.get_chapters()
                    if chapters:
                        # For simplicity, load the first chapter's content
                        content = processor.get_chapter_content(chapters[0])
                        self.txt_input.delete("1.0", tk.END)
                        self.txt_input.insert("1.0", content)
                        self.lbl_file_info.config(text=f"Loaded EPUB: {os.path.basename(filename)} (First chapter)")
                        self.logger.info(f"Loaded EPUB file: {filename}, Title: {title}")
                    else:
                        messagebox.showwarning("No content", "EPUB file contains no chapters.")
                        self.logger.warning(f"EPUB file {filename} loaded but contains no chapters.")
                        return
                else:
                    result = load_text_from_path(filename)

                    if result.is_success():
                        content = result.value  # type: ignore
                        if content:
                            self.txt_input.delete("1.0", tk.END)
                            self.txt_input.insert("1.0", content)
                            self.lbl_file_info.config(text=f"Loaded: {os.path.basename(filename)}")
                            self.logger.info(f"Loaded file: {filename}")
                        else:
                            messagebox.showwarning("No content", "No translatable content found in the file.")
                    else:
                        # Handle failure case
                        error = result.error  # type: ignore
                        user_friendly_msg = get_user_friendly_message(error)
                        self.logger.error(
                            "File loading failed",
                            extra={
                                "file_path": filename,
                                "error_type": type(error).__name__,
                                "user_message": user_friendly_msg,
                                "technical_details": str(error),
                            }
                        )
                        messagebox.showerror("File Loading Error", user_friendly_msg)

                # Save to recent files
                self.settings.add_recent_file(filename)

            except Exception as e:
                # Fallback for unexpected errors
                user_friendly_msg = get_user_friendly_message(e)
                self.logger.error(
                    "Unexpected file loading error",
                    extra={
                        "file_path": filename,
                        "error_type": type(e).__name__,
                        "user_message": user_friendly_msg,
                        "technical_details": str(e),
                    }
                )
                messagebox.showerror("File Loading Error", user_friendly_msg)
    def translate_async(self, text, source_lang, target_lang):
        """Translate text using enhanced TranslationService with comprehensive error handling."""
        if not text or text.isspace():
            return ""

        provider_id = self.get_selected_provider_id()

        result = self.translation_service.translate_text(
            session=self.session,
            text=text,
            source_lang=source_lang,
            target_lang=target_lang,
            provider_id=provider_id,
        )

        if result.is_success():
            return result.value
        else:
            # Surface translation errors so the UI can show a user-friendly message.
            raise result.error

    def perform_backtranslation(self):
        """Perform the back-translation process in a separate thread"""
        try:
            # Get input text
            input_text = self.txt_input.get("1.0", tk.END).strip()

            if not input_text:
                self.root.after(0, lambda: messagebox.showwarning(
                    "No input", "Please enter English text to translate."
                ))
                return

            # Update status & show spinner
            self.root.after(0, lambda: self.lbl_status.config(text="Translating to Japanese...", fg="orange"))
            self.root.after(0, lambda: self.show_spinner(True))
            self.root.after(0, lambda: self.txt_ja.config(state="normal"))
            self.root.after(0, lambda: self.txt_ja.delete("1.0", tk.END))
            self.root.after(0, lambda: self.txt_ja.config(state="disabled"))
            self.root.after(0, lambda: self.txt_back.config(state="normal"))
            self.root.after(0, lambda: self.txt_back.delete("1.0", tk.END))
            self.root.after(0, lambda: self.txt_back.config(state="disabled"))

            # Step 1: Translate English to Japanese
            japanese_text = self.translate_async(input_text, "en", "ja")

            # Update Japanese text box
            self.root.after(0, lambda: self.txt_ja.config(state="normal"))
            self.root.after(0, lambda: self.txt_ja.insert("1.0", japanese_text))
            self.root.after(0, lambda: self.txt_ja.config(state="disabled"))

            # Update status
            self.root.after(0, lambda: self.lbl_status.config(text="Translating back to English...", fg="orange"))

            # Step 2: Translate Japanese back to English
            backtranslated_text = self.translate_async(japanese_text, "ja", "en")

            # Update back-translated text box
            self.root.after(0, lambda: self.txt_back.config(state="normal"))
            self.root.after(0, lambda: self.txt_back.insert("1.0", backtranslated_text))
            self.root.after(0, lambda: self.txt_back.config(state="disabled"))

            # Update preview
            self.root.after(0, lambda: self.update_preview(backtranslated_text))
            self.root.after(0, lambda: self.lbl_status.config(text="Done", fg="green"))

            # Log translation summary
            self.logger.info(
                "Back-translation completed",
                extra={
                    "input_length": len(input_text),
                    "japanese_length": len(japanese_text),
                    "backtranslated_length": len(backtranslated_text)
                }
            )

        except Exception as e:
            # Show user-friendly error message
            user_friendly_msg = get_user_friendly_message(e)
            technical_details = str(e)

            # Log the full technical details
            self.logger.error(
                "Backtranslation failed",
                extra={
                    "error_type": type(e).__name__,
                    "user_message": user_friendly_msg,
                    "technical_details": technical_details,
                    "input_length": len(input_text) if 'input_text' in locals() else 0,
                }
            )

            # Show user-friendly message in UI
            self.root.after(0, lambda: messagebox.showerror("Translation Error", user_friendly_msg))
            self.root.after(0, lambda: self.lbl_status.config(text=f"Error: {user_friendly_msg[:50]}...", fg="red"))

        finally:
            # Re-enable controls
            self.root.after(0, lambda: self.btn_translate.config(state="normal"))
            self.root.after(0, lambda: self.txt_input.config(state="normal"))
            self.root.after(0, lambda: self.show_spinner(False))
            self.is_translating = False

    def start_translation(self):
        """Start the translation process in a background thread"""
        if self.is_translating:
            return

        self.is_translating = True

        # Disable controls during translation
        self.btn_translate.config(state="disabled")
        self.txt_input.config(state="disabled")

        # Start translation in background thread
        self.translation_thread = threading.Thread(target=self.perform_backtranslation)
        self.translation_thread.daemon = True
        self.translation_thread.start()

    def get_selected_provider_id(self) -> str:
        """Return the canonical provider id for the selected label."""
        label = self.provider_var.get()
        return self.provider_label_to_id.get(label, PROVIDER_GOOGLE_UNOFFICIAL)

    def on_provider_changed(self) -> None:
        """Persist provider selection and update status."""
        provider_id = self.get_selected_provider_id()
        self.settings.set_provider_id(provider_id)
        if hasattr(self, "lbl_status"):
            self.set_status("Using unofficial provider.", "blue")

    def set_status(self, text: str, color: str = "blue"):
        self.lbl_status.config(text=text, fg=color)

    def show_spinner(self, show: bool):
        if not self.progress_bar:
            return
        if show:
            self.progress_bar.pack(side=tk.RIGHT, padx=(0, 8))
            try:
                self.progress_bar.start(12)
            except Exception:
                pass
        else:
            try:
                self.progress_bar.stop()
            except Exception:
                pass
            self.progress_bar.pack_forget()

    def save_results(self, *_):
        """Save the Japanese and back-translated text to a UTF-8 file."""
        content_input = self.txt_input.get("1.0", tk.END).strip()
        content_ja = self._get_textbox_value(self.txt_ja)
        content_back = self._get_textbox_value(self.txt_back)
        if not any([content_input, content_ja, content_back]):
            messagebox.showwarning("Nothing to save", "No content to save.")
            return
        initial = "backtranslation.txt"
        filename = filedialog.asksaveasfilename(
            title="Save results",
            defaultextension=".txt",
            initialfile=initial,
            initialdir=str(get_exports_dir()),
            filetypes=[('Text files', '*.txt')]
        )
        if not filename:
            return
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                f.write("Input (English):\n")
                f.write(content_input + "\n\n")
                f.write("Japanese (intermediate):\n")
                f.write(content_ja + "\n\n")
                f.write("Back to English:\n")
                f.write(content_back + "\n")
            self.logger.info(f"Saved results to {filename}")
            messagebox.showinfo("Saved", f"Results saved to {os.path.basename(filename)}")
        except Exception as e:
            user_friendly_msg = get_user_friendly_message(e)
            self.logger.error(
                "File saving failed",
                extra={
                    "file_path": filename,
                    "error_type": type(e).__name__,
                    "user_message": user_friendly_msg,
                    "technical_details": str(e),
                }
            )
            messagebox.showerror("Save Error", user_friendly_msg)

    def copy_results(self, *_):
        """Copy the back-translated text to the clipboard."""
        content_back = self._get_textbox_value(self.txt_back)
        if not content_back:
            messagebox.showwarning("No content", "No back-translated text to copy.")
            return
        try:
            self.root.clipboard_clear()
            self.root.clipboard_append(content_back)
            self.logger.info("Copied results to clipboard")
            self.set_status("Copied back-translated text.", "green")
        except Exception as e:
            user_friendly_msg = get_user_friendly_message(e)
            self.logger.error(
                "Clipboard copy failed",
                extra={
                    "error_type": type(e).__name__,
                    "user_message": user_friendly_msg,
                    "technical_details": str(e),
                }
            )
            messagebox.showerror("Clipboard Error", user_friendly_msg)

    def _get_textbox_value(self, textbox: scrolledtext.ScrolledText) -> str:
        state = textbox.cget("state")
        try:
            textbox.config(state="normal")
            return textbox.get("1.0", tk.END).strip()
        finally:
            textbox.config(state=state)

    def build_menu(self):
        menubar = tk.Menu(self.root)
        file_menu = tk.Menu(menubar, tearoff=0)
        file_menu.add_command(label="Import File (Ctrl+O)", command=self.load_file)
        file_menu.add_command(label="Save Results (Ctrl+S)", command=self.save_results)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        menubar.add_cascade(label="File", menu=file_menu)

        edit_menu = tk.Menu(menubar, tearoff=0)
        edit_menu.add_command(label="Copy Results (Ctrl+Shift+C)", command=self.copy_results)
        menubar.add_cascade(label="Edit", menu=edit_menu)

        view_menu = tk.Menu(menubar, tearoff=0)
        view_menu.add_command(label="Toggle Theme (Ctrl+T)", command=self.toggle_theme)
        menubar.add_cascade(label="View", menu=view_menu)

        settings_menu = tk.Menu(menubar, tearoff=0)
        settings_menu.add_command(label="Toggle Provider (Ctrl+P)", command=self.toggle_api_shortcut)
        menubar.add_cascade(label="Settings", menu=settings_menu)

        self.root.config(menu=menubar)

    def bind_shortcuts(self):
        """Bind keyboard shortcuts to application functions."""
        self.root.bind('<Control-o>', lambda event: self.load_file())
        self.root.bind('<Control-O>', lambda event: self.load_file())
        self.root.bind('<Control-s>', lambda event: self.save_results())
        self.root.bind('<Control-S>', lambda event: self.save_results())
        self.root.bind('<Control-t>', lambda event: self.toggle_theme())
        self.root.bind('<Control-T>', lambda event: self.toggle_theme())
        self.root.bind('<Control-p>', lambda event: self.toggle_api_shortcut())
        self.root.bind('<Control-P>', lambda event: self.toggle_api_shortcut())
        self.root.bind('<Control-Shift-C>', lambda event: self.copy_results())

    def on_closing(self):
        """Handle window closing - save settings."""
        try:
            # Save window geometry
            geometry = f"{self.root.winfo_width()}x{self.root.winfo_height()}"
            self.settings.set_window_geometry(geometry)

            # Save current theme
            self.settings.set_theme(self.current_theme)

            self.logger.info("Settings saved on application close")
        except Exception as e:
            self.logger.error(f"Failed to save settings on close: {e}")

        # Close the window
        self.root.destroy()

    def on_format_selected(self, event):
        """Handle format selection change — preview removed."""
        pass

    def update_preview(self, content):
        """Preview pane removed — no-op."""
        pass

    def toggle_api_shortcut(self):
        """Cycle through providers and provide user feedback."""
        current_label = self.provider_var.get()
        try:
            idx = self.provider_labels.index(current_label)
        except ValueError:
            idx = 0
        next_label = self.provider_labels[(idx + 1) % len(self.provider_labels)]
        self.provider_var.set(next_label)
        self.on_provider_changed()
        self.show_status_message(f"Switched to {next_label}", "green")

    def show_status_message(self, message, color="green", duration=3000):
        """Display a message in the status bar for a short duration."""
        self.lbl_status.config(text=message, fg=color)
        self.root.after(duration, lambda: self.lbl_status.config(text="Ready", fg="blue"))

    def show_batch_processor(self):
        """Show the batch processing window."""
        batch_window = tk.Toplevel(self.root)
        batch_window.title("Batch Processing")
        batch_window.geometry("400x200")

        tk.Label(batch_window, text="Select a directory to process:").pack(pady=10)

        def select_directory():
            directory = filedialog.askdirectory()
            if directory:
                self.start_batch_processing(directory)
                batch_window.destroy()

        tk.Button(batch_window, text="Select Directory", command=select_directory).pack(pady=10)

    def start_batch_processing(self, directory):
        """Start the batch processing in a separate thread."""
        self.batch_processor = BatchProcessor(self.translation_service, self.update_batch_progress)
        thread = threading.Thread(
            target=self.batch_processor.process_directory,
            args=(directory, self.get_selected_provider_id())
        )
        thread.daemon = True
        thread.start()
        self.show_batch_progress_window()

    def show_batch_progress_window(self):
        """Show a window with the batch processing progress."""
        self.progress_window = tk.Toplevel(self.root)
        self.progress_window.title("Batch Progress")
        self.progress_window.geometry("300x100")

        self.progress_label = tk.Label(self.progress_window, text="Starting...")
        self.progress_label.pack(pady=10)

        self.progress_bar = ttk.Progressbar(self.progress_window, orient="horizontal", length=280, mode="determinate")
        self.progress_bar.pack(pady=10)

        tk.Button(self.progress_window, text="Stop", command=self.stop_batch_processing).pack(pady=5)

    def update_batch_progress(self, current, total):
        """Update the progress bar and label in the batch progress window."""
        if hasattr(self, 'progress_window') and self.progress_window.winfo_exists():
            self.progress_bar['value'] = (current / total) * 100
            self.progress_label['text'] = f"Processing file {current} of {total}"
            self.progress_window.update_idletasks()
            if current == total:
                messagebox.showinfo("Batch Complete", "Batch processing is complete.")
                self.progress_window.destroy()

    def stop_batch_processing(self):
        """Stop the batch processing."""
        if hasattr(self, 'batch_processor'):
            self.batch_processor.stop()
        if hasattr(self, 'progress_window') and self.progress_window.winfo_exists():
            self.progress_window.destroy()


    def on_panic(self):
        """Panic button removed — no-op."""
        pass


def main():
    """Main application entry point"""
    if platform.system() == "Windows":
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except Exception as e:
            print(f"Warning: Could not set DPI awareness: {e}")
    try:
        # Create the main window
        root = tk.Tk()

        # Create the application
        TranslationFiesta(root)

        # Start the GUI event loop
        root.mainloop()

    except KeyboardInterrupt:
        print("\nApplication interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Application error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
