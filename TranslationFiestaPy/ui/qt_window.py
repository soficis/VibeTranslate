"""PySide6 implementation of the TranslationFiesta main window."""

import threading

import requests
from PySide6.QtCore import QObject, Qt, Signal, Slot
from PySide6.QtWidgets import (
    QComboBox,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from epub_processor import EpubProcessor
from file_utils import load_text_from_path
from provider_ids import (
    PROVIDER_GOOGLE_UNOFFICIAL,
    PROVIDER_LABELS,
)
from settings_storage import get_settings_storage
from translation_services import TranslationService

from .qt_theme import get_qss


class TranslationSignals(QObject):
    """Signals for background translation updates."""
    status_changed = Signal(str, str)  # message, color
    intermediate_ready = Signal(str)
    result_ready = Signal(str)
    finished = Signal()
    error = Signal(str)

class AppleResultCard(QFrame):
    """A styled container for translation results."""
    def __init__(self, title, parent=None):
        super().__init__(parent)
        self.setFrameShape(QFrame.NoFrame)
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(12, 12, 12, 12)
        self.layout.setSpacing(8)

        self.title_label = QLabel(title.upper())
        self.title_label.setProperty("class", "SmallLabel")
        self.layout.addWidget(self.title_label)

        self.text_area = QTextEdit()
        self.text_area.setReadOnly(True)
        self.layout.addWidget(self.text_area)

class QtTranslationFiesta(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("TranslationFiesta")
        self.setMinimumSize(900, 700)

        # Load Settings & Init Services
        self.settings = get_settings_storage()
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15'
        })
        self.translation_service = TranslationService(session=self.session)

        # UI State
        self.is_translating = False
        self.signals = TranslationSignals()
        self.signals.status_changed.connect(self.update_status)
        self.signals.intermediate_ready.connect(self.on_intermediate_ready)
        self.signals.result_ready.connect(self.on_result_ready)
        self.signals.finished.connect(self.on_translation_finished)
        self.signals.error.connect(self.on_translation_error)

        # Theme
        self.current_theme = self.settings.get_theme() or "dark"
        self.setStyleSheet(get_qss(self.current_theme))

        self.init_ui()
        self.restore_geometry()

    def init_ui(self):
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.main_layout = QVBoxLayout(self.central_widget)
        self.main_layout.setContentsMargins(24, 24, 24, 24)
        self.main_layout.setSpacing(16)

        # --- Header Toolbar ---
        header_layout = QHBoxLayout()
        header_layout.setSpacing(12)

        self.provider_combo = QComboBox()
        self.provider_combo.addItems([PROVIDER_LABELS[PROVIDER_GOOGLE_UNOFFICIAL]])
        header_layout.addWidget(self.provider_combo)

        header_layout.addStretch()

        self.btn_import = QPushButton("Import File")
        self.btn_import.clicked.connect(self.open_file_dialog)
        header_layout.addWidget(self.btn_import)

        self.btn_batch = QPushButton("Batch Processor")
        self.btn_batch.clicked.connect(self.open_batch_dialog)
        header_layout.addWidget(self.btn_batch)

        self.main_layout.addLayout(header_layout)

        # --- Source Section ---
        source_header = QLabel("SOURCE TEXT")
        source_header.setProperty("class", "SmallLabel")
        self.main_layout.addWidget(source_header)

        self.txt_input = QTextEdit()
        self.txt_input.setPlaceholderText("Paste English text here...")
        self.main_layout.addWidget(self.txt_input, 3)

        # --- Action Area ---
        action_layout = QVBoxLayout()
        action_layout.setAlignment(Qt.AlignCenter)

        self.btn_translate = QPushButton("Backtranslate Text")
        self.btn_translate.setProperty("class", "PrimaryButton")
        self.btn_translate.setFixedWidth(240)
        self.btn_translate.clicked.connect(self.start_translation)
        action_layout.addWidget(self.btn_translate)

        self.progress_bar = QProgressBar()
        self.progress_bar.setFixedWidth(240)
        self.progress_bar.setVisible(False)
        action_layout.addWidget(self.progress_bar)

        self.main_layout.addLayout(action_layout)

        # --- Results Section ---
        results_layout = QHBoxLayout()
        results_layout.setSpacing(12)

        self.card_ja = AppleResultCard("Intermediate (JA)")
        results_layout.addWidget(self.card_ja)

        self.card_en = AppleResultCard("Final Result (EN)")
        results_layout.addWidget(self.card_en)

        self.main_layout.addLayout(results_layout, 4)

        # --- Footer Status ---
        self.status_bar = QWidget()
        self.status_bar.setFixedHeight(32)
        self.status_bar_layout = QHBoxLayout(self.status_bar)
        self.status_bar_layout.setContentsMargins(16, 0, 16, 0)

        self.lbl_status = QLabel("Ready")
        self.lbl_status.setProperty("class", "SmallLabel")
        self.status_bar_layout.addWidget(self.lbl_status)

        # Add tiny Tools above the result card on far right if needed,
        # but keep footer clean.
        self.status_bar_layout.addStretch()

        self.btn_copy = QPushButton("Copy Result")
        self.btn_copy.setFixedWidth(100)
        self.btn_copy.clicked.connect(self.copy_to_clipboard)
        self.status_bar_layout.addWidget(self.btn_copy)

        self.main_layout.addWidget(self.status_bar)

    def restore_geometry(self):
        geom = self.settings.get_window_geometry()
        if geom and "x" in geom:
            w, h = map(int, geom.split("x"))
            self.resize(w, h)

    @Slot(str, str)
    def update_status(self, msg, color=""):
        self.lbl_status.setText(msg)
        if color:
            self.lbl_status.setStyleSheet(f"color: {color};")
        else:
            self.lbl_status.setStyleSheet("")

    def start_translation(self):
        text = self.txt_input.toPlainText().strip()
        if not text:
            QMessageBox.warning(self, "No Input", "Please enter some text to translate.")
            return

        self.is_translating = True
        self.btn_translate.setVisible(False)
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0) # Indeterminate

        threading.Thread(target=self.run_translation, args=(text,), daemon=True).start()

    def run_translation(self, text):
        try:
            self.signals.status_changed.emit("Translating to Japanese...", "#FF9F0A")

            # Forward
            ja_text = self.translation_service.translate_text(
                None, text, "en", "ja", provider_id=PROVIDER_GOOGLE_UNOFFICIAL
            )
            if ja_text.is_success():
                self.signals.intermediate_ready.emit(ja_text.value)
            else:
                raise Exception(str(ja_text.error))

            # Backward
            self.signals.status_changed.emit("Translating back to English...", "#FF9F0A")
            en_text = self.translation_service.translate_text(
                None, ja_text.value, "ja", "en", provider_id=PROVIDER_GOOGLE_UNOFFICIAL
            )
            if en_text.is_success():
                self.signals.result_ready.emit(en_text.value)
            else:
                raise Exception(str(en_text.error))

            self.signals.status_changed.emit("Done", "#30D158")
        except Exception as e:
            self.signals.error.emit(str(e))
        finally:
            self.signals.finished.emit()

    @Slot(str)
    def on_intermediate_ready(self, text):
        self.card_ja.text_area.setPlainText(text)

    @Slot(str)
    def on_result_ready(self, text):
        self.card_en.text_area.setPlainText(text)

    @Slot()
    def on_translation_finished(self):
        self.is_translating = False
        self.progress_bar.setVisible(False)
        self.btn_translate.setVisible(True)

    @Slot(str)
    def on_translation_error(self, err_msg):
        QMessageBox.critical(self, "Translation Error", f"Failed to translate: {err_msg}")
        self.update_status("Error", "#FF453A")

    def copy_to_clipboard(self):
        res = self.card_en.text_area.toPlainText()
        if res:
            from PySide6.QtGui import QGuiApplication
            QGuiApplication.clipboard().setText(res)
            self.update_status("Copied result to clipboard", "#30D158")

    def open_file_dialog(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Open File", "", "Text Files (*.txt *.md *.html *.epub);;All Files (*)"
        )
        if file_path:
            if file_path.lower().endswith(".epub"):
                proc = EpubProcessor(file_path)
                chapters = proc.get_chapters()
                if chapters:
                    self.txt_input.setPlainText(proc.get_chapter_content(chapters[0]))
            else:
                res = load_text_from_path(file_path)
                if res.is_success():
                    self.txt_input.setPlainText(res.value)

    def open_batch_dialog(self):
        dir_path = QFileDialog.getExistingDirectory(self, "Select Directory for Batch Processing")
        if dir_path:
            # Need to implement a simple Qt-based progress dialog for batch
            QMessageBox.information(self, "Batch", f"Starting batch processing in: {dir_path}")
            # Placeholder for batch logic

    def on_closing(self):
        self.settings.set_window_geometry(f"{self.width()}x{self.height()}")
        self.close()
