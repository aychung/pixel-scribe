import {
  expect,
  test,
  type Page,
  type WebSocketRoute,
} from "@playwright/test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

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

async function installRafProbe(page: Page) {
  await page.addInitScript(() => {
    const callbacks = new Map<
      number,
      { callback: FrameRequestCallback; nativeId?: number }
    >();
    const canceledCallbacks: FrameRequestCallback[] = [];
    const nativeRequest = globalThis.requestAnimationFrame.bind(globalThis);
    const nativeCancel = globalThis.cancelAnimationFrame.bind(globalThis);
    const nativeMin = Math.min;
    let nextId = 1;
    const probe = {
      hold: false,
      requested: 0,
      canceled: 0,
      fired: 0,
      pending: 0,
      clears: 0,
      images: [] as unknown[],
      clampValues: [] as number[][],
      flush(timestamp: number) {
        const queued = [...callbacks.entries()].filter(([, entry]) => entry.nativeId === undefined);
        for (const [id, entry] of queued) {
          callbacks.delete(id);
          this.pending -= 1;
          this.fired += 1;
          entry.callback(timestamp);
        }
      },
      invokeCanceled(timestamp: number) {
        for (const callback of canceledCallbacks) callback(timestamp);
      },
    };
    Object.defineProperty(globalThis, "__canvasRafProbe", {
      configurable: true,
      value: probe,
    });
    Object.defineProperty(globalThis, "requestAnimationFrame", {
      configurable: true,
      value: (callback: FrameRequestCallback) => {
        const id = nextId;
        nextId += 1;
        probe.requested += 1;
        probe.pending += 1;
        if (probe.hold) {
          callbacks.set(id, { callback });
          return id;
        }
        const nativeId = nativeRequest((timestamp) => {
          callbacks.delete(id);
          probe.pending -= 1;
          probe.fired += 1;
          callback(timestamp);
        });
        callbacks.set(id, { callback, nativeId });
        return id;
      },
    });
    Object.defineProperty(globalThis, "cancelAnimationFrame", {
      configurable: true,
      value: (id: number) => {
        const entry = callbacks.get(id);
        if (entry) {
          callbacks.delete(id);
          probe.pending -= 1;
          canceledCallbacks.push(entry.callback);
          if (entry.nativeId !== undefined) nativeCancel(entry.nativeId);
        }
        probe.canceled += 1;
      },
    });
    const contextPrototype = CanvasRenderingContext2D.prototype;
    const nativeClearRect = contextPrototype.clearRect;
    Object.defineProperty(contextPrototype, "clearRect", {
      configurable: true,
      value(this: CanvasRenderingContext2D, ...arguments_: Parameters<typeof nativeClearRect>) {
        probe.clears += 1;
        return nativeClearRect.apply(this, arguments_);
      },
    });
    Object.defineProperty(Math, "min", {
      configurable: true,
      value: (...values: number[]) => {
        if (values[0] === 100 && values.length === 2) probe.clampValues.push(values);
        return nativeMin(...values);
      },
    });
  });
}

async function rafMetrics(page: Page) {
  return page.evaluate(() => {
    const probe = (globalThis as typeof globalThis & {
      __canvasRafProbe: {
        requested: number;
        canceled: number;
        fired: number;
        pending: number;
        clears: number;
        clampValues: number[][];
      };
    }).__canvasRafProbe;
    return {
      requested: probe.requested,
      canceled: probe.canceled,
      fired: probe.fired,
      pending: probe.pending,
      clears: probe.clears,
      clampValues: [...probe.clampValues],
    };
  });
}

async function installFfiModule(page: Page) {
  const source = readFileSync(
    resolve(process.cwd(), "src/pixel_scribe_frontend/canvas_ffi.mjs"),
    "utf8",
  );
  await page.route("**/__canvas_ffi_test__.mjs", async (route) => {
    await route.fulfill({
      contentType: "text/javascript",
      body: source,
    });
  });
}

async function prepareDirectFfi(page: Page) {
  await installRafProbe(page);
  await installFfiModule(page);
  await page.goto("/");
  await page.evaluate(() => {
    document.body.innerHTML =
      '<canvas id="office-canvas" style="display:block;width:320px;height:720px"></canvas>';
  });
  await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
  await page.evaluate(async () => {
    const probe = (globalThis as typeof globalThis & {
      __canvasRafProbe: { hold: boolean; images: unknown[] };
    }).__canvasRafProbe;
    class FakeImage {
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;
      set src(_url: string) {
        probe.images.push(this);
      }
    }
    Object.defineProperty(globalThis, "Image", {
      configurable: true,
      value: FakeImage,
    });
    probe.hold = true;
    const ffi = await import("/__canvas_ffi_test__.mjs");
    ffi.initialize_canvas(() => {}, () => {}, () => {});
    ffi.render_canvas(
      JSON.stringify({ avatars: [] }),
      JSON.stringify({
        origin_x: 0,
        origin_y: 0,
        viewport_width: 320,
        viewport_height: 720,
      }),
      () => {},
    );
  });
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
  test("coalesces dirty frames, clamps delay, and settles a static scene", async ({ page }) => {
    await prepareDirectFfi(page);
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(1);
    await page.evaluate(() => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      probe.flush(16);
    });
    const baseline = await rafMetrics(page);
    expect(baseline.pending).toBe(0);
    await page.evaluate(() => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { images: Array<{ onload: (() => void) | null }> };
      }).__canvasRafProbe;
      for (const image of probe.images) image.onload?.();
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(1);
    await expect.poll(async () => (await rafMetrics(page)).clears).toBe(baseline.clears);
    await page.evaluate(() => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      probe.hold = false;
      probe.flush(10_000);
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
    await expect.poll(async () => (await canvasInk(page)).opaque).toBeGreaterThan(500);
    await expect.poll(async () => (await rafMetrics(page)).clears).toBeGreaterThan(baseline.clears);
    const settled = await rafMetrics(page);
    expect(settled.clampValues).toContainEqual([100, 9984]);
    await expect.poll(async () => (await rafMetrics(page)).requested).toBe(settled.requested);
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);

    await page.evaluate(async () => {
      const ffi = await import("/__canvas_ffi_test__.mjs");
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean };
      }).__canvasRafProbe;
      probe.hold = true;
      ffi.render_canvas(
        JSON.stringify({ avatars: [] }),
        JSON.stringify({
          origin_x: 0,
          origin_y: 0,
          viewport_width: 320,
          viewport_height: 720,
        }),
        () => {},
      );
      ffi.render_canvas(
        JSON.stringify({ avatars: [] }),
        JSON.stringify({
          origin_x: 0,
          origin_y: 0,
          viewport_width: 320,
          viewport_height: 720,
        }),
        () => {},
      );
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(1);
    await page.evaluate(() => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      probe.hold = false;
      probe.flush(10_100);
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
  });

  test("cancels a queued frame and ignores its late callback after disposal", async ({ page }) => {
    await prepareDirectFfi(page);
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(1);
    const before = await rafMetrics(page);
    await page.evaluate(async () => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: {
          images: Array<{
            onload: (() => void) | null;
            onerror: (() => void) | null;
          }>;
          invokeCanceled: (timestamp: number) => void;
        };
      }).__canvasRafProbe;
      const lateCallbacks = probe.images.map((image) => ({
        onload: image.onload,
        onerror: image.onerror,
      }));
      const ffi = await import("/__canvas_ffi_test__.mjs");
      ffi.dispose_canvas();
      probe.invokeCanceled(10_000);
      for (const callbacks of lateCallbacks) {
        callbacks.onload?.();
        callbacks.onerror?.();
      }
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
    await expect.poll(async () => (await rafMetrics(page)).canceled).toBeGreaterThan(0);
    const after = await rafMetrics(page);
    expect(after.clears).toBe(before.clears);
    expect(after.requested).toBe(before.requested);
    expect(after.pending).toBe(0);
  });

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

  test.describe("visual baselines", () => {
    test.use({
      viewport: { width: 320, height: 720 },
      deviceScaleFactor: 1,
    });

    test("captures the joined office at 320px", async ({ page }) => {
      const assertNoBrowserErrors = observeBrowserErrors(page);
      const assetLoads = observeAssetLoads(page);
      await installDeterminism(page);
      await joinOffice(page, false, peerId, "Lin");

      await expect(
        page.getByRole("region", { name: "Participants" }).getByText("2 participants", {
          exact: true,
        }),
      ).toBeVisible();
      await expect.poll(() => assetLoads.tiles).toBe(1);
      await expect.poll(() => assetLoads.avatars).toBe(1);
      await expect.poll(async () => (await canvasInk(page)).colors).toBeGreaterThan(8);
      await expect(page.locator("#canvas-status")).toHaveText("");
      await expect(page.locator(".canvas-placeholder")).toHaveScreenshot(
        "office-joined-320.png",
        { animations: "disabled", caret: "hide" },
      );
      assertNoBrowserErrors();
    });

    test("captures a readable desktop crowd of 50 avatars", async ({ page }) => {
      const assertNoBrowserErrors = observeBrowserErrors(page);
      const assetLoads = observeAssetLoads(page);
      await installDeterminism(page);
      await page.setViewportSize({ width: 1280, height: 800 });
      const socket = await joinOffice(page, false, peerId, "Lin", selfId, false);

      for (let index = 0; index < 49; index += 1) {
        const suffix = String(index).padStart(2, "0");
        socket.send(
          JSON.stringify({
            type: "user_joined",
            room_id: "default",
            user: {
              connection_id: `crowd-${suffix}`,
              username: `Visitor ${suffix}`,
            },
          }),
        );
      }
      const participants = page.getByRole("region", { name: "Participants" });
      await expect(participants.getByText("50 participants", { exact: true })).toBeVisible();
      await expect(participants.getByRole("listitem")).toHaveCount(50);
      await expect.poll(() => assetLoads.tiles).toBe(1);
      await expect.poll(() => assetLoads.avatars).toBe(1);
      await expect.poll(async () => (await canvasInk(page)).colors).toBeGreaterThan(8);
      await expect(page.locator("#canvas-status")).toHaveText("");
      await expect(page.locator(".canvas-placeholder")).toHaveScreenshot(
        "office-crowded-desktop.png",
        { animations: "disabled", caret: "hide" },
      );
      assertNoBrowserErrors();
    });

    test("captures useful fallback geometry when art fails", async ({ page }) => {
      const assertNoBrowserErrors = observeBrowserErrors(page);
      const assetLoads = observeAssetLoads(page);
      await installDeterminism(page);
      await joinOffice(page, true, peerId, "Lin");

      await expect(
        page.getByRole("region", { name: "Participants" }).getByText("2 participants", {
          exact: true,
        }),
      ).toBeVisible();
      await expect(page.locator("#canvas-status")).toHaveText(
        "Office art unavailable; showing fallback geometry.",
      );
      await expect.poll(() => assetLoads.tiles).toBe(1);
      await expect.poll(() => assetLoads.avatars).toBe(1);
      await expect.poll(async () => (await canvasInk(page)).opaque).toBeGreaterThan(500);
      await expect(page.locator(".canvas-placeholder")).toHaveScreenshot(
        "office-fallback-320.png",
        { animations: "disabled", caret: "hide" },
      );
      assertNoBrowserErrors();
    });
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
