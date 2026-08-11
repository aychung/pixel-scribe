import { expect, test } from "@playwright/test";
import { runAccessibilityScan } from "./support/accessibility";

test.describe("application shell", () => {
  test("prefills the display name from the encoded Unicode preference cookie", async ({ page }) => {
    await page.context().addCookies([
      {
        name: "pixel_scribe_username",
        value: "Zo%C3%AB%20%F0%9F%A7%91%F0%9F%8F%BD%E2%80%8D%F0%9F%92%BB",
        url: "http://localhost:1234/",
      },
    ]);

    await page.goto("/");

    await expect(page.getByRole("textbox", { name: "Display name" })).toHaveValue(
      "Zoë 🧑🏽‍💻",
    );
  });

  test("writes the Unicode preference with the exact HTTP cookie policy", async ({
    page,
  }) => {
    await page.routeWebSocket("/ws", () => {});
    await page.addInitScript(() => {
      const descriptor = Object.getOwnPropertyDescriptor(
        Document.prototype,
        "cookie",
      );
      if (descriptor?.set === undefined) throw new Error("cookie setter unavailable");
      const writes: string[] = [];
      Object.defineProperty(document, "cookie", {
        configurable: true,
        get: descriptor.get,
        set: (value: string) => {
          writes.push(value);
          descriptor.set?.call(document, value);
        },
      });
      (window as typeof window & { __cookieWrites?: string[] }).__cookieWrites = writes;
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Zoë 🧑🏽‍💻");
    await username.press("Enter");

    await expect
      .poll(() =>
        page.evaluate(
          () => (window as typeof window & { __cookieWrites?: string[] }).__cookieWrites,
        ),
      )
      .toEqual([
        "pixel_scribe_username=Zo%C3%AB%20%F0%9F%A7%91%F0%9F%8F%BD%E2%80%8D%F0%9F%92%BB; Max-Age=15552000; Path=/; SameSite=Strict",
      ]);

    const cookie = (await page.context().cookies("http://localhost:1234/"))
      .find((candidate) => candidate.name === "pixel_scribe_username");
    expect(cookie).toMatchObject({
      name: "pixel_scribe_username",
      value: "Zo%C3%AB%20%F0%9F%A7%91%F0%9F%8F%BD%E2%80%8D%F0%9F%92%BB",
      path: "/",
      sameSite: "Strict",
      secure: false,
      httpOnly: false,
    });
    expect(cookie?.expires).toBeGreaterThanOrEqual(
      Math.floor(Date.now() / 1000) + 15_552_000 - 2,
    );
    expect(cookie?.expires).toBeLessThanOrEqual(
      Math.floor(Date.now() / 1000) + 15_552_000 + 2,
    );
  });

  test("returns focus to the username field after validation failure", async ({ page }) => {
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("a".repeat(33));
    const submit = page.getByRole("button", { name: "Enter the office" });
    await submit.focus();
    await expect(submit).toBeFocused();
    await submit.press("Enter");

    await expect(page.getByRole("alert")).toHaveText(
      "Username must be 32 characters or fewer.",
    );
    await expect(username).toBeFocused();
  });

  test("renders named controls and submits the username form from the keyboard", async ({ page }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));

    await page.routeWebSocket("/ws", () => {});
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
