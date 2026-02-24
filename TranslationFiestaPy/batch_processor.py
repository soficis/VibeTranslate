import os

from langdetect import detect
from langdetect.lang_detect_exception import LangDetectException

from bleu_scorer import get_bleu_scorer
from enhanced_logger import get_logger
from file_utils import load_text_from_path
from provider_ids import normalize_provider_id
from translation_services import TranslationService


class BatchProcessor:
    def __init__(self, translation_service: TranslationService, update_callback=None):
        self.translation_service = translation_service
        self.update_callback = update_callback
        self.logger = get_logger()
        self.bleu_scorer = get_bleu_scorer()
        self.is_running = False

    def process_directory(
        self,
        directory_path,
        provider_id=None,
        source_lang=None,
        target_lang="ja",
    ):
        self.is_running = True
        files_to_process = [f for f in os.listdir(directory_path) if f.endswith(('.txt', '.md', '.html'))]
        total_files = len(files_to_process)
        self.logger.info(f"Starting batch processing for {total_files} files in {directory_path}")
        resolved_provider_id = normalize_provider_id(provider_id)

        for i, filename in enumerate(files_to_process):
            if not self.is_running:
                self.logger.info("Batch processing stopped by user.")
                break

            filepath = os.path.join(directory_path, filename)
            self.logger.info(f"Processing file {i + 1}/{total_files}: {filename}")

            try:
                result = load_text_from_path(filepath)
                if result.is_success():
                    content = result.value
                    translated_content = self.back_translate_content(
                        content,
                        resolved_provider_id,
                        source_lang,
                        target_lang,
                    )
                    self.save_translated_file(filepath, translated_content, content)
                else:
                    self.logger.error(f"Failed to load file {filename}: {result.error}")

            except Exception as e:
                self.logger.error(f"An error occurred while processing {filename}: {e}")

            if self.update_callback:
                self.update_callback(i + 1, total_files)

        self.is_running = False
        self.logger.info("Batch processing finished.")

    def back_translate_content(
        self,
        content,
        provider_id,
        source_lang=None,
        target_lang="ja",
    ):
        resolved_provider_id = normalize_provider_id(provider_id)
        if not content or content.isspace():
            return ""

        if source_lang is None:
            try:
                source_lang = detect(content)
            except LangDetectException as error:
                self.logger.warning(f"Language detection failed, defaulting source language to 'en': {error}")
                source_lang = "en"  # fallback

        def validate_language(code):
            return len(code) == 2 and code.isalpha()

        if not validate_language(source_lang) or not validate_language(target_lang):
            raise ValueError(f"Invalid language codes: {source_lang}, {target_lang}")

        if source_lang == target_lang:
            return content

        # First translation: source -> target
        first_result = self.translation_service.translate_text(
            None,
            content,
            source_lang,
            target_lang,
            provider_id=resolved_provider_id,
        )
        if first_result.is_success():
            intermediate = first_result.value
            # Second translation: target -> source
            second_result = self.translation_service.translate_text(
                None,
                intermediate,
                target_lang,
                source_lang,
                provider_id=resolved_provider_id,
            )
            if second_result.is_success():
                backtranslated = second_result.value

                # Calculate BLEU score for quality assessment
                quality_assessment = self.bleu_scorer.assess_translation_quality(content, backtranslated)

                # Log quality assessment
                self.logger.info(
                    "Batch translation quality assessment",
                    extra={
                        "bleu_score": quality_assessment['bleu_score'],
                        "confidence_level": quality_assessment['confidence_level'],
                        "quality_rating": quality_assessment['quality_rating'],
                        "recommendations": quality_assessment['recommendations'],
                        "original_length": len(content),
                        "intermediate_length": len(intermediate),
                        "backtranslated_length": len(backtranslated),
                        "source_lang": source_lang,
                        "target_lang": target_lang
                    }
                )

                return backtranslated

        return "Translation Failed"

    def save_translated_file(self, original_path, translated_content, original_content=None):
        dir_name, file_name = os.path.split(original_path)
        name, ext = os.path.splitext(file_name)
        new_filename = f"{name}_translated{ext}"
        new_filepath = os.path.join(dir_name, new_filename)
        try:
            with open(new_filepath, 'w', encoding='utf-8') as f:
                f.write(translated_content)

                # Add quality assessment if original content is available
                if original_content:
                    quality_assessment = self.bleu_scorer.assess_translation_quality(original_content, translated_content)
                    f.write("\n\n=== QUALITY ASSESSMENT ===\n")
                    f.write(f"BLEU Score: {quality_assessment['bleu_percentage']}\n")
                    f.write(f"Confidence: {quality_assessment['confidence_level']}\n")
                    f.write(f"Rating: {quality_assessment['quality_rating']}\n")
                    f.write(f"Assessment: {quality_assessment['description']}\n")
                    f.write(f"Recommendations: {quality_assessment['recommendations']}\n")

            self.logger.info(f"Saved translated file to {new_filepath}")
        except Exception as e:
            self.logger.error(f"Failed to save translated file {new_filepath}: {e}")

    def stop(self):
        self.is_running = False
