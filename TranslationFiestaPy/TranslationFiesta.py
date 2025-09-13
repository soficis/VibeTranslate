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

import tkinter as tk
from tkinter import messagebox, scrolledtext, filedialog
from tkinter import ttk
import requests
import threading
import sys
import os
import platform
if platform.system() == "Windows":
    import ctypes
try:
    from tkinterweb import HtmlFrame
except ImportError:
    # Fallback if tkinterweb is not available or doesn't have HtmlFrame
    HtmlFrame = None

from exceptions import get_user_friendly_message, TranslationFiestaError
from result import Result, Success, Failure
from enhanced_logger import get_logger
from file_utils import load_text_from_path
from epub_processor import EpubProcessor
from translation_services import TranslationService, translate_text
from secure_storage import get_secure_storage, store_api_key, get_api_key, delete_api_key
from settings_storage import get_settings_storage, get_theme, set_theme
from batch_processor import BatchProcessor
from bleu_scorer import get_bleu_scorer


class TranslationFiesta:
    def __init__(self, root):
        self.root = root
        self.root.title("TranslationFiesta - English ↔ Japanese Backtranslation")

        # DPI Awareness and Scaling
        self.dpi_factor = self.get_dpi_factor()
        self.scale_factor = self.dpi_factor / 96.0 if self.dpi_factor else 1.0

        # Initialize storage modules
        self.settings = get_settings_storage()
        self.secure_storage = get_secure_storage()

        # Load window geometry from settings
        geometry = self.settings.get_window_geometry()
        self.root.geometry(geometry)
        self.root.resizable(True, True)

        # Configure grid weights for responsive layout
        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_rowconfigure(6, weight=1)

        # Theme management
        self.themes = {
            'light': {
                'bg': '#f0f0f0',
                'fg': '#000000',
                'text_bg': '#ffffff',
                'text_fg': '#000000',
                'button_bg': '#e0e0e0',
                'button_fg': '#000000',
                'label_bg': '#f0f0f0',
                'label_fg': '#000000'
            },
            'dark': {
                'bg': '#2b2b2b',
                'fg': '#ffffff',
                'text_bg': '#3c3c3c',
                'text_fg': '#ffffff',
                'button_bg': '#4a4a4a',
                'button_fg': '#ffffff',
                'label_bg': '#2b2b2b',
                'label_fg': '#ffffff'
            }
        }

        # Load theme from settings
        self.current_theme = self.settings.get_theme()

        # Enhanced logging
        self.logger = get_logger()

        # HTTP session for connection reuse
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })

        # Translation settings - load from storage
        use_official = self.settings.get_use_official_api()
        self.use_official_var = tk.BooleanVar(value=use_official)

        # Load API key from secure storage
        api_key = get_api_key("google_translate") or ""
        self.api_key_var = tk.StringVar(value=api_key)

        # Threading/UI state
        self.translation_thread = None
        self.is_translating = False
        self.progress_bar = None

        # Translation service with enhanced error handling
        self.translation_service = TranslationService()

        # BLEU scorer for quality assessment
        self.bleu_scorer = get_bleu_scorer()

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
        """Create and layout all GUI widgets"""
        theme = self.themes[self.current_theme]

        # Apply theme to root window
        self.root.configure(bg=theme['bg'])

        # Menu
        self.build_menu()

        # Toolbar section
        toolbar_frame = tk.Frame(self.root, bg=theme['bg'])
        toolbar_frame.grid(row=0, column=0, sticky="ew", padx=10, pady=(10, 5))
        toolbar_frame.grid_columnconfigure(2, weight=1)

        # Theme toggle button
        self.btn_theme = tk.Button(
            toolbar_frame, text="☀️ Light" if self.current_theme == 'dark' else "🌙 Dark", command=self.toggle_theme,
            bg=theme['button_bg'], fg=theme['button_fg'], font=("Arial", self.scale_font(9))
        )
        self.btn_theme.grid(row=0, column=0, padx=(0, 10))

        # File load button
        self.btn_load_file = tk.Button(
            toolbar_frame, text="📁 Load File", command=self.load_file,
            bg=theme['button_bg'], fg=theme['button_fg'], font=("Arial", self.scale_font(9))
        )
        self.btn_load_file.grid(row=0, column=1, padx=(0, 10))

        # Batch process button
        self.btn_batch_process = tk.Button(
            toolbar_frame, text="📦 Batch Process", command=self.show_batch_processor,
            bg=theme['button_bg'], fg=theme['button_fg'], font=("Arial", self.scale_font(9))
        )
        self.btn_batch_process.grid(row=0, column=2, padx=(0, 10))

        # Mysterious "Panic" Button
        self.btn_panic = tk.Button(
            toolbar_frame, text="Panic", command=self.on_panic,
            bg="#ff4d4d", fg="#ffffff", font=("Arial", self.scale_font(9), "bold")
        )
        self.btn_panic.grid(row=0, column=3, padx=(0, 10))

        # File info label
        self.lbl_file_info = tk.Label(
            toolbar_frame, text="", anchor="w", bg=theme['bg'], fg=theme['fg'], font=("Arial", self.scale_font(9))
        )
        self.lbl_file_info.grid(row=0, column=4, sticky="ew")

        # Official API toggle and key
        self.chk_official = tk.Checkbutton(
            toolbar_frame, text="Use Official API", variable=self.use_official_var,
            command=self.on_toggle_official, bg=theme['bg'], fg=theme['fg'],
            selectcolor=theme['button_bg'], font=("Arial", self.scale_font(9))
        )
        self.chk_official.grid(row=1, column=0, sticky="w", pady=(6, 0))

        tk.Label(toolbar_frame, text="API Key:", bg=theme['bg'], fg=theme['fg'], font=("Arial", self.scale_font(9))).grid(row=1, column=1, sticky="e", pady=(6, 0))
        self.entry_api_key = tk.Entry(
            toolbar_frame, textvariable=self.api_key_var, show='*', width=40,
            bg=theme['text_bg'], fg=theme['text_fg'], insertbackground=theme['text_fg']
        )
        self.entry_api_key.grid(row=1, column=2, sticky="ew", pady=(6, 0))
        self.entry_api_key.config(state="disabled")

        # Input section
        self.lbl_input = tk.Label(self.root, text=self.lbl_input_text, anchor="w",
                           bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", self.scale_font(10)))
        self.lbl_input.grid(row=1, column=0, sticky="ew", padx=10, pady=(5, 2))

        self.txt_input = scrolledtext.ScrolledText(
            self.root, height=10, wrap=tk.WORD, font=("Arial", self.scale_font(10)),
            bg=theme['text_bg'], fg=theme['text_fg'], insertbackground=theme['text_fg']
        )
        self.txt_input.grid(row=2, column=0, sticky="ew", padx=10, pady=(0, 10))

        # Button and status
        button_frame = tk.Frame(self.root, bg=theme['bg'])
        button_frame.grid(row=3, column=0, sticky="ew", padx=10)
        button_frame.grid_columnconfigure(1, weight=1)

        self.btn_translate = tk.Button(
            button_frame, text=self.btn_translate_text, command=self.start_translation,
            height=2, font=("Arial", self.scale_font(10), "bold"),
            bg=theme['button_bg'], fg=theme['button_fg']
        )
        self.btn_translate.grid(row=0, column=0, padx=(0, 10))

        self.lbl_status = tk.Label(
            button_frame, text=self.lbl_status_text, anchor="w", fg="blue",
            bg=theme['bg'], font=("Arial", self.scale_font(9))
        )
        self.lbl_status.grid(row=0, column=1, sticky="ew")

        # Progress bar (visible only during translation)
        self.progress_bar = ttk.Progressbar(button_frame, mode='indeterminate')
        self.progress_bar.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(6, 0))
        self.progress_bar.grid_remove()

        # Japanese intermediate section
        self.lbl_ja = tk.Label(self.root, text=self.lbl_ja_text, anchor="w",
                         bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", self.scale_font(10)))
        self.lbl_ja.grid(row=4, column=0, sticky="ew", padx=10, pady=(10, 2))

        self.txt_ja = scrolledtext.ScrolledText(
            self.root, height=10, wrap=tk.WORD, state="disabled", font=("Arial", self.scale_font(10)),
            bg=theme['text_bg'], fg=theme['text_fg']
        )
        self.txt_ja.grid(row=5, column=0, sticky="ew", padx=10, pady=(0, 10))

        # Back to English section
        self.lbl_back = tk.Label(self.root, text=self.lbl_back_text, anchor="w",
                           bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", self.scale_font(10)))
        self.lbl_back.grid(row=6, column=0, sticky="ew", padx=10, pady=(10, 2))

        self.txt_back = scrolledtext.ScrolledText(
            self.root, height=8, wrap=tk.WORD, state="disabled", font=("Arial", self.scale_font(10)),
            bg=theme['text_bg'], fg=theme['text_fg']
        )
        self.txt_back.grid(row=7, column=0, sticky="ew", padx=10, pady=(0, 10))
 
        # Output format selection
        format_frame = tk.Frame(self.root, bg=theme['bg'])
        format_frame.grid(row=8, column=0, sticky="ew", padx=10, pady=(10, 0))
 
        tk.Label(format_frame, text="Output Format:", bg=theme['bg'], fg=theme['fg'], font=("Arial", self.scale_font(9))).pack(side=tk.LEFT, padx=(0, 5))
        self.format_combo = ttk.Combobox(
            format_frame, textvariable=self.output_format_var,
            values=["HTML", "Markdown", "Plain Text"], state="readonly",
            font=("Arial", self.scale_font(9))
        )
        self.format_combo.pack(side=tk.LEFT, padx=(0, 10))
        self.format_combo.bind("<<ComboboxSelected>>", self.on_format_selected)
 
        # Preview pane
        self.lbl_preview = tk.Label(self.root, text="Preview:", anchor="w",
                                    bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", self.scale_font(10)))
        self.lbl_preview.grid(row=9, column=0, sticky="ew", padx=10, pady=(10, 2))
 
        # Webview for HTML preview (fallback to Text widget if not available)
        if HtmlFrame is not None:
            try:
                self.webview = HtmlFrame(self.root, width=600, height=200)
                self.webview.grid(row=10, column=0, sticky="nsew", padx=10, pady=(0, 10))
                self.root.grid_rowconfigure(10, weight=1) # Make webview expandable
            except Exception as e:
                print(f"Warning: Could not create HTML preview: {e}")
                self.create_fallback_preview()
        else:
            self.create_fallback_preview()

    def create_fallback_preview(self):
        """Create a fallback text preview when HTML preview is not available"""
        theme = self.themes[self.current_theme]
        self.webview = tk.Text(self.root, height=10, wrap=tk.WORD, state="disabled",
                              font=("Arial", self.scale_font(10)),
                              bg=theme['text_bg'], fg=theme['text_fg'])
        self.webview.grid(row=10, column=0, sticky="nsew", padx=10, pady=(0, 10))
        self.root.grid_rowconfigure(10, weight=1)

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
            text="☀️ Light" if self.current_theme == 'dark' else "🌙 Dark",
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
    def process_file(self, filename):
        """Deprecated: use file_utils.load_text_from_path instead"""
        return load_text_from_path(filename)

    def translate_async(self, text, source_lang, target_lang):
        """Translate text using enhanced TranslationService with comprehensive error handling."""
        if not text or text.isspace():
            return ""

        result = self.translation_service.translate_text(
            session=self.session,
            text=text,
            source_lang=source_lang,
            target_lang=target_lang,
            use_official_api=self.use_official_var.get(),
            api_key=(self.api_key_var.get() or None),
        )

        if result.is_success():
            return result.value
        else:
            # For backward compatibility, raise the exception
            # The UI will handle this and show user-friendly messages
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

            # Calculate BLEU score for quality assessment
            quality_assessment = self.bleu_scorer.assess_translation_quality(
                input_text, backtranslated_text
            )

            # Update status with BLEU score and confidence
            status_text = f"Done - BLEU: {quality_assessment['bleu_percentage']} ({quality_assessment['confidence_level']})"
            status_color = "green" if quality_assessment['bleu_score'] >= 0.6 else "orange" if quality_assessment['bleu_score'] >= 0.4 else "red"
            self.root.after(0, lambda: self.lbl_status.config(text=status_text, fg=status_color))

            # Log quality assessment
            self.logger.info(
                "Back-translation completed",
                extra={
                    "bleu_score": quality_assessment['bleu_score'],
                    "confidence_level": quality_assessment['confidence_level'],
                    "quality_rating": quality_assessment['quality_rating'],
                    "recommendations": quality_assessment['recommendations'],
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

    def on_toggle_official(self):
        """Enable/disable API key entry based on official API toggle."""
        if self.use_official_var.get():
            self.entry_api_key.config(state="normal")
            self.set_status("Official API enabled. Provide API key.", "orange")
        else:
            self.entry_api_key.config(state="disabled")
            self.set_status("Using unofficial API.", "blue")

        # Save the setting
        self.settings.set_use_official_api(self.use_official_var.get())

    def set_status(self, text: str, color: str = "blue"):
        self.lbl_status.config(text=text, fg=color)

    def show_spinner(self, show: bool):
        if not self.progress_bar:
            return
        if show:
            self.progress_bar.grid()
            try:
                self.progress_bar.start(12)
            except Exception:
                pass
        else:
            try:
                self.progress_bar.stop()
            except Exception:
                pass
            self.progress_bar.grid_remove()

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
        settings_menu.add_command(label="Toggle API (Ctrl+P)", command=self.toggle_api_shortcut)
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

        # Bind API key entry changes to save automatically
        self.api_key_var.trace_add("write", self.on_api_key_changed)

    def on_api_key_changed(self, *args):
        """Handle API key changes and save to secure storage."""
        api_key = self.api_key_var.get().strip()
        if api_key:
            if store_api_key("google_translate", api_key):
                self.logger.info("API key saved to secure storage")
            else:
                self.logger.error("Failed to save API key to secure storage")
        else:
            # If API key is empty, remove it from storage
            delete_api_key("google_translate")
            self.logger.info("API key removed from secure storage")

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
        """Handle format selection change."""
        selected_format = self.output_format_var.get()
        self.logger.info(f"Output format selected: {selected_format}")
        # Update preview immediately if there's content
        if self.txt_back.get("1.0", tk.END).strip():
            self.update_preview(self.txt_back.get("1.0", tk.END).strip())
 
    def update_preview(self, content):
        """Update the WebView with formatted content."""
        selected_format = self.output_format_var.get()

        # Handle HtmlFrame (tkinterweb) case
        if hasattr(self.webview, 'load_html'):
            if selected_format == "HTML":
                self.webview.load_html(content)
            elif selected_format == "Markdown":
                # Basic Markdown to HTML conversion for preview
                html_content = f"<html><body><pre>{content}</pre></body></html>" # Placeholder
                self.webview.load_html(html_content)
            else: # Plain Text
                html_content = f"<html><body><pre>{content}</pre></body></html>"
                self.webview.load_html(html_content)
        else:
            # Handle Text widget fallback case
            self.webview.config(state="normal")
            self.webview.delete(1.0, tk.END)
            self.webview.insert(tk.END, content)
            self.webview.config(state="disabled")

    def toggle_api_shortcut(self):
        """Toggle the API and provide user feedback."""
        self.use_official_var.set(not self.use_official_var.get())
        self.on_toggle_official()
        status = "Official API" if self.use_official_var.get() else "Unofficial API"
        self.show_status_message(f"Switched to {status}", "green")

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
            args=(directory, self.use_official_var.get(), self.api_key_var.get())
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
        """Handle the 'Panic' button click."""
        messagebox.showinfo("Emergency Stop", "Translation process has been stopped.")


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
        app = TranslationFiesta(root)

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
