export type UnofficialGoogleOptions = {
  fetchFn?: typeof fetch;
  maxRetries?: number;
  minBackoffMs?: number;
  maxBackoffMs?: number;
  signal?: AbortSignal;
};

const defaultOptions: Required<Pick<UnofficialGoogleOptions, "maxRetries" | "minBackoffMs" | "maxBackoffMs">> = {
  maxRetries: 3,
  minBackoffMs: 200,
  maxBackoffMs: 2000
};

export const buildUnofficialGoogleUrl = (text: string, sourceLang: string, targetLang: string) => {
  const params = new URLSearchParams({
    client: "gtx",
    sl: sourceLang,
    tl: targetLang,
    dt: "t",
    q: text
  });
  return `https://translate.googleapis.com/translate_a/single?${params.toString()}`;
};

export const parseUnofficialGoogleResponse = (data: unknown) => {
  const root = Array.isArray(data) ? data : null;
  const sentences = root && Array.isArray(root[0]) ? (root[0] as unknown[]) : [];

  let output = "";
  for (const sentence of sentences) {
    if (Array.isArray(sentence) && typeof sentence[0] === "string") {
      output += sentence[0];
    }
  }

  const trimmed = output.trim();
  if (!trimmed) {
    throw new Error("invalid_response");
  }
  return trimmed;
};

const jitter = (ms: number) => Math.floor(ms * (0.7 + Math.random() * 0.6));

const sleep = (ms: number, signal?: AbortSignal) =>
  new Promise<void>((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    if (!signal) return;
    const onAbort = () => {
      clearTimeout(timer);
      reject(new DOMException("Aborted", "AbortError"));
    };
    if (signal.aborted) return onAbort();
    signal.addEventListener("abort", onAbort, { once: true });
  });

const classifyHttpStatus = (status: number) => {
  if (status === 429) return "rate_limited";
  if (status === 403) return "blocked";
  if (status >= 500) return "network_error";
  return "invalid_response";
};

export const translateUnofficialGoogle = async (
  text: string,
  sourceLang: string,
  targetLang: string,
  options: UnofficialGoogleOptions = {}
) => {
  const fetchFn = options.fetchFn ?? fetch;
  const maxRetries = options.maxRetries ?? defaultOptions.maxRetries;
  const minBackoffMs = options.minBackoffMs ?? defaultOptions.minBackoffMs;
  const maxBackoffMs = options.maxBackoffMs ?? defaultOptions.maxBackoffMs;

  if (!text.trim()) {
    throw new Error("user_error");
  }

  const url = buildUnofficialGoogleUrl(text, sourceLang, targetLang);

  let lastError: unknown = undefined;
  for (let attempt = 1; attempt <= maxRetries; attempt += 1) {
    try {
      const response = await fetchFn(url, {
        method: "GET",
        signal: options.signal,
        headers: { Accept: "application/json,text/plain,*/*" }
      });

      if (!response.ok) {
        throw new Error(classifyHttpStatus(response.status));
      }
      const data = (await response.json()) as unknown;
      return parseUnofficialGoogleResponse(data);
    } catch (error) {
      lastError = error;
      if (attempt >= maxRetries) break;
      const backoff = Math.min(maxBackoffMs, minBackoffMs * 2 ** (attempt - 1));
      await sleep(jitter(backoff), options.signal);
    }
  }

  if (lastError instanceof DOMException && lastError.name === "AbortError") {
    throw lastError;
  }
  throw lastError instanceof Error ? lastError : new Error("network_error");
};

