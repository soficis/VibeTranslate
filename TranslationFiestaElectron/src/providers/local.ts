export type LocalProviderOptions = {
  signal?: AbortSignal;
};

export const translateLocal = async (text: string, sourceLang: string, targetLang: string, _options: LocalProviderOptions = {}) => {
  if (!text.trim()) {
    throw new Error("user_error");
  }
  if (!window.translationFiesta?.localService) {
    throw new Error("config_error");
  }
  const response = await window.translationFiesta.localService.translate({
    text,
    source_lang: sourceLang,
    target_lang: targetLang
  });
  if (!response.translatedText) {
    throw new Error(response.error ?? "network_error");
  }
  const trimmed = response.translatedText.trim();
  if (!trimmed) {
    throw new Error("invalid_response");
  }
  return trimmed;
};

