import { describe, expect, it } from "vitest";
import { DEFAULT_PROVIDER_ID, normalizeProviderId } from "../../providerId";

describe("providerId", () => {
  it("normalizes aliases to google_unofficial", () => {
    const aliases = [
      "google_unofficial",
      "unofficial",
      "google_unofficial_free",
      "google_free",
      "googletranslate",
      "",
      "  unofficial  ",
      "GOOGLE_UNOFFICIAL",
      undefined,
      null,
      "unknown_provider"
    ];

    for (const alias of aliases) {
      expect(normalizeProviderId(alias)).toBe(DEFAULT_PROVIDER_ID);
    }
  });
});
