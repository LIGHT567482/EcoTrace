import { afterEach, describe, expect, it, vi } from "vitest";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  vi.resetModules();
});

describe("API base URL wiring", () => {
  it("uses the configured production API URL", async () => {
    vi.stubEnv("DEV", false);
    vi.stubEnv("VITE_API_URL", "");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ status: "ok" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      ),
    );

    const { api } = await import("./api.js");
    const result = await api("/health/", { auth: false });

    expect(result).toEqual({ status: "ok" });
    expect(fetch).toHaveBeenCalledWith(
      "https://ecotrace-api-sr9f.onrender.com/api/health/",
      expect.objectContaining({ method: "GET" }),
    );
  });

  it("normalizes a configured API URL with trailing slashes", async () => {
    vi.stubEnv("DEV", false);
    vi.stubEnv("VITE_API_URL", "https://api.example.test/api///");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ status: "ok" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      ),
    );

    const { api } = await import("./api.js");
    await api("/health/", { auth: false });

    expect(fetch).toHaveBeenCalledWith(
      "https://api.example.test/api/health/",
      expect.objectContaining({ method: "GET" }),
    );
  });
});
