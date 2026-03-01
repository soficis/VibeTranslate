export type ProviderId = "google_unofficial";

export const DEFAULT_PROVIDER_ID: ProviderId = "google_unofficial";

const PROVIDER_ID_ALIASES: Record<string, ProviderId> = {
  google_unofficial: DEFAULT_PROVIDER_ID,
  unofficial: DEFAULT_PROVIDER_ID,
  google_unofficial_free: DEFAULT_PROVIDER_ID,
  google_free: DEFAULT_PROVIDER_ID,
  googletranslate: DEFAULT_PROVIDER_ID,
  "": DEFAULT_PROVIDER_ID
};

export const normalizeProviderId = (providerId: string | null | undefined): ProviderId => {
  const normalized = (providerId ?? "").trim().toLowerCase();
  return PROVIDER_ID_ALIASES[normalized] ?? DEFAULT_PROVIDER_ID;
};
