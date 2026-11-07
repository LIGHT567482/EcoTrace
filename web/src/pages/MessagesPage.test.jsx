// Runtime validation coverage for: message composer availability.
// @vitest-environment jsdom

import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import MessagesPage from "./MessagesPage";

const mocks = vi.hoisted(() => ({
  api: vi.fn(),
}));

vi.mock("../api", () => ({
  api: mocks.api,
  formatDate: (value) => value,
}));

vi.mock("../auth", () => ({
  useAuth: () => ({ user: { id: 1 } }),
}));

describe("MessagesPage composer", () => {
  beforeEach(() => {
    mocks.api.mockReset();
    mocks.api.mockResolvedValueOnce([]);
  });

  it("allows drafting when no eligible recipient is available", async () => {
    render(<MessagesPage />);

    const composer = await screen.findByRole("textbox", { name: "Message" });
    expect(
      await screen.findByText(/eligible recipient is available/i),
    ).toBeTruthy();

    expect(composer.disabled).toBe(false);
    fireEvent.change(composer, { target: { value: "Hello, EcoTrace team." } });
    expect(composer.value).toBe("Hello, EcoTrace team.");
    expect(screen.getByRole("button", { name: "Send message" }).disabled).toBe(
      true,
    );
  });
});
