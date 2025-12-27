export type OfficialGoogleOptions = {
  fetchFn?: typeof fetch;
  signal?: AbortSignal;
};

export const translateOfficialGoogle = async (
  text: string,
  sourceLang: string,
  targetLang: string,
  apiKey: string,
  options: OfficialGoogleOptions = {}
) => {
  if (!text.trim()) {
    throw new Error("user_error");
  }
  if (!apiKey) {
    throw new Error("config_error");
  }

  const fetchFn = options.fetchFn ?? fetch;
  const response = await fetchFn(
    `https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      signal: options.signal,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        q: [text],
        target: targetLang,
        source: sourceLang,
        format: "text"
      })
    }
  );

  if (!response.ok) {
    if (response.status === 401 || response.status === 403) throw new Error("config_error");
    if (response.status === 429) throw new Error("rate_limited");
    throw new Error("network_error");
  }

  const payload = (await response.json()) as {
    data?: { translations?: { translatedText?: string }[] };
  };
  const translatedText = payload.data?.translations?.[0]?.translatedText?.trim() ?? "";
  if (!translatedText) {
    throw new Error("invalid_response");
  }
  return translatedText;
};

