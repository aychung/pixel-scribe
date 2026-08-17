import { expect, test, type Page, type WebSocketRoute } from "@playwright/test";

const fixedTime = new Date("2026-08-16T12:00:00Z");
const fixedSeed = 2147483648;
const selfId = "connection-self";
// Keep the lifecycle fixture's peer visibly separated from self. The renderer
// correctly omits bubbles for owners outside the camera crop, so this test must
// exercise visible owners; dedicated scene tests cover offscreen ownership.
const peerId = "edge-50";
const multilineText = "line one\nline two\nline three";

test.use({ deviceScaleFactor: 1 });

type Session = {
  socket: WebSocketRoute;
  clientFrames: string[];
};

type BubbleRect = {
  left: number;
  top: number;
  width: number;
  height: number;
  area: number;
};

function roomState(messages: object[] = []) {
  return JSON.stringify({
    type: "room_state",
    room_id: "default",
    self_id: selfId,
    users: [
      { connection_id: selfId, username: "Ada" },
      { connection_id: peerId, username: "Ada" },
    ],
    messages,
  });
}

function messageFrame(
  messageId: string,
  senderId: string,
  text: string,
  username = "Ada",
) {
  return JSON.stringify({
    type: "message_sent",
    room_id: "default",
    message: {
      message_id: messageId,
      sender_id: senderId,
      username,
      text,
      sent_at: "2026-08-16T12:00:00Z",
    },
  });
}

function historyMessage(messageId: string, text: string) {
  return {
    message_id: messageId,
    sender_id: peerId,
    username: "Ada",
    text,
    sent_at: "2026-08-16T11:59:00Z",
  };
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
  await page.clock.install({ time: fixedTime });
}

async function joinOffice(
  page: Page,
  initialMessages: object[] = [],
): Promise<Session> {
  const clientFrames: string[] = [];
  let routedSocket: WebSocketRoute | undefined;

  await page.routeWebSocket("/ws", (socket) => {
    routedSocket = socket;
    socket.onMessage((message) => {
      clientFrames.push(
        typeof message === "string" ? message : message.toString(),
      );
    });
  });

  await page.setViewportSize({ width: 1440, height: 900 });
  await installDeterminism(page);
  await page.goto("/");

  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect.poll(() => clientFrames).toEqual([
    '{"type":"join_room","room_id":"default","username":"Ada"}',
  ]);

  if (routedSocket === undefined) throw new Error("WebSocket route was not opened");
  routedSocket.send(roomState(initialMessages));
  await expect(page.getByRole("status")).toHaveText(
    "Joined the default office.",
  );
  await expect
    .poll(() =>
      page.locator("#office-canvas").evaluate((element) => {
        const canvas = element as HTMLCanvasElement;
        return { width: canvas.width, height: canvas.height };
      }),
    )
    .toEqual({ width: expect.any(Number), height: expect.any(Number) });
  return { socket: routedSocket, clientFrames };
}

async function pauseAtCurrentTime(page: Page) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const now = await page.evaluate(() => Date.now());
    try {
      await page.clock.pauseAt(new Date(now));
      return await page.evaluate(() => Date.now());
    } catch (error) {
      if (!String(error).includes("Cannot fast-forward to the past")) {
        throw error;
      }
    }
  }
  throw new Error("Could not pause the browser clock at its current time");
}

async function messageText(page: Page) {
  return page.locator("#chat-log .message-text").evaluateAll((elements) =>
    elements.map((element) => (element as HTMLElement).innerText),
  );
}

async function bubbleRects(page: Page): Promise<BubbleRect[]> {
  return page.locator("#office-canvas").evaluate((element) => {
    const canvas = element as HTMLCanvasElement;
    const context = canvas.getContext("2d");
    if (context === null) throw new Error("Canvas 2D context unavailable");

    const { width, height } = canvas;
    const pixels = context.getImageData(0, 0, width, height).data;
    const matching = new Uint8Array(width * height);
    for (let index = 0; index < width * height; index += 1) {
      const pixel = index * 4;
      if (
        pixels[pixel] === 242 &&
        pixels[pixel + 1] === 234 &&
        pixels[pixel + 2] === 216 &&
        pixels[pixel + 3] === 255
      ) {
        matching[index] = 1;
      }
    }

    const visited = new Uint8Array(width * height);
    const rectangles: BubbleRect[] = [];
    for (let start = 0; start < matching.length; start += 1) {
      if (matching[start] === 0 || visited[start] !== 0) continue;
      const stack = [start];
      visited[start] = 1;
      let area = 0;
      let left = width;
      let top = height;
      let right = -1;
      let bottom = -1;
      while (stack.length > 0) {
        const current = stack.pop() as number;
        const x = current % width;
        const y = Math.floor(current / width);
        area += 1;
        left = Math.min(left, x);
        top = Math.min(top, y);
        right = Math.max(right, x);
        bottom = Math.max(bottom, y);
        for (const neighbor of [current - 1, current + 1, current - width, current + width]) {
          if (neighbor < 0 || neighbor >= matching.length || visited[neighbor] !== 0) {
            continue;
          }
          const neighborX = neighbor % width;
          if (Math.abs(neighborX - x) > 1 || matching[neighbor] === 0) continue;
          visited[neighbor] = 1;
          stack.push(neighbor);
        }
      }
      const rectangleWidth = right - left + 1;
      const rectangleHeight = bottom - top + 1;
      if (area >= 400 && rectangleWidth >= 40 && rectangleHeight >= 10) {
        rectangles.push({
          left,
          top,
          width: rectangleWidth,
          height: rectangleHeight,
          area,
        });
      }
    }
    return rectangles.sort((first, second) => second.area - first.area);
  });
}

async function bubblePixel(page: Page, rectangle: BubbleRect) {
  return page.locator("#office-canvas").evaluate(
    (element, point) => {
      const canvas = element as HTMLCanvasElement;
      const context = canvas.getContext("2d");
      if (context === null) throw new Error("Canvas 2D context unavailable");
      const pixel = context.getImageData(point.x, point.y, 1, 1).data;
      return [pixel[0], pixel[1], pixel[2], pixel[3]];
    },
    { x: rectangle.left + 4, y: rectangle.top + 4 },
  );
}

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

test.describe("temporary speech bubbles", () => {
  test("renders one accepted multiline message in the DOM and peer-owned canvas bubble through fade", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const session = await joinOffice(page);
    const liveFrame = messageFrame("live-peer", peerId, multilineText);

    const liveSentAt = await page.evaluate(() => Date.now());
    session.socket.send(liveFrame);
    await expect(page.locator("#chat-log .chat-message")).toHaveCount(1);
    await expect.poll(() => messageText(page)).toEqual([multilineText]);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);
    const beforeFade = (await bubbleRects(page))[0];
    const opaque = await bubblePixel(page, beforeFade);
    expect(opaque).toEqual([242, 234, 216, 255]);
    const canvas = page.locator("#office-canvas");

    // The same accepted event is idempotent at both semantic boundaries.
    session.socket.send(liveFrame);
    await expect(page.locator("#chat-log .chat-message")).toHaveCount(1);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);

    const pausedAt = await pauseAtCurrentTime(page);
    const beforeCanvas = await canvas.screenshot();
    await expect(canvas).toHaveScreenshot("bubble-before.png");

    const fadeTarget = liveSentAt + 5_500;
    expect(fadeTarget).toBeGreaterThan(pausedAt);
    await page.clock.runFor(fadeTarget - pausedAt);
    const fading = await bubblePixel(page, beforeFade);
    expect(fading).not.toEqual(opaque);
    expect(fading[3]).toBe(255);
    const duringCanvas = await canvas.screenshot();
    expect(duringCanvas.equals(beforeCanvas)).toBe(false);
    await expect(canvas).toHaveScreenshot("bubble-during.png");

    await page.clock.runFor(1_000);
    await expect.poll(() => bubbleRects(page)).toHaveLength(0);
    const afterCanvas = await canvas.screenshot();
    expect(afterCanvas.equals(duringCanvas)).toBe(false);
    expect(afterCanvas.equals(beforeCanvas)).toBe(false);
    await expect(canvas).toHaveScreenshot("bubble-after.png");
    await expect.poll(() => messageText(page)).toEqual([multilineText]);
    assertNoBrowserErrors();
  });

  test("replaces by sender ID and clears the sender bubble on leave", async ({
    page,
  }) => {
    const session = await joinOffice(page);
    session.socket.send(messageFrame("peer-old", peerId, "old bubble"));
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);
    const oldBubble = (await bubbleRects(page))[0];

    await page.clock.fastForward(1_000);
    session.socket.send(messageFrame("peer-new", peerId, "new bubble"));
    await expect(page.locator("#chat-log .chat-message")).toHaveCount(2);
    await expect.poll(() => messageText(page)).toEqual(["old bubble", "new bubble"]);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);
    const replacement = (await bubbleRects(page))[0];
    expect(replacement.left).toBe(oldBubble.left);
    expect(replacement.top).toBe(oldBubble.top);
    expect(replacement.width).toBe(oldBubble.width);
    // At t=5s the old timer fires, but the replacement (started at t=1s)
    // remains fully visible. This proves stale timer identity is invalidated.
    await page.clock.fastForward(4_000);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);

    // The duplicate usernames do not share a visual owner: the self sender's
    // accepted event adds a second bubble at the other avatar's anchor.
    session.socket.send(messageFrame("self-live", selfId, "self bubble"));
    await expect.poll(() => bubbleRects(page)).toHaveLength(2);
    const owners = (await bubbleRects(page)).map((bubble) => bubble.left);
    expect(owners).toContain(replacement.left);
    expect(owners.some((left) => left !== replacement.left)).toBe(true);

    session.socket.send(
      JSON.stringify({
        type: "user_left",
        room_id: "default",
        connection_id: peerId,
      }),
    );
    await expect(
      page
        .getByRole("region", { name: "Participants" })
        .getByRole("list")
        .locator("li"),
    ).toHaveCount(1);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);
    await expect.poll(() => messageText(page)).toEqual([
      "old bubble",
      "new bubble",
      "self bubble",
    ]);
  });

  test("does not replay snapshot history and reduced motion stays opaque until expiry", async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    const session = await joinOffice(page, [
      historyMessage("history-only", "old\nmultiline\nhistory"),
    ]);
    expect(
      await page.evaluate(() =>
        window.matchMedia("(prefers-reduced-motion: reduce)").matches,
      ),
    ).toBe(true);

    await expect(page.locator("#chat-log .chat-message")).toHaveCount(1);
    await expect.poll(() => messageText(page)).toEqual(["old\nmultiline\nhistory"]);
    await expect.poll(() => bubbleRects(page)).toHaveLength(0);

    session.socket.send(messageFrame("reduced-live", peerId, multilineText));
    await expect(page.locator("#chat-log .chat-message")).toHaveCount(2);
    await expect.poll(() => messageText(page)).toEqual([
      "old\nmultiline\nhistory",
      multilineText,
    ]);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);
    const bubble = (await bubbleRects(page))[0];
    const opaque = await bubblePixel(page, bubble);

    await page.clock.fastForward(5_500);
    await expect.poll(() => bubbleRects(page)).toHaveLength(1);
    expect(await bubblePixel(page, bubble)).toEqual(opaque);

    await page.clock.fastForward(500);
    await expect.poll(() => bubbleRects(page)).toHaveLength(0);
    await expect(page.locator("#chat-log .chat-message")).toHaveCount(2);
  });
});
