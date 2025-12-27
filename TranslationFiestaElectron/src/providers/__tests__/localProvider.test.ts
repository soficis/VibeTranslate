import { describe, expect, it } from "vitest";
import { translateLocal } from "../local";

describe("local provider", () => {
  it("uses local service bridge", async () => {
    (globalThis as any).window = {
      translationFiesta: {
        localService: {
          translate: async () => ({ translatedText: "hello" })
        }
      }
    };

    const result = await translateLocal("こんにちは", "ja", "en");
    expect(result).toBe("hello");
  });

  it("throws when bridge missing", async () => {
    (globalThis as any).window = {};
    await expect(translateLocal("hi", "en", "ja")).rejects.toThrow("config_error");
  });
});
