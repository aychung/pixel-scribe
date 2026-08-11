import { expect, test, type Page, type WebSocketRoute } from "@playwright/test";

type ChatSession = {
  socket: WebSocketRoute;
  clientFrames: string[];
};

const selfId = "connection-self";
const peerId = "connection-peer";

function collectClientFrames(frames: string[]) {
  return (message: string | { toString(): string }) => {
    frames.push(typeof message === "string" ? message : message.toString());
  };
}

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
  username: string,
  text: string,
  sentAt = "2026-08-11T19:00:00Z",
) {
  return JSON.stringify({
    type: "message_sent",
    room_id: "default",
    message: {
      message_id: messageId,
      sender_id: senderId,
      username,
      text,
      sent_at: sentAt,
    },
  });
}

function errorFrame(code: "invalid_message" | "rate_limited", message: string) {
  return JSON.stringify({
    type: "error",
    room_id: "default",
    code,
    message,
    recoverable: true,
  });
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

async function joinChat(
  page: Page,
  initialMessages: object[] = [],
): Promise<ChatSession> {
  const clientFrames: string[] = [];
  let routedSocket: WebSocketRoute | undefined;

  await page.routeWebSocket("/ws", (socket) => {
    routedSocket = socket;
    socket.onMessage(collectClientFrames(clientFrames));
  });
  await page.goto("/");

  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect(page.getByRole("status")).toContainText(
    "Waiting for the office snapshot",
  );
  await expect.poll(() => clientFrames).toEqual([
    '{"type":"join_room","room_id":"default","username":"Ada"}',
  ]);

  if (routedSocket === undefined) throw new Error("WebSocket route was not opened");
  routedSocket.send(roomState(initialMessages));
  await expect(page.getByRole("status")).toHaveText(
    "Joined the default office.",
  );

  return { socket: routedSocket, clientFrames };
}

function sendMessageFrame(text: string) {
  return JSON.stringify({
    type: "send_message",
    room_id: "default",
    text,
  });
}

async function expectAtBottom(page: Page) {
  await expect
    .poll(() =>
      page.locator("#chat-log").evaluate((element) => {
        const log = element as HTMLElement;
        return log.scrollHeight - log.clientHeight - log.scrollTop;
      }),
    )
    .toBeLessThanOrEqual(1);
}

function overflowingMessages() {
  return Array.from({ length: 50 }, (_, index) => ({
    message_id: `history-${index}`,
    sender_id: index % 2 === 0 ? selfId : peerId,
    username: index % 2 === 0 ? "Ada" : "Ada",
    text: `History message ${index}`,
    sent_at: `2026-08-11T18:${String(index).padStart(2, "0")}:00Z`,
  }));
}

test.describe("accepted chat", () => {
  test("sends exact normalized JSON and renders only accepted self and peer events", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 720 });
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const session = await joinChat(page);
    const textarea = page.getByRole("textbox", { name: "Message" });
    const send = page.getByRole("button", { name: "Send message" });
    const log = page.locator("#chat-log");

    await textarea.fill("  hello\nworld  ");
    await send.click();
    await expect.poll(() => session.clientFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
      sendMessageFrame("hello\nworld"),
    ]);
    await expect(log.locator(".chat-message")).toHaveCount(0);
    await expect(textarea).toHaveValue("hello\nworld");

    session.socket.send(
      messageFrame("message-self", selfId, "Ada", "hello\nworld"),
    );
    await expect(log.locator(".chat-message")).toHaveCount(1);
    await expect(log.locator(".message-text br")).toHaveCount(1);
    await expect
      .poll(() =>
        log.locator(".message-text").evaluate((element) =>
          (element as HTMLElement).innerText,
        ),
      )
      .toBe("hello\nworld");
    await expect(log.locator(".message-self")).toHaveText(" (You)");
    await expect(textarea).toHaveValue("");
    await expect(log.locator("time")).toHaveAttribute(
      "datetime",
      "2026-08-11T19:00:00Z",
    );

    const unsafeMultiline = "<img src=x onerror=alert(1)>\nsecond line";
    session.socket.send(
      messageFrame("message-peer", peerId, "Ada", unsafeMultiline),
    );
    await expect(log.locator(".chat-message")).toHaveCount(2);
    await expect(log.locator(".message-text").nth(1).locator("br")).toHaveCount(1);
    await expect
      .poll(() =>
        log.locator(".message-text").nth(1).evaluate((element) =>
          (element as HTMLElement).innerText,
        ),
      )
      .toBe(unsafeMultiline);
    await expect(log.locator(".message-self")).toHaveCount(1);
    await expect(log.locator("script, img, [onerror]")).toHaveCount(0);

    const longUnbrokenText = "L".repeat(500);
    session.socket.send(
      messageFrame("message-long", peerId, "Ada", longUnbrokenText),
    );
    const longMessage = log.locator(".message-text").nth(2);
    await expect(longMessage).toHaveText(longUnbrokenText);
    await expect
      .poll(() =>
        longMessage.evaluate(
          (element) => element.scrollWidth <= element.clientWidth,
        ),
      )
      .toBe(true);

    assertNoBrowserErrors();
  });

  test("does not send Shift+Enter or composing Enter, while plain Enter submits", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const session = await joinChat(page);
    const textarea = page.getByRole("textbox", { name: "Message" });

    await textarea.fill("first line");
    await textarea.press("Shift+Enter");
    await expect(textarea).toHaveValue("first line\n");
    expect(session.clientFrames).toHaveLength(1);

    await textarea.dispatchEvent("keydown", {
      key: "Enter",
      shiftKey: false,
      isComposing: true,
    });
    expect(session.clientFrames).toHaveLength(1);

    await textarea.fill("submitted");
    await textarea.press("Enter");
    await expect.poll(() => session.clientFrames).toHaveLength(2);
    expect(session.clientFrames[1]).toBe(sendMessageFrame("submitted"));

    assertNoBrowserErrors();
  });

  test("keeps invalid controls and valid oversized final frames without sending", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const session = await joinChat(page);
    const textarea = page.getByRole("textbox", { name: "Message" });
    const send = page.getByRole("button", { name: "Send message" });

    await textarea.fill("bad\tcontrol");
    await send.click();
    await expect(page.getByRole("alert")).toHaveText(
      "Message contains an unsupported control character.",
    );
    await expect(textarea).toHaveValue("bad\tcontrol");
    expect(session.clientFrames).toHaveLength(1);

    // Combining marks keep this within the 500-grapheme limit while making the
    // complete UTF-8 JSON frame exceed the 8,192-byte protocol limit.
    const oversized = `a${"\u0301".repeat(5000)}`;
    await textarea.fill(oversized);
    await send.click();
    await expect(page.getByRole("alert")).toHaveText(
      "Message is too large to send.",
    );
    await expect(textarea).toHaveValue(oversized);
    expect(session.clientFrames).toHaveLength(1);

    assertNoBrowserErrors();
  });

  test("allows only one send in flight and blocks repeated submissions", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const session = await joinChat(page);
    const textarea = page.getByRole("textbox", { name: "Message" });

    await textarea.fill("one in flight");
    await textarea.press("Enter");
    await expect.poll(() => session.clientFrames).toHaveLength(2);
    await expect(page.getByRole("form", { name: "Write a message" })).toHaveAttribute(
      "aria-busy",
      "true",
    );
    await expect(page.getByRole("button", { name: "Sending…" })).toBeDisabled();

    await textarea.press("Enter");
    await page.getByRole("form", { name: "Write a message" }).evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });
    await expect.poll(() => session.clientFrames).toHaveLength(2);

    assertNoBrowserErrors();
  });

  test("preserves the draft after invalid_message and releases the send lock", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const session = await joinChat(page);
    const textarea = page.getByRole("textbox", { name: "Message" });
    const send = page.getByRole("button", { name: "Send message" });
    const draft = "server must reject this";

    await textarea.fill(draft);
    await send.click();
    await expect.poll(() => session.clientFrames).toHaveLength(2);
    session.socket.send(errorFrame("invalid_message", "Message rejected by server."));

    await expect(page.getByRole("alert")).toHaveText("Message rejected by server.");
    await expect(textarea).toHaveValue(draft);
    await expect(textarea).toBeFocused();
    await expect(send).toBeEnabled();
    await send.click();
    await expect.poll(() => session.clientFrames).toHaveLength(3);

    assertNoBrowserErrors();
  });

  test("throttles for one second after rate_limited, then releases the draft", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    await page.clock.install({ time: new Date("2026-08-11T19:00:00Z") });
    const session = await joinChat(page);
    const textarea = page.getByRole("textbox", { name: "Message" });
    const form = page.getByRole("form", { name: "Write a message" });

    await textarea.fill("rate limited draft");
    await textarea.press("Enter");
    await expect.poll(() => session.clientFrames).toHaveLength(2);
    session.socket.send(errorFrame("rate_limited", "Slow down for a moment."));

    await expect(page.getByRole("alert")).toHaveText("Slow down for a moment.");
    await expect(textarea).toHaveValue("rate limited draft");
    await expect(page.getByRole("button", { name: "Temporarily throttled" })).toBeDisabled();
    await form.evaluate((element) => (element as HTMLFormElement).requestSubmit());
    await expect.poll(() => session.clientFrames).toHaveLength(2);

    await page.clock.fastForward(1000);
    await expect(page.getByRole("button", { name: "Send message" })).toBeEnabled();
    await textarea.press("Enter");
    await expect.poll(() => session.clientFrames).toHaveLength(3);
    expect(session.clientFrames[2]).toBe(sendMessageFrame("rate limited draft"));

    assertNoBrowserErrors();
  });

  test("deduplicates a message_id in the snapshot and live stream", async ({
    page,
  }) => {
    const assertNoBrowserErrors = observeBrowserErrors(page);
    const duplicate = {
      message_id: "duplicate-id",
      sender_id: peerId,
      username: "Ada",
      text: "only once",
      sent_at: "2026-08-11T19:00:00Z",
    };
    const session = await joinChat(page, [duplicate, duplicate]);
    const log = page.locator("#chat-log");

    await expect(log.locator(".chat-message")).toHaveCount(1);
    session.socket.send(
      messageFrame(
        duplicate.message_id,
        duplicate.sender_id,
        duplicate.username,
        duplicate.text,
        duplicate.sent_at,
      ),
    );
    await expect(log.locator(".chat-message")).toHaveCount(1);
    await expect(log.locator(".message-text")).toHaveText("only once");

    assertNoBrowserErrors();
  });

  for (const viewportWidth of [320, 1280]) {
    test(`scrolls own echoes, follows near-bottom peers, and preserves older reading at ${viewportWidth}px`, async ({
      page,
    }) => {
      await page.setViewportSize({ width: viewportWidth, height: 720 });
      const assertNoBrowserErrors = observeBrowserErrors(page);
      const session = await joinChat(page, overflowingMessages());
      const log = page.locator("#chat-log");
      const textarea = page.getByRole("textbox", { name: "Message" });

      await expect
        .poll(() =>
          log.evaluate(
            (element) => element.scrollHeight > element.clientHeight,
          ),
        )
        .toBe(true);

      await log.evaluate((element) => {
        element.scrollTop = 0;
      });
      await textarea.fill("my accepted message");
      await textarea.press("Enter");
      await expect.poll(() => session.clientFrames).toHaveLength(2);
      session.socket.send(
        messageFrame("own-scroll", selfId, "Ada", "my accepted message"),
      );
      await expect(log.locator(".chat-message")).toHaveCount(50);
      await expectAtBottom(page);

      await log.evaluate((element) => {
        element.scrollTop = 0;
      });
      session.socket.send(
        messageFrame("peer-old-reader", peerId, "Ada", "peer message"),
      );
      await expect(log.locator(".chat-message")).toHaveCount(50);
      await expect
        .poll(() => log.evaluate((element) => element.scrollTop))
        .toBe(0);

      await log.evaluate((element) => {
        element.scrollTop = element.scrollHeight - element.clientHeight;
      });
      session.socket.send(
        messageFrame(
          "peer-near-bottom",
          peerId,
          "Ada",
          "newest peer message",
        ),
      );
      await expect(log.locator(".chat-message")).toHaveCount(50);
      await expectAtBottom(page);

      assertNoBrowserErrors();
    });
  }
});
