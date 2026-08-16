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
const fixedSeed = 2147483648;

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

async function installDeterminism(page: Page) {
  await page.addInitScript((seed) => {
    Object.defineProperty(Math, "random", { value: () => 0.5 });
    const nativeGetRandomValues = globalThis.crypto.getRandomValues.bind(
      globalThis.crypto,
    );
    Object.defineProperty(globalThis.crypto, "getRandomValues", {
      value: (values: Uint32Array) => {
        if (values instanceof Uint32Array && values.length === 1) {
          values[0] = seed;
          return values;
        }
        return nativeGetRandomValues(values);
      },
    });
  }, fixedSeed);
}

async function joinOffice(
  page: Page,
  routeAssets: boolean,
  peerConnectionId = peerId,
  peerUsername = "Lin",
  selfConnectionId = selfId,
  includePeer = true,
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
            self_id: selfConnectionId,
            users: [
              { connection_id: selfConnectionId, username: "Ada" },
              ...(includePeer
                ? [{ connection_id: peerConnectionId, username: peerUsername }]
                : []),
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

async function canvasMetrics(page: Page) {
  return page.locator("#office-canvas").evaluate((element) => {
    const canvas = element as HTMLCanvasElement;
    const context = canvas.getContext("2d");
    if (context === null) throw new Error("Canvas 2D context unavailable");
    const rect = canvas.getBoundingClientRect();
    const style = getComputedStyle(canvas);
    const cssWidth =
      rect.width - parseFloat(style.borderLeftWidth) - parseFloat(style.borderRightWidth);
    const cssHeight =
      rect.height - parseFloat(style.borderTopWidth) - parseFloat(style.borderBottomWidth);
    const dpr = window.devicePixelRatio;
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const centerX = cssWidth / 2;
    const centerY = cssHeight / 2;
    const radius = 1.5;
    let centerGold = 0;
    let minGoldX = canvas.width;
    let minGoldY = canvas.height;
    let maxGoldX = -1;
    let maxGoldY = -1;
    for (let y = 0; y < canvas.height; y += 1) {
      for (let x = 0; x < canvas.width; x += 1) {
        const index = (y * canvas.width + x) * 4;
        const red = pixels[index];
        const green = pixels[index + 1];
        const blue = pixels[index + 2];
        const alpha = pixels[index + 3];
        const cssX = x / dpr;
        const cssY = y / dpr;
        if (
          alpha > 0 &&
          red > 180 &&
          green > 130 &&
          blue < 150 &&
          Math.abs(cssX - centerX) <= radius &&
          Math.abs(cssY - centerY) <= radius
        ) {
          centerGold += 1;
          minGoldX = Math.min(minGoldX, x);
          minGoldY = Math.min(minGoldY, y);
          maxGoldX = Math.max(maxGoldX, x);
          maxGoldY = Math.max(maxGoldY, y);
        }
      }
    }
    let fingerprint = 0;
    for (let index = 0; index < pixels.length; index += 16) {
      fingerprint = (fingerprint * 31 + pixels[index]) >>> 0;
    }
    const corner = context.getImageData(2 * dpr, 2 * dpr, 1, 1).data;
    return {
      cssWidth,
      cssHeight,
      dpr,
      width: canvas.width,
      height: canvas.height,
      centerGold,
      centerGoldCenter: {
        x: (minGoldX + maxGoldX) / 2 / dpr,
        y: (minGoldY + maxGoldY) / 2 / dpr,
      },
      fingerprint,
      corner: [corner[0], corner[1], corner[2], corner[3]],
    };
  });
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

for (const dpr of [1, 2] as const) {
  test.describe(`camera crop and culling at DPR ${dpr}`, () => {
    test.use({
      viewport: { width: 320, height: 720 },
      deviceScaleFactor: dpr,
    });

    test("keeps the self visual center invariant and rounds backing geometry", async ({
      page,
    }) => {
      await installDeterminism(page);
      const socket = await joinOffice(page, false);
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);

      const before = await canvasMetrics(page);
      expect(before.dpr).toBe(dpr);
      expect(before.width).toBe(Math.round(before.cssWidth * dpr));
      expect(before.height).toBe(Math.round(before.cssHeight * dpr));
      expect(Math.abs(before.centerGoldCenter.x - before.cssWidth / 2)).toBeLessThan(1.1);
      expect(Math.abs(before.centerGoldCenter.y - before.cssHeight / 2)).toBeLessThan(1.1);

      socket.send(
        JSON.stringify({
          type: "user_joined",
          room_id: "default",
          user: { connection_id: "zz-offscreen", username: "Far" },
        }),
      );
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);
      const afterPeer = await canvasMetrics(page);
      expect(Math.abs(afterPeer.centerGoldCenter.x - afterPeer.cssWidth / 2)).toBeLessThan(1.1);
      expect(Math.abs(afterPeer.centerGoldCenter.y - afterPeer.cssHeight / 2)).toBeLessThan(1.1);

      await page.setViewportSize({ width: 400, height: 720 });
      await expect
        .poll(async () => {
          const metrics = await canvasMetrics(page);
          return metrics.width !== before.width && metrics.height !== before.height;
        })
        .toBe(true);
      const resized = await canvasMetrics(page);
      expect(resized.width).toBe(Math.round(resized.cssWidth * dpr));
      expect(resized.height).toBe(Math.round(resized.cssHeight * dpr));
      expect(Math.abs(resized.centerGoldCenter.x - resized.cssWidth / 2)).toBeLessThan(1.1);
      expect(Math.abs(resized.centerGoldCenter.y - resized.cssHeight / 2)).toBeLessThan(1.1);
    });

    test("keeps offscreen participants semantic while culling their canvas work", async ({
      page,
    }) => {
      await installDeterminism(page);
      await page.setViewportSize({ width: 1024, height: 720 });
      const socket = await joinOffice(page, false, "zz-far-54", "Lin");
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);
      const before = await canvasMetrics(page);

      await expect(
        page.getByRole("region", { name: "Participants" }).getByText("Lin", {
          exact: true,
        }),
      ).toBeVisible();
      socket.send(
        JSON.stringify({
          type: "user_joined",
          room_id: "default",
          user: { connection_id: "zz-far-65", username: "Far" },
        }),
      );
      await expect(
        page.getByRole("region", { name: "Participants" }).getByText("Far", {
          exact: true,
        }),
      ).toBeVisible();
      await expect.poll(async () => (await canvasMetrics(page)).fingerprint).toBe(before.fingerprint);
    });

    test("fills an out-of-world edge crop without moving the self", async ({ page }) => {
      await installDeterminism(page);
      await joinOffice(page, false, "zz-peer", "Peer", "edge-51", false);
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);
      const metrics = await canvasMetrics(page);
      expect(Math.abs(metrics.centerGoldCenter.x - metrics.cssWidth / 2)).toBeLessThan(1.1);
      expect(Math.abs(metrics.centerGoldCenter.y - metrics.cssHeight / 2)).toBeLessThan(1.1);
      expect(metrics.corner).toEqual([24, 35, 42, 255]);
    });

    test("retargets the camera to a replacement self after reconnect", async ({ page }) => {
      await installDeterminism(page);
      await page.clock.install({ time: new Date("2026-08-13T12:00:00Z") });
      const sessions: WebSocketRoute[] = [];
      await page.routeWebSocket("/ws", (socket) => {
        sessions.push(socket);
        socket.onMessage((message) => {
          const frame = JSON.parse(message.toString()) as { type?: string };
          if (frame.type !== "join_room") return;
          const nextSelf = sessions.length === 1 ? "edge-51" : "edge-50";
          socket.send(
            JSON.stringify({
              type: "room_state",
              room_id: "default",
              self_id: nextSelf,
              users: [{ connection_id: nextSelf, username: "Ada" }],
              messages: [],
            }),
          );
        });
      });
      await page.goto("/");
      await page.getByRole("textbox", { name: "Display name" }).fill("Ada");
      await page.getByRole("textbox", { name: "Display name" }).press("Enter");
      await expect(page.getByRole("status")).toHaveText("Joined the default office.");
      await expect.poll(() => sessions).toHaveLength(1);
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);
      const first = await canvasMetrics(page);
      expect(first.corner).toEqual([24, 35, 42, 255]);

      await sessions[0].close();
      await expect(page.getByRole("status")).toHaveText("Connection lost. Reconnecting…");
      await page.clock.fastForward(500);
      await expect.poll(() => sessions).toHaveLength(2);
      await expect(page.getByRole("status")).toHaveText("Joined the default office.");
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);
      const second = await canvasMetrics(page);
      expect(Math.abs(second.centerGoldCenter.x - second.cssWidth / 2)).toBeLessThan(1.1);
      expect(Math.abs(second.centerGoldCenter.y - second.cssHeight / 2)).toBeLessThan(1.1);
      expect(second.corner).not.toEqual(first.corner);
    });
  });
}
