import {
  expect,
  test,
  type Page,
  type WebSocketRoute,
} from "@playwright/test";

const selfId = "connection-self";
const peerId = "connection-peer";
const longPeerId = `opaque-${"x".repeat(256)}`;
const familyEmoji = "👨‍👩‍👧‍👦";
const graphemePeerName = familyEmoji.repeat(12);

function observeBrowserErrors(page: Page) {
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));
  return () => {
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  };
}

function observeAssetLoads(page: Page) {
  const loads = { tiles: 0, avatars: 0 };
  page.on("requestfinished", (request) => {
    const path = new URL(request.url()).pathname;
    if (path.endsWith("/pixel-art/office-tiles-16.png")) loads.tiles += 1;
    if (path.endsWith("/pixel-art/office-avatars-16.png")) loads.avatars += 1;
  });
  return loads;
}

async function joinOffice(
  page: Page,
  routeAssets: boolean,
  peerConnectionId = peerId,
  peerUsername = "Lin",
): Promise<WebSocketRoute> {
  if (routeAssets) {
    await page.route("**/pixel-art/office-*.png", async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 250));
      await route.fulfill({ status: 200, contentType: "image/png", body: "missing" });
    });
  }

  let routedSocket: WebSocketRoute | undefined;
  await page.routeWebSocket("/ws", (socket) => {
    routedSocket = socket;
    socket.onMessage((message) => {
      const frame = JSON.parse(message.toString()) as { type?: string };
      if (frame.type === "join_room") {
        socket.send(
          JSON.stringify({
            type: "room_state",
            room_id: "default",
            self_id: selfId,
            users: [
              { connection_id: selfId, username: "Ada" },
              { connection_id: peerConnectionId, username: peerUsername },
            ],
            messages: [],
          }),
        );
      }
    });
  });

  await page.goto("/");
  await page.getByRole("textbox", { name: "Display name" }).fill("Ada");
  await page.getByRole("textbox", { name: "Display name" }).press("Enter");
  await expect(page.getByRole("status")).toHaveText("Joined the default office.");
  if (routedSocket === undefined) throw new Error("WebSocket route was not opened");
  return routedSocket;
}

async function canvasInk(page: Page) {
  return page.locator("#office-canvas").evaluate((element) => {
    const canvas = element as HTMLCanvasElement;
    const context = canvas.getContext("2d");
    if (context === null) throw new Error("Canvas 2D context unavailable");
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    let opaque = 0;
    const colors = new Set<string>();
    for (let index = 0; index < pixels.length; index += 4) {
      if (pixels[index + 3] > 0) opaque += 1;
      if (pixels[index + 3] > 0 && colors.size < 32) {
        colors.add(`${pixels[index]},${pixels[index + 1]},${pixels[index + 2]}`);
      }
    }
    return { opaque, colors: colors.size, width: canvas.width, height: canvas.height };
  });
}

test.describe("canvas office scene", () => {
  test("draws the layered office and avatar scene after joining", async ({ page }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const assetLoads = observeAssetLoads(page);
    await joinOffice(page, false, longPeerId, graphemePeerName);

    await expect.poll(() => assetLoads.tiles).toBe(1);
    await expect.poll(() => assetLoads.avatars).toBe(1);
    await expect.poll(async () => (await canvasInk(page)).colors).toBeGreaterThan(8);
    const ink = await canvasInk(page);
    expect(ink.opaque, JSON.stringify(ink)).toBeGreaterThan(2_000);
    expect(ink.colors).toBeGreaterThan(3);
    await expect(page.locator("#office-canvas")).toHaveAttribute(
      "aria-label",
      "Pixel-art office canvas",
    );
    assertNoBrowserErrors();
  });

  test("draws useful fallback geometry and reports missing art", async ({ page }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const assetLoads = observeAssetLoads(page);
    const socket = await joinOffice(page, true, peerId, "Lin");

    const canvasHandle = await page.locator("#office-canvas").elementHandle();
    await expect(page.locator("#canvas-status")).toHaveText(
      "Office art unavailable; showing fallback geometry.",
    );
    expect(canvasHandle).not.toBeNull();
    expect(
      await page.evaluate(
        (canvas) => document.getElementById("office-canvas") === canvas,
        canvasHandle,
      ),
    ).toBe(true);

    const participants = page.getByRole("region", { name: "Participants" });
    await expect(participants.getByText("2 participants", { exact: true })).toBeVisible();
    socket.send(
      JSON.stringify({
        type: "user_joined",
        room_id: "default",
        user: { connection_id: "connection-churn", username: "Mia" },
      }),
    );
    await expect(participants.getByText("3 participants", { exact: true })).toBeVisible();
    socket.send(
      JSON.stringify({
        type: "user_left",
        room_id: "default",
        connection_id: "connection-churn",
      }),
    );
    await expect(participants.getByText("2 participants", { exact: true })).toBeVisible();
    await expect.poll(() => assetLoads.tiles).toBe(1);
    await expect.poll(() => assetLoads.avatars).toBe(1);
    await expect.poll(async () => (await canvasInk(page)).opaque).toBeGreaterThan(500);
    const ink = await canvasInk(page);
    expect(ink.opaque, JSON.stringify(ink)).toBeGreaterThan(500);
    await expect(page.locator("#canvas-status")).toHaveText(
      "Office art unavailable; showing fallback geometry.",
    );
    assertNoBrowserErrors();
  });
});
