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
  const loads = {
    tiles: 0,
    cupboard: 0,
    kitchen: 0,
    miscellaneous: 0,
    flowers: 0,
    carpet: 0,
    windows: 0,
    paintings: 0,
    characterModel: 0,
    characterHair: 0,
    characterOutfit: 0,
  };
  page.on("requestfinished", (request) => {
    const path = decodeURIComponent(new URL(request.url()).pathname);
    if (path.endsWith("/Interior/Home/TilesHouse.png")) loads.tiles += 1;
    if (path.endsWith("/Interior/Home/Cupboard-Sheet.png")) loads.cupboard += 1;
    if (path.endsWith("/Interior/Home/Kitchen-Sheet.png")) loads.kitchen += 1;
    if (path.endsWith("/Interior/Home/Miscellaneous-Sheet.png")) loads.miscellaneous += 1;
    if (path.endsWith("/Interior/Home/Flowers-Sheet.png")) loads.flowers += 1;
    if (path.endsWith("/Interior/Home/Carpet-Sheet.png")) loads.carpet += 1;
    if (path.endsWith("/Interior/Home/Windows-Sheet.png")) loads.windows += 1;
    if (path.endsWith("/Interior/Home/Paintings-Sheet.png")) loads.paintings += 1;
    if (path.endsWith("/Character/CharacterModel/Character Model.png")) {
      loads.characterModel += 1;
    }
    if (path.endsWith("/Character/Hair/Hairs.png")) loads.characterHair += 1;
    if (path.endsWith("/Character/Outfits/Suit.png")) loads.characterOutfit += 1;
  });
  return loads;
}

async function expectMetrocityAssetLoads(loads: ReturnType<typeof observeAssetLoads>) {
  for (const name of Object.keys(loads) as Array<keyof typeof loads>) {
    await expect.poll(() => loads[name]).toBe(1);
  }
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
      saves: 0,
      restores: 0,
      throwOnClip: false,
      avatarSourceXs: [] as number[],
      avatarSourceYs: [] as number[],
      characterLayerOrder: [] as string[],
      characterLayerSources: {
        "character-model": [] as Array<[number, number, number, number]>,
        "character-outfit": [] as Array<[number, number, number, number]>,
        "character-hair": [] as Array<[number, number, number, number]>,
      },
      tileSourceRects: [] as Array<[number, number, number, number]>,
      textDraws: [] as Array<{ text: string; maxWidth?: number }>,
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
    const nativeSave = contextPrototype.save;
    const nativeRestore = contextPrototype.restore;
    const nativeClip = contextPrototype.clip;
    const nativeDrawImage = contextPrototype.drawImage;
    const nativeFillText = contextPrototype.fillText;
    Object.defineProperty(contextPrototype, "clearRect", {
      configurable: true,
      value(this: CanvasRenderingContext2D, ...arguments_: Parameters<typeof nativeClearRect>) {
        probe.clears += 1;
        return nativeClearRect.apply(this, arguments_);
      },
    });
    Object.defineProperty(contextPrototype, "save", {
      configurable: true,
      value(this: CanvasRenderingContext2D) {
        probe.saves += 1;
        return nativeSave.call(this);
      },
    });
    Object.defineProperty(contextPrototype, "restore", {
      configurable: true,
      value(this: CanvasRenderingContext2D) {
        probe.restores += 1;
        return nativeRestore.call(this);
      },
    });
    Object.defineProperty(contextPrototype, "clip", {
      configurable: true,
      value(this: CanvasRenderingContext2D) {
        if (probe.throwOnClip) throw new Error("synthetic clip failure");
        return nativeClip.call(this);
      },
    });
    Object.defineProperty(contextPrototype, "drawImage", {
      configurable: true,
      value(this: CanvasRenderingContext2D, ...arguments_: unknown[]) {
        const image = arguments_[0] as { kind?: string } | undefined;
        const imageKind = image?.kind;
        if (imageKind === "character-model") {
          probe.avatarSourceXs.push(arguments_[1] as number);
          probe.avatarSourceYs.push(arguments_[2] as number);
        }
        if (
          imageKind === "character-model" ||
          imageKind === "character-outfit" ||
          imageKind === "character-hair"
        ) {
          probe.characterLayerOrder.push(imageKind);
          probe.characterLayerSources[imageKind].push([
            arguments_[1] as number,
            arguments_[2] as number,
            arguments_[3] as number,
            arguments_[4] as number,
          ]);
        }
        if (
          image?.kind === "tiles" ||
          image?.kind === "character-model" ||
          image?.kind === "character-hair" ||
          image?.kind === "character-outfit" ||
          image?.kind === "other"
        ) {
          if (image.kind === "tiles") {
            probe.tileSourceRects.push([
              arguments_[1] as number,
              arguments_[2] as number,
              arguments_[3] as number,
              arguments_[4] as number,
            ]);
          }
          return;
        }
        return nativeDrawImage.apply(
          this,
          arguments_ as Parameters<typeof nativeDrawImage>,
        );
      },
    });
    Object.defineProperty(contextPrototype, "fillText", {
      configurable: true,
      value(this: CanvasRenderingContext2D, ...arguments_: unknown[]) {
        probe.textDraws.push({
          text: arguments_[0] as string,
          maxWidth: arguments_[3] as number | undefined,
        });
        return nativeFillText.apply(
          this,
          arguments_ as Parameters<typeof nativeFillText>,
        );
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

async function renderDirectScene(page: Page, scene: unknown, camera: unknown) {
  await page.evaluate(async ({ scene, camera }) => {
    const probe = (globalThis as typeof globalThis & {
      __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
    }).__canvasRafProbe;
    const ffi = await import("/__canvas_ffi_test__.mjs");
    probe.hold = true;
    ffi.render_canvas(JSON.stringify(scene), JSON.stringify(camera), () => {});
    probe.hold = false;
    probe.flush(16);
  }, { scene, camera });
  await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
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
    await page.route("**/pixel-art/metrocity/**", async (route) => {
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

async function canvasColorCounts(page: Page) {
  return page.locator("#office-canvas").evaluate((element) => {
    const canvas = element as HTMLCanvasElement;
    const context = canvas.getContext("2d");
    if (context === null) throw new Error("Canvas 2D context unavailable");
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const counts: Record<string, number> = {};
    for (let index = 0; index < pixels.length; index += 4) {
      const key = `${pixels[index]},${pixels[index + 1]},${pixels[index + 2]}`;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  });
}

test.describe("canvas FFI boundaries", () => {
  test("uses the CSS content box for null-entry resize and live DPR measurements", async ({
    page,
  }) => {
    await installFfiModule(page);
    await page.addInitScript(() => {
      class NoopResizeObserver {
        constructor(_callback: ResizeObserverCallback) {}
        observe(_target: Element, _options?: ResizeObserverOptions) {}
        disconnect() {}
      }
      Object.defineProperty(globalThis, "ResizeObserver", {
        configurable: true,
        value: NoopResizeObserver,
      });
      const nativeMatchMedia = window.matchMedia.bind(window);
      const mediaLists: MediaQueryList[] = [];
      Object.defineProperty(globalThis, "__canvasMediaLists", {
        configurable: true,
        value: mediaLists,
      });
      Object.defineProperty(window, "matchMedia", {
        configurable: true,
        value: (query: string) => {
          const media = nativeMatchMedia(query);
          mediaLists.push(media);
          return media;
        },
      });
    });
    await page.goto("/");
    await page.evaluate(() => {
      document.body.innerHTML =
        '<canvas id="office-canvas" style="display:block;box-sizing:border-box;width:320px;height:200px;padding:3px 4px 5px 6px;border-style:solid;border-width:1px 2px 3px 4px"></canvas>';
    });
    const dimensions = await page.evaluate(async () => {
      const events: Array<[number, number, number]> = [];
      Object.defineProperty(globalThis, "__canvasSizeEvents", {
        configurable: true,
        value: events,
      });
      const ffi = await import("/__canvas_ffi_test__.mjs");
      ffi.initialize_canvas(
        (width, height, dpr) => events.push([width, height, dpr]),
        (width, height, dpr) => events.push([width, height, dpr]),
        () => {},
      );
      return { events, dpr: window.devicePixelRatio };
    });
    const dpr = dimensions.dpr;
    expect(dimensions.events[0]).toEqual([304, 188, dpr]);

    await page.evaluate(() => {
      const canvas = document.getElementById("office-canvas") as HTMLCanvasElement;
      canvas.style.width = "300px";
      canvas.style.height = "180px";
      window.dispatchEvent(new Event("resize"));
    });
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasSizeEvents: Array<[number, number, number]>;
      }).__canvasSizeEvents))
      .toContainEqual([284, 168, dpr]);

    await page.evaluate(() => {
      const canvas = document.getElementById("office-canvas") as HTMLCanvasElement;
      canvas.style.width = "280px";
      canvas.style.height = "160px";
      const lists = (globalThis as typeof globalThis & {
        __canvasMediaLists: MediaQueryList[];
      }).__canvasMediaLists;
      lists[lists.length - 1].dispatchEvent(new Event("change"));
    });
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasSizeEvents: Array<[number, number, number]>;
      }).__canvasSizeEvents))
      .toContainEqual([264, 148, dpr]);
  });

  test("balances fallback context state after success and injected drawing failure", async ({
    page,
  }) => {
    await prepareDirectFfi(page);
    await renderDirectScene(page, {
      avatars: [{ id: "self", username: "Ada", x: 160, y: 120, variant: 0, self: true, status: "online" }],
    }, { origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 });
    let counts = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasRafProbe: { saves: number; restores: number; throwOnClip: boolean };
    }).__canvasRafProbe);
    expect(counts.saves).toBe(counts.restores);

    await page.evaluate(async () => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { throwOnClip: boolean };
      }).__canvasRafProbe;
      probe.throwOnClip = true;
    });
    await renderDirectScene(page, { avatars: [] }, {
      origin_x: 0,
      origin_y: 0,
      viewport_width: 320,
      viewport_height: 240,
    });
    counts = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasRafProbe: { saves: number; restores: number; throwOnClip: boolean };
    }).__canvasRafProbe);
    expect(counts.saves).toBe(counts.restores);
  });

  test("draws fallback office geometry in addition to the backdrop and avatars", async ({
    page,
  }) => {
    await prepareDirectFfi(page);
    await renderDirectScene(page, {
      avatars: [
        { id: "self", username: "Ada", x: 96, y: 112, variant: 0, self: true, status: "online" },
        { id: "peer", username: "Lin", x: 256, y: 208, variant: 1, self: false, status: "online" },
      ],
    }, { origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 });
    const colors = await canvasColorCounts(page);
    expect(colors["47,76,77"] ?? 0).toBeGreaterThan(100);
    expect(colors["111,135,144"] ?? 0).toBeGreaterThan(100);
    expect(colors["139,94,74"] ?? 0).toBeGreaterThan(100);
    expect(colors["243,211,106"] ?? 0).toBeGreaterThan(0);
    expect(colors["114,183,161"] ?? 0).toBeGreaterThan(0);
  });

  test("draws equal-depth avatars in the already-sorted input order", async ({ page }) => {
    await installRafProbe(page);
    await installFfiModule(page);
    await page.goto("/");
    await page.evaluate(() => {
      document.body.innerHTML =
        '<canvas id="office-canvas" style="display:block;width:320px;height:240px"></canvas>';
    });
    await page.evaluate(async () => {
      class FakeImage {
        kind = "";
        onload: (() => void) | null = null;
        onerror: (() => void) | null = null;
        set src(url: string) {
          const path = decodeURIComponent(url);
          this.kind = path.includes("TilesHouse")
            ? "tiles"
            : path.includes("Character Model")
              ? "character-model"
              : path.includes("/Hairs.png")
                ? "character-hair"
                : path.includes("/Suit.png")
                  ? "character-outfit"
                  : "other";
          this.onload?.();
        }
      }
      Object.defineProperty(globalThis, "Image", { configurable: true, value: FakeImage });
      const ffi = await import("/__canvas_ffi_test__.mjs");
      ffi.initialize_canvas(() => {}, () => {}, () => {});
      ffi.render_canvas(
        JSON.stringify({
          avatars: [
            { id: "z", username: "Zed", x: 160, y: 120, variant: 0, self: false, status: "online" },
            { id: "ä", username: "Ada", x: 160, y: 120, variant: 1, self: false, status: "online" },
          ],
        }),
        JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 }),
        () => {},
      );
    });
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasRafProbe: { avatarSourceXs: number[] };
      }).__canvasRafProbe.avatarSourceXs))
      .toEqual([0, 0]);
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasRafProbe: { avatarSourceYs: number[] };
      }).__canvasRafProbe.avatarSourceYs))
      .toEqual([0, 32]);
  });

  test("samples avatar variants from every atlas row", async ({ page }) => {
    await installRafProbe(page);
    await installFfiModule(page);
    await page.goto("/");
    await page.evaluate(() => {
      document.body.innerHTML =
        '<canvas id="office-canvas" style="display:block;width:320px;height:240px"></canvas>';
    });
    await page.evaluate(async () => {
      class FakeImage {
        kind = "";
        onload: (() => void) | null = null;
        onerror: (() => void) | null = null;
        set src(url: string) {
          const path = decodeURIComponent(url);
          this.kind = path.includes("TilesHouse")
            ? "tiles"
            : path.includes("Character Model")
              ? "character-model"
              : path.includes("/Hairs.png")
                ? "character-hair"
                : path.includes("/Suit.png")
                  ? "character-outfit"
                  : "other";
          this.onload?.();
        }
      }
      Object.defineProperty(globalThis, "Image", { configurable: true, value: FakeImage });
      const ffi = await import("/__canvas_ffi_test__.mjs");
      ffi.initialize_canvas(() => {}, () => {}, () => {});
      ffi.render_canvas(
        JSON.stringify({
          avatars: [{ id: "self", username: "Ada", x: 160, y: 120, variant: 31, self: true, status: "online" }],
        }),
        JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 }),
        () => {},
      );
    });
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasRafProbe: { avatarSourceXs: number[]; avatarSourceYs: number[] };
      }).__canvasRafProbe.avatarSourceXs))
      .toEqual([0]);
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasRafProbe: { avatarSourceYs: number[] };
      }).__canvasRafProbe.avatarSourceYs))
      .toEqual([32]);
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasRafProbe: {
          characterLayerOrder: string[];
          characterLayerSources: Record<string, Array<[number, number, number, number]>>;
        };
      }).__canvasRafProbe.characterLayerOrder))
      .toEqual(["character-model", "character-outfit", "character-hair"]);
    const characterSources = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasRafProbe: {
        characterLayerSources: Record<string, Array<[number, number, number, number]>>;
      };
    }).__canvasRafProbe.characterLayerSources);
    expect(characterSources["character-model"]).toEqual([[0, 32, 32, 32]]);
    expect(characterSources["character-outfit"]).toEqual([[0, 96, 32, 32]]);
    expect(characterSources["character-hair"]).toEqual([[0, 224, 32, 32]]);
  });

  test("samples Metrocity wall crops from the tile atlas", async ({ page }) => {
    await installRafProbe(page);
    await installFfiModule(page);
    await page.goto("/");
    await page.evaluate(() => {
      document.body.innerHTML =
        '<canvas id="office-canvas" style="display:block;width:320px;height:240px"></canvas>';
    });
    await page.evaluate(async () => {
      class FakeImage {
        kind = "";
        onload: (() => void) | null = null;
        onerror: (() => void) | null = null;
        set src(url: string) {
          const path = decodeURIComponent(url);
          this.kind = path.includes("TilesHouse")
            ? "tiles"
            : path.includes("Character Model")
              ? "character-model"
              : path.includes("/Hairs.png")
                ? "character-hair"
                : path.includes("/Suit.png")
                  ? "character-outfit"
                  : "other";
          this.onload?.();
        }
      }
      Object.defineProperty(globalThis, "Image", { configurable: true, value: FakeImage });
      const ffi = await import("/__canvas_ffi_test__.mjs");
      ffi.initialize_canvas(() => {}, () => {}, () => {});
      ffi.render_canvas(
        JSON.stringify({ avatars: [] }),
        JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 }),
        () => {},
      );
    });
    await expect
      .poll(() => page.evaluate(() => (globalThis as typeof globalThis & {
        __canvasRafProbe: { tileSourceRects: Array<[number, number, number, number]> };
      }).__canvasRafProbe.tileSourceRects))
      .toContainEqual([0, 64, 16, 16]);
    const floorSources = await page.evaluate(() => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { tileSourceRects: Array<[number, number, number, number]> };
      }).__canvasRafProbe;
      return probe.tileSourceRects.filter(([sourceX, sourceY]) =>
        sourceX === 0 && sourceY === 64
      );
    });
    expect(floorSources.length).toBeGreaterThan(0);
    expect(new Set(floorSources.map((rect) => rect.join(",")))).toEqual(new Set([
      "0,64,16,16",
    ]));
  });

  test("rejects unsorted avatar input and reports no avatar draw", async ({ page }) => {
    await prepareDirectFfi(page);
    await page.evaluate(async () => {
      const errors: number[] = [];
      Object.defineProperty(globalThis, "__canvasSceneErrors", {
        configurable: true,
        value: errors,
      });
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      const ffi = await import("/__canvas_ffi_test__.mjs");
      probe.hold = true;
      ffi.render_canvas(JSON.stringify({ avatars: [
        { id: "ä", username: "Ada", x: 160, y: 120, variant: 1, self: false, status: "online" },
        { id: "z", username: "Zed", x: 160, y: 120, variant: 0, self: false, status: "online" },
      ] }), JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 }),
      (code) => errors.push(code));
      probe.hold = false;
      probe.flush(32);
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
    const errors = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasSceneErrors: number[];
    }).__canvasSceneErrors);
    expect(errors).toEqual([6]);
    const colors = await canvasColorCounts(page);
    expect(colors["114,183,161"] ?? 0).toBe(0);
  });

  test("rejects oversized bubble geometry and settles without an animation loop", async ({ page }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    await prepareDirectFfi(page);
    await page.evaluate(async () => {
      const errors: number[] = [];
      Object.defineProperty(globalThis, "__canvasSceneErrors", {
        configurable: true,
        value: errors,
      });
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      const ffi = await import("/__canvas_ffi_test__.mjs");
      probe.hold = true;
      const startedAt = Date.now() - 5_500;
      ffi.render_canvas(JSON.stringify({
        avatars: [
          { id: "sender", username: "Ada", x: 160, y: 120, variant: 0, self: false, status: "online" },
        ],
        bubbles: [{
          id: "fading",
          sender_id: "sender",
          lines: ["fading"],
          left: 0,
          top: 0,
          width: 48,
          height: 20,
          started_at_ms: startedAt,
          expires_at_ms: startedAt + 6_000,
        }],
      }), JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 720 }), () => {});
      ffi.render_canvas(JSON.stringify({
        avatars: [
          { id: "sender", username: "Ada", x: 160, y: 120, variant: 0, self: false, status: "online" },
        ],
        bubbles: [{
          id: "bubble",
          sender_id: "sender",
          lines: ["hello"],
          left: 0,
          top: 0,
          width: 161,
          height: 20,
          started_at_ms: 10_000,
          expires_at_ms: 16_000,
        }],
      }), JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 720 }),
      (code) => errors.push(code));
      probe.hold = false;
      probe.flush(32);
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
    const errors = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasSceneErrors: number[];
    }).__canvasSceneErrors);
    expect(errors).toEqual([6]);
    const before = await rafMetrics(page);
    await page.waitForTimeout(50);
    const after = await rafMetrics(page);
    expect(after.pending).toBe(0);
    expect(after.requested).toBe(before.requested);
    assertNoBrowserErrors();
  });

  test("enforces the bubble interior width for wide graphemes", async ({ page }) => {
    await prepareDirectFfi(page);
    await page.evaluate(async () => {
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      const ffi = await import("/__canvas_ffi_test__.mjs");
      probe.hold = true;
      const startedAt = Date.now();
      ffi.render_canvas(JSON.stringify({
        avatars: [
          { id: "sender", username: "Ada", x: 160, y: 120, variant: 0, self: false, status: "online" },
        ],
        bubbles: [{
          id: "wide-emoji",
          sender_id: "sender",
          lines: ["🙂".repeat(18)],
          left: 0,
          top: 0,
          width: 160,
          height: 20,
          started_at_ms: startedAt,
          expires_at_ms: startedAt + 6_000,
        }],
      }), JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 240 }), () => {});
      probe.hold = false;
      probe.flush(32);
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
    const textDraws = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasRafProbe: { textDraws: Array<{ text: string; maxWidth?: number }> };
    }).__canvasRafProbe.textDraws);
    const bubbleText = textDraws.find(({ text }) => text === "🙂".repeat(18));
    expect(bubbleText).toEqual({ text: "🙂".repeat(18), maxWidth: 144 });
  });

  test("rejects noncanonical bubble lifetime and settles without an animation loop", async ({ page }) => {
    await prepareDirectFfi(page);
    await page.evaluate(async () => {
      const errors: number[] = [];
      Object.defineProperty(globalThis, "__canvasSceneErrors", {
        configurable: true,
        value: errors,
      });
      const probe = (globalThis as typeof globalThis & {
        __canvasRafProbe: { hold: boolean; flush: (timestamp: number) => void };
      }).__canvasRafProbe;
      const ffi = await import("/__canvas_ffi_test__.mjs");
      probe.hold = true;
      ffi.render_canvas(JSON.stringify({
        avatars: [
          { id: "sender", username: "Ada", x: 160, y: 120, variant: 0, self: false, status: "online" },
        ],
        bubbles: [{
          id: "bubble",
          sender_id: "sender",
          lines: ["hello"],
          left: 0,
          top: 0,
          width: 40,
          height: 20,
          started_at_ms: 10_000,
          expires_at_ms: 16_001,
        }],
      }), JSON.stringify({ origin_x: 0, origin_y: 0, viewport_width: 320, viewport_height: 720 }),
      (code) => errors.push(code));
      probe.hold = false;
      probe.flush(32);
    });
    await expect.poll(async () => (await rafMetrics(page)).pending).toBe(0);
    const errors = await page.evaluate(() => (globalThis as typeof globalThis & {
      __canvasSceneErrors: number[];
    }).__canvasSceneErrors);
    expect(errors).toEqual([6]);
    const before = await rafMetrics(page);
    await page.waitForTimeout(50);
    const after = await rafMetrics(page);
    expect(after.pending).toBe(0);
    expect(after.requested).toBe(before.requested);
  });
});

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

    await expectMetrocityAssetLoads(assetLoads);
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
    await expectMetrocityAssetLoads(assetLoads);
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
      await expectMetrocityAssetLoads(assetLoads);
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
      await expectMetrocityAssetLoads(assetLoads);
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
      await expectMetrocityAssetLoads(assetLoads);
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

    test("zooms the office around the self visual center", async ({ page }) => {
      await joinOffice(page, false);
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);
      await expect(page.locator("#office-zoom-value")).toHaveText("200%");

      const before = await canvasMetrics(page);
      await page.getByRole("button", { name: "Zoom in" }).click();
      await expect(page.locator("#office-zoom-value")).toHaveText("300%");
      await expect.poll(async () => (await canvasMetrics(page)).centerGold).toBeGreaterThan(0);

      const zoomed = await canvasMetrics(page);
      expect(Math.abs(zoomed.centerGoldCenter.x - zoomed.cssWidth / 2)).toBeLessThan(1.1);
      expect(Math.abs(zoomed.centerGoldCenter.y - zoomed.cssHeight / 2)).toBeLessThan(1.1);
      expect(zoomed.fingerprint).not.toBe(before.fingerprint);

      await page.getByRole("button", { name: "Reset zoom" }).click();
      await expect(page.locator("#office-zoom-value")).toHaveText("200%");
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
