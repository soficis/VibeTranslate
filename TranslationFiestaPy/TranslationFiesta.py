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

from app_logger import create_logger
from file_utils import load_text_from_path
from translation_services import translate_text


class TranslationFiesta:
    def __init__(self, root):
        self.root = root
        self.root.title("TranslationFiesta - English ↔ Japanese Backtranslation")
        self.root.geometry("820x640")
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
        self.current_theme = 'light'

        # Logging
        self.logger = create_logger()

        # HTTP session for connection reuse
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })

        # Translation settings
        self.use_official_var = tk.BooleanVar(value=False)
        self.api_key_var = tk.StringVar(value="")

        # Threading/UI state
        self.translation_thread = None
        self.is_translating = False
        self.progress_bar = None

        # Create GUI elements
        self.create_widgets()
        self.bind_shortcuts()

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
            toolbar_frame, text="🌙 Dark", command=self.toggle_theme,
            bg=theme['button_bg'], fg=theme['button_fg'], font=("Arial", 9)
        )
        self.btn_theme.grid(row=0, column=0, padx=(0, 10))

        # File load button
        self.btn_load_file = tk.Button(
            toolbar_frame, text="📁 Load File", command=self.load_file,
            bg=theme['button_bg'], fg=theme['button_fg'], font=("Arial", 9)
        )
        self.btn_load_file.grid(row=0, column=1, padx=(0, 10))

        # File info label
        self.lbl_file_info = tk.Label(
            toolbar_frame, text="", anchor="w", bg=theme['bg'], fg=theme['fg'], font=("Arial", 9)
        )
        self.lbl_file_info.grid(row=0, column=2, sticky="ew")

        # Official API toggle and key
        self.chk_official = tk.Checkbutton(
            toolbar_frame, text="Use Official API", variable=self.use_official_var,
            command=self.on_toggle_official, bg=theme['bg'], fg=theme['fg'], font=("Arial", 9)
        )
        self.chk_official.grid(row=1, column=0, sticky="w", pady=(6, 0))

        tk.Label(toolbar_frame, text="API Key:", bg=theme['bg'], fg=theme['fg'], font=("Arial", 9)).grid(row=1, column=1, sticky="e", pady=(6, 0))
        self.entry_api_key = tk.Entry(
            toolbar_frame, textvariable=self.api_key_var, show='*', width=40,
            bg=theme['text_bg'], fg=theme['text_fg'], insertbackground=theme['text_fg']
        )
        self.entry_api_key.grid(row=1, column=2, sticky="ew", pady=(6, 0))
        self.entry_api_key.config(state="disabled")

        # Input section
        lbl_input = tk.Label(self.root, text="Input (English):", anchor="w",
                           bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", 10))
        lbl_input.grid(row=1, column=0, sticky="ew", padx=10, pady=(5, 2))

        self.txt_input = scrolledtext.ScrolledText(
            self.root, height=10, wrap=tk.WORD, font=("Arial", 10),
            bg=theme['text_bg'], fg=theme['text_fg'], insertbackground=theme['text_fg']
        )
        self.txt_input.grid(row=2, column=0, sticky="ew", padx=10, pady=(0, 10))

        # Button and status
        button_frame = tk.Frame(self.root, bg=theme['bg'])
        button_frame.grid(row=3, column=0, sticky="ew", padx=10)
        button_frame.grid_columnconfigure(1, weight=1)

        self.btn_translate = tk.Button(
            button_frame, text="Backtranslate", command=self.start_translation,
            height=2, font=("Arial", 10, "bold"),
            bg=theme['button_bg'], fg=theme['button_fg']
        )
        self.btn_translate.grid(row=0, column=0, padx=(0, 10))

        self.lbl_status = tk.Label(
            button_frame, text="Ready", anchor="w", fg="blue",
            bg=theme['bg'], font=("Arial", 9)
        )
        self.lbl_status.grid(row=0, column=1, sticky="ew")

        # Progress bar (visible only during translation)
        self.progress_bar = ttk.Progressbar(button_frame, mode='indeterminate')
        self.progress_bar.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(6, 0))
        self.progress_bar.grid_remove()

        # Japanese intermediate section
        lbl_ja = tk.Label(self.root, text="Japanese (intermediate):", anchor="w",
                         bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", 10))
        lbl_ja.grid(row=4, column=0, sticky="ew", padx=10, pady=(10, 2))

        self.txt_ja = scrolledtext.ScrolledText(
            self.root, height=10, wrap=tk.WORD, state="disabled", font=("Arial", 10),
            bg=theme['text_bg'], fg=theme['text_fg']
        )
        self.txt_ja.grid(row=5, column=0, sticky="ew", padx=10, pady=(0, 10))

        # Back to English section
        lbl_back = tk.Label(self.root, text="Back to English:", anchor="w",
                           bg=theme['label_bg'], fg=theme['label_fg'], font=("Arial", 10))
        lbl_back.grid(row=6, column=0, sticky="ew", padx=10, pady=(10, 2))

        self.txt_back = scrolledtext.ScrolledText(
            self.root, height=8, wrap=tk.WORD, state="disabled", font=("Arial", 10),
            bg=theme['text_bg'], fg=theme['text_fg']
        )
        self.txt_back.grid(row=7, column=0, sticky="ew", padx=10, pady=(0, 10))

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
        """Load content from .txt, .md, or .html file"""
        filetypes = [
            ('Text files', '*.txt'),
            ('Markdown files', '*.md'),
            ('HTML files', '*.html'),
            ('All supported files', '*.txt;*.md;*.html')
        ]

        filename = filedialog.askopenfilename(
            title="Select file to translate",
            filetypes=filetypes
        )

        if filename:
            try:
                content = load_text_from_path(filename)
                if content:
                    self.txt_input.delete("1.0", tk.END)
                    self.txt_input.insert("1.0", content)
                    self.lbl_file_info.config(text=f"Loaded: {os.path.basename(filename)}")
                    self.logger.info(f"Loaded file: {filename}")
                else:
                    messagebox.showwarning("No content", "No translatable content found in the file.")
            except Exception as e:
                self.logger.error(f"Failed to load file: {e}")
                messagebox.showerror("Error", f"Failed to load file: {str(e)}")
    def process_file(self, filename):
        """Deprecated: use file_utils.load_text_from_path instead"""
        return load_text_from_path(filename)

    def translate_async(self, text, source_lang, target_lang):
        """Translate text via unofficial or official API with retries."""
        if not text or text.isspace():
            return ""
        return translate_text(
            self.session,
            text,
            source_lang,
            target_lang,
            use_official_api=self.use_official_var.get(),
            api_key=(self.api_key_var.get() or None),
            logger=self.logger,
        )

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

            # Update status
            self.root.after(0, lambda: self.lbl_status.config(text="Done", fg="green"))

        except Exception as e:
            # Show error message
            error_msg = str(e)
            self.root.after(0, lambda: messagebox.showerror("Error", error_msg))
            self.root.after(0, lambda: self.lbl_status.config(text=f"Error: {error_msg[:50]}...", fg="red"))

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
            self.logger.error(f"Failed to save results: {e}")
            messagebox.showerror("Error", f"Failed to save results: {e}")

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
            self.logger.error(f"Clipboard copy failed: {e}")
            messagebox.showerror("Error", f"Failed to copy: {e}")

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
        file_menu.add_command(label="Import .txt", command=self.load_file)
        file_menu.add_command(label="Save Results	Ctrl+S", command=self.save_results)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        menubar.add_cascade(label="File", menu=file_menu)

        edit_menu = tk.Menu(menubar, tearoff=0)
        edit_menu.add_command(label="Copy Results	Ctrl+C", command=self.copy_results)
        menubar.add_cascade(label="Edit", menu=edit_menu)

        self.root.config(menu=menubar)

    def bind_shortcuts(self):
        self.root.bind('<Control-s>', self.save_results)
        self.root.bind('<Control-S>', self.save_results)
        self.root.bind('<Control-c>', self.copy_results)
        self.root.bind('<Control-C>', self.copy_results)


def main():
    """Main application entry point"""
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
