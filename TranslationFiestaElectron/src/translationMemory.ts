export type ProviderId = "google_unofficial";

type Entry = {
  key: string;
  value: string;
  accessedAt: number;
};

type Persisted = {
  version: 1;
  maxEntries: number;
  entries: Entry[];
};

const storageKey = "tf_tm_v1";

const loadPersisted = (): Persisted => {
  try {
    const raw = localStorage.getItem(storageKey);
    if (!raw) throw new Error("empty");
    const parsed = JSON.parse(raw) as Persisted;
    if (parsed.version !== 1) throw new Error("bad");
    return parsed;
  } catch {
    return { version: 1, maxEntries: 500, entries: [] };
  }
};

const savePersisted = (data: Persisted) => {
  localStorage.setItem(storageKey, JSON.stringify(data));
};

export const buildTmKey = (providerId: ProviderId, sourceLang: string, targetLang: string, text: string) =>
  `${providerId}:${sourceLang}:${targetLang}:${text}`;

export const lookup = (providerId: ProviderId, sourceLang: string, targetLang: string, text: string) => {
  const key = buildTmKey(providerId, sourceLang, targetLang, text);
  const data = loadPersisted();
  const found = data.entries.find((entry) => entry.key === key);
  if (!found) return undefined;
  found.accessedAt = Date.now();
  savePersisted(data);
  return found.value;
};

export const store = (providerId: ProviderId, sourceLang: string, targetLang: string, text: string, value: string) => {
  const key = buildTmKey(providerId, sourceLang, targetLang, text);
  const data = loadPersisted();
  const now = Date.now();
  const existing = data.entries.find((entry) => entry.key === key);
  if (existing) {
    existing.value = value;
    existing.accessedAt = now;
  } else {
    data.entries.push({ key, value, accessedAt: now });
  }

  if (data.entries.length > data.maxEntries) {
    data.entries.sort((a, b) => b.accessedAt - a.accessedAt);
    data.entries = data.entries.slice(0, data.maxEntries);
  }

  savePersisted(data);
};

export const clear = () => {
  savePersisted({ version: 1, maxEntries: 500, entries: [] });
};

