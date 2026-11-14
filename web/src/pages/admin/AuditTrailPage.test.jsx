// @vitest-environment jsdom

import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import AuditTrailPage from "./AuditTrailPage";

const mocks = vi.hoisted(() => ({
  api: vi.fn(),
}));

vi.mock("../../api", () => ({
  api: mocks.api,
  formatDate: (value) => value,
}));

vi.mock("../../components/ReportPrintTools", () => ({
  ReportPrintHeader: () => null,
}));

describe("AuditTrailPage", () => {
  beforeEach(() => {
    mocks.api.mockReset();
    mocks.api.mockResolvedValue({
      count: 1,
      next: null,
      previous: null,
      results: [
        {
          id: 1,
          created_at: "2026-11-13",
          actor_name: "EcoTrace Admin",
          actor_phone: "+256700123456",
          method: "GET",
          path: "/api/users/",
          status_code: 200,
        },
      ],
    });
  });

  it("shows each actor's login phone in its own username column", async () => {
    render(<AuditTrailPage />);

    expect(
      await screen.findByRole("columnheader", { name: "Username (phone)" }),
    ).toBeTruthy();
    expect(await screen.findByText("+256700123456")).toBeTruthy();
    expect(await screen.findByText("EcoTrace Admin")).toBeTruthy();
  });
});
