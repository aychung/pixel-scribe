import { expect, test } from "@playwright/test";
import { runAccessibilityScan } from "./support/accessibility";

test.describe("application shell", () => {
  test("renders named controls and submits the username form from the keyboard", async ({ page }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));

    await page.goto("/");

    await expect(page.getByRole("heading", { name: "Pixel Scribe" })).toBeVisible();
    await expect(
      page.getByRole("region", { name: "Office preview" }),
    ).toBeVisible();
    await expect(
      page.getByRole("img", {
        name: "A quiet pixel-art office waiting for visitors",
      }),
    ).toBeVisible();

    const joinPanel = page.getByRole("region", { name: "Join the office" });
    await expect(joinPanel).toBeVisible();

    const username = page.getByRole("textbox", { name: "Display name" });
    await expect(username).toHaveAttribute("autocomplete", "nickname");
    await expect(
      joinPanel.getByRole("button", { name: "Enter the office" }),
    ).toBeVisible();

    await username.fill("Ada");
    await username.press("Enter");
    await expect(username).toHaveValue("Ada");

    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });

  test("keeps essential shell elements inside a 320px viewport", async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 720 });
    await page.goto("/");

    const essentialElements = [
      page.getByRole("heading", { name: "Pixel Scribe" }),
      page.getByRole("img", {
        name: "A quiet pixel-art office waiting for visitors",
      }),
      page.getByRole("textbox", { name: "Display name" }),
      page.getByRole("button", { name: "Enter the office" }),
    ];
    const viewportWidth = page.viewportSize()?.width;
    expect(viewportWidth).toBe(320);

    for (const element of essentialElements) {
      const bounds = await element.boundingBox();
      expect(bounds).not.toBeNull();
      expect(bounds?.x).toBeGreaterThanOrEqual(0);
      expect(bounds?.x).toBeLessThanOrEqual(viewportWidth);
      expect((bounds?.x ?? 0) + (bounds?.width ?? 0)).toBeLessThanOrEqual(
        viewportWidth,
      );
    }

    const hasHorizontalOverflow = await page.evaluate(
      () =>
        document.documentElement.scrollWidth >
          document.documentElement.clientWidth ||
        document.body.scrollWidth > document.body.clientWidth,
    );
    expect(hasHorizontalOverflow).toBe(false);
  });

  test("has no WCAG A or AA accessibility violations", async ({ page }) => {
    await page.goto("/");

    const results = await runAccessibilityScan(page);

    expect(results.violations).toEqual([]);
  });
});
