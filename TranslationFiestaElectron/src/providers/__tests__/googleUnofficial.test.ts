import { describe, expect, it } from "vitest";
import { buildUnofficialGoogleUrl, parseUnofficialGoogleResponse } from "../googleUnofficial";

describe("googleUnofficial", () => {
  it("builds expected URL", () => {
    const url = buildUnofficialGoogleUrl("Hello world", "en", "ja");
    expect(url).toContain("https://translate.googleapis.com/translate_a/single?");
    expect(url).toContain("client=gtx");
    expect(url).toContain("sl=en");
    expect(url).toContain("tl=ja");
    expect(url).toContain("dt=t");
    expect(url).toContain("q=Hello+world");
  });

  it("parses segment array response", () => {
    const fixture = [
      [
        ["こんにちは世界", "Hello world", null, null, 1],
        ["！", "!", null, null, 1]
      ]
    ];
    expect(parseUnofficialGoogleResponse(fixture)).toBe("こんにちは世界！");
  });

  it("throws for invalid response", () => {
    expect(() => parseUnofficialGoogleResponse({})).toThrow("invalid_response");
  });
});

