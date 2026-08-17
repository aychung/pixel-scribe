import { expect, test, type Page, type WebSocketRoute } from "@playwright/test";
import { runAccessibilityScan } from "./support/accessibility";

const joinFrame = '{"type":"join_room","room_id":"default","username":"Ada"}';

function roomState() {
  return JSON.stringify({
    type: "room_state",
    room_id: "default",
    self_id: "connection-self",
    users: [{ connection_id: "connection-self", username: "Ada" }],
    messages: [],
  });
}

function errorFrame(
  code: string,
  message: string,
  recoverable: boolean,
) {
  return JSON.stringify({
    type: "error",
    room_id: "default",
    code,
    message,
    recoverable,
  });
}

async function scan(page: Page) {
  const results = await runAccessibilityScan(page);
  expect(results.violations).toEqual([]);
}

async function openUsername(page: Page) {
  await page.goto("/");
  await expect(page.getByRole("textbox", { name: "Display name" })).toBeVisible();
}

async function joinOffice(page: Page) {
  let socketRoute: WebSocketRoute | undefined;
  await page.routeWebSocket("/ws", (socket) => {
    socketRoute = socket;
    socket.onMessage((message) => {
      if (message === joinFrame) socket.send(roomState());
    });
  });
  await openUsername(page);
  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect(page.getByRole("status")).toHaveText("Joined the default office.");
  return socketRoute;
}

test.describe("unsuppressed WCAG A/AA state coverage", () => {
  test("username state has no automated violations", async ({ page }) => {
    await openUsername(page);
    await scan(page);
  });

  test("joined state has no automated violations", async ({ page }) => {
    await joinOffice(page);
    await scan(page);
  });

  test("reconnecting state keeps a usable semantic workspace", async ({ page }) => {
    const socket = await joinOffice(page);
    await socket?.close();
    await expect(page.getByRole("status")).toContainText("Connection lost. Reconnecting");
    await expect(page.getByRole("textbox", { name: "Message" })).toBeDisabled();
    await scan(page);
  });

  test("protocol-failure state focuses its recovery status", async ({ page }) => {
    let socketRoute: WebSocketRoute | undefined;
    await page.routeWebSocket("/ws", (socket) => {
      socketRoute = socket;
      socket.onMessage((message) => {
        if (message === joinFrame) socket.send("not-json");
      });
    });
    await openUsername(page);
    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("alert")).toHaveText("Protocol error.");
    await expect(page.locator("#connection-status")).toBeFocused();
    await expect(page.getByRole("button", { name: "Retry connection" })).toBeVisible();
    await scan(page);
    await socketRoute?.close();
  });

  test("room-full state exposes a named retry without relying on color", async ({ page }) => {
    await page.routeWebSocket("/ws", (socket) => {
      socket.onMessage((message) => {
        if (message === joinFrame) {
          socket.send(errorFrame("room_full", "Room is full.", false));
        }
      });
    });
    await openUsername(page);
    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toHaveText("The office is full right now.");
    await expect(page.getByRole("alert")).toHaveText("Room is full.");
    await expect(page.getByRole("textbox", { name: "Display name" })).toBeDisabled();
    await expect(page.getByRole("button", { name: "Enter the office" })).toBeDisabled();
    await expect(page.getByRole("button", { name: "Retry connection" })).toBeVisible();
    await scan(page);
  });

  test("pre-snapshot reconnect disables the unusable username form", async ({ page }) => {
    await page.routeWebSocket("/ws", (socket) => {
      socket.onMessage((message) => {
        if (message === joinFrame) socket.close();
      });
    });
    await openUsername(page);
    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toContainText("Connection lost. Reconnecting");
    await expect(username).toBeDisabled();
    await expect(page.getByRole("button", { name: "Enter the office" })).toBeDisabled();
    await expect(page.locator(".username-form")).toHaveAttribute("aria-busy", "false");
    await scan(page);
  });

  test("room-unavailable state preserves chat semantics while disabling sends", async ({ page }) => {
    const socket = await joinOffice(page);
    await socket?.send(errorFrame(
      "room_unavailable",
      "Room is unavailable. Reconnect to continue.",
      false,
    ));
    await expect(page.getByRole("alert")).toHaveText(
      "Room is unavailable. Reconnect to continue.",
    );
    await expect(page.getByRole("textbox", { name: "Message" })).toBeDisabled();
    await socket?.close();
    await expect(page.getByRole("button", { name: "Retry now" })).toBeVisible();
    await scan(page);
  });

  test("focus remains in the workspace when a manual retry starts", async ({ page }) => {
    const socket = await joinOffice(page);
    await socket?.close();
    const retry = page.getByRole("button", { name: "Retry now" });
    await expect(retry).toBeVisible();
    await retry.focus();
    await retry.click();
    await expect(page.locator("#connection-status")).toBeFocused();
  });
});
