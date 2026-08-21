import {
  expect,
  test,
  type Locator,
  type Page,
  type WebSocketRoute,
} from "@playwright/test";

type Box = { x: number; y: number; width: number; height: number };

type User = { connection_id: string; username: string };

const selfUser = { connection_id: "connection-self", username: "Ada" };

function roomState(users: User[] = [selfUser]) {
  return JSON.stringify({
    type: "room_state",
    room_id: "default",
    self_id: "connection-self",
    users,
    messages: [],
  });
}

function errorFrame(code: string, message: string) {
  return JSON.stringify({
    type: "error",
    room_id: "default",
    code,
    message,
    recoverable: false,
  });
}

async function joinOffice(page: Page, users?: User[]) {
  let socketRoute: WebSocketRoute | undefined;
  await page.routeWebSocket("/ws", (socket) => {
    socketRoute = socket;
    socket.onMessage((message) => {
      if (message === '{"type":"join_room","room_id":"default","username":"Ada"}') {
        socket.send(roomState(users));
      }
    });
  });

  await page.goto("/");
  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect(page.getByRole("status")).toHaveText("Joined the default office.");
  return socketRoute;
}

async function assertNoBodyOverflow(page: Page) {
  const overflow = await page.evaluate(() => ({
    document: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    body: document.body.scrollWidth > document.body.clientWidth,
  }));
  expect(overflow).toEqual({ document: false, body: false });
}

async function expectBoundingBox(locator: Locator): Promise<Box> {
  const bounds = await locator.boundingBox();
  expect(bounds).not.toBeNull();
  if (bounds === null) throw new Error("Expected a visible bounding box");
  return bounds;
}

function assertVerticallyWithin(bounds: Box, top: number, bottom: number) {
  expect(bounds.y).toBeGreaterThanOrEqual(top);
  expect(bounds.y + bounds.height).toBeLessThanOrEqual(bottom);
}

function assertContained(bounds: Box, container: Box) {
  expect(bounds.x).toBeGreaterThanOrEqual(container.x);
  expect(bounds.x + bounds.width).toBeLessThanOrEqual(
    container.x + container.width,
  );
  assertVerticallyWithin(
    bounds,
    container.y,
    container.y + container.height,
  );
}

for (const viewportWidth of [768, 1024, 1440] as const) {
  test(`keeps the desktop composer reachable at ${viewportWidth}×320`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: viewportWidth, height: 320 });
    await joinOffice(page);

    const composer = page.getByRole("form", { name: "Write a message" });
    const messageLog = page.getByRole("log", { name: "Messages" });
    const textarea = composer.getByRole("textbox", { name: "Message" });
    const send = page.getByRole("button", { name: "Send message" });
    await expect(composer).toBeVisible();
    await expect(send).toBeVisible();

    // The first successful join deliberately focuses the composer. Shift+Tab
    // still reaches the semantic message log, and Tab returns to the controls.
    await expect(textarea).toBeFocused();
    await page.keyboard.press("Shift+Tab");
    await expect(messageLog).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(textarea).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(send).toBeFocused();

    const viewportHeight = page.viewportSize()?.height;
    expect(viewportHeight).toBe(320);
    for (const control of [composer, send]) {
      const bounds = await expectBoundingBox(control);
      assertVerticallyWithin(bounds, 0, viewportHeight ?? 0);
    }
    await assertNoBodyOverflow(page);
  });
}

for (const viewport of [
  { width: 320, height: 640 },
  { width: 768, height: 640 },
  { width: 1024, height: 720 },
  { width: 1440, height: 900 },
] as const) {
  test(`keeps the office and composer usable at ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await joinOffice(page);

    const stage = page.locator(".office-stage");
    const rail = page.locator(".chat-rail");
    const canvas = page.locator("#office-canvas");
    const composer = page.getByRole("form", { name: "Write a message" });
    const send = page.getByRole("button", { name: "Send message" });
    await expect(canvas).toBeVisible();
    await expect(composer).toBeVisible();
    await expect(send).toBeVisible();

    const stageBounds = await expectBoundingBox(stage);
    const railBounds = await expectBoundingBox(rail);
    const viewportSize = page.viewportSize();
    expect(stageBounds.x + stageBounds.width).toBeLessThanOrEqual(
      viewportSize?.width ?? 0,
    );
    expect(railBounds.y + railBounds.height).toBeLessThanOrEqual(
      viewportSize?.height ?? 0,
    );
    if (viewport.width < 768) {
      expect(railBounds.y).toBeGreaterThanOrEqual(
        stageBounds.y + stageBounds.height,
      );
    } else {
      expect(railBounds.x).toBeGreaterThanOrEqual(
        stageBounds.x + stageBounds.width,
      );
    }
    await assertNoBodyOverflow(page);
  });
}

test("keeps the 320px mobile chat rail ordered and contained", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 });
  await joinOffice(page, [
    selfUser,
    { connection_id: "connection-peer", username: "Grace" },
  ]);

  const rail = page.locator(".chat-rail");
  const stage = page.locator(".office-stage");
  const canvas = page.locator("#office-canvas");
  const participantList = page
    .getByRole("region", { name: "Participants" })
    .getByRole("list");
  const messageLog = page.getByRole("log", { name: "Messages" });
  const composer = page.getByRole("form", { name: "Write a message" });
  const chatLogPanel = page.locator(".chat-log-panel");
  const chatHeading = chatLogPanel.locator(":scope > h3");
  const historyNote = chatLogPanel.locator(":scope > .history-note");
  const composerHeading = composer.locator(":scope > h3");
  const composerLabel = composer.locator(":scope > label");
  const composerHelp = composer.locator(":scope > .field-help");
  const composerFeedback = composer.locator(":scope > .form-feedback");
  const textarea = composer.getByRole("textbox", { name: "Message" });
  const send = page.getByRole("button", { name: "Send message" });

  const railBounds = await expectBoundingBox(rail);
  const stageBounds = await expectBoundingBox(stage);
  const canvasBounds = await expectBoundingBox(canvas);
  expect(canvasBounds.height).toBeGreaterThanOrEqual(96);
  expect(stageBounds.y + stageBounds.height).toBeLessThanOrEqual(railBounds.y);

  const directSections = await rail.locator(":scope > *").evaluateAll((elements) =>
    elements.map((element) => {
      const bounds = element.getBoundingClientRect();
      return { top: bounds.top, bottom: bounds.bottom };
    }),
  );
  for (let index = 1; index < directSections.length; index += 1) {
    expect(directSections[index].top).toBeGreaterThanOrEqual(
      directSections[index - 1].bottom - 1,
    );
  }
  for (const element of [participantList, messageLog, composer]) {
    assertContained(await expectBoundingBox(element), railBounds);
  }

  const chatPanelBounds = await expectBoundingBox(chatLogPanel);
  const chatFlow = [
    await expectBoundingBox(chatHeading),
    await expectBoundingBox(messageLog),
    await expectBoundingBox(historyNote),
  ];
  for (const bounds of chatFlow) {
    assertContained(bounds, chatPanelBounds);
  }
  for (let index = 1; index < chatFlow.length; index += 1) {
    expect(chatFlow[index].y).toBeGreaterThanOrEqual(
      chatFlow[index - 1].y + chatFlow[index - 1].height - 1,
    );
  }

  const composerBounds = await expectBoundingBox(composer);
  const headingBounds = await expectBoundingBox(composerHeading);
  const labelBounds = await expectBoundingBox(composerLabel);
  const textareaBounds = await expectBoundingBox(textarea);
  const sendBounds = await expectBoundingBox(send);
  const helpBounds = await expectBoundingBox(composerHelp);
  for (const bounds of [
    headingBounds,
    labelBounds,
    textareaBounds,
    sendBounds,
    helpBounds,
  ]) {
    assertContained(bounds, composerBounds);
  }
  expect(labelBounds.y).toBeGreaterThanOrEqual(
    headingBounds.y + headingBounds.height - 1,
  );
  const inputRowTop = Math.min(textareaBounds.y, sendBounds.y);
  const inputRowBottom = Math.max(
    textareaBounds.y + textareaBounds.height,
    sendBounds.y + sendBounds.height,
  );
  expect(inputRowTop).toBeGreaterThanOrEqual(
    labelBounds.y + labelBounds.height - 1,
  );
  expect(inputRowBottom).toBeLessThanOrEqual(helpBounds.y + 1);
  const feedbackCount = await composerFeedback.count();
  for (let index = 0; index < feedbackCount; index += 1) {
    const feedbackBounds = await expectBoundingBox(composerFeedback.nth(index));
    expect(feedbackBounds.y).toBeGreaterThanOrEqual(
      helpBounds.y + helpBounds.height - 1,
    );
    expect(feedbackBounds.y + feedbackBounds.height).toBeLessThanOrEqual(
      composerBounds.y + composerBounds.height,
    );
  }
  const composerFlow = [
    headingBounds,
    labelBounds,
    textareaBounds,
    sendBounds,
    helpBounds,
  ];
  for (const bounds of [...chatFlow, ...composerFlow]) {
    assertContained(bounds, railBounds);
    assertVerticallyWithin(bounds, 0, 720);
  }
  const renderedRailContent = await rail
    .locator("h2, h3, p, label, textarea, button, [role=\"log\"]")
    .evaluateAll((elements) =>
      elements.map((element) => {
        const bounds = element.getBoundingClientRect();
        return {
          x: bounds.x,
          y: bounds.y,
          right: bounds.right,
          bottom: bounds.bottom,
        };
      }),
    );
  for (const bounds of renderedRailContent) {
    expect(bounds.x).toBeGreaterThanOrEqual(railBounds.x);
    expect(bounds.right).toBeLessThanOrEqual(railBounds.x + railBounds.width);
    expect(bounds.y).toBeGreaterThanOrEqual(railBounds.y);
    expect(bounds.bottom).toBeLessThanOrEqual(railBounds.y + railBounds.height);
    expect(bounds.y).toBeGreaterThanOrEqual(0);
    expect(bounds.bottom).toBeLessThanOrEqual(720);
  }
  for (const control of [textarea, send]) {
    assertVerticallyWithin(await expectBoundingBox(control), 0, 720);
  }

  expect(await participantList.evaluate((element) => getComputedStyle(element).overflowY)).toBe(
    "auto",
  );
  expect(await messageLog.evaluate((element) => getComputedStyle(element).overflowY)).toBe(
    "auto",
  );
  expect(
    await participantList.evaluate((element) => element.scrollHeight > element.clientHeight),
  ).toBe(true);
  expect(await messageLog.evaluate((element) => element.scrollHeight > element.clientHeight)).toBe(
    true,
  );
  const flowElements = await page
    .locator("#canvas-fallback, #canvas-status")
    .evaluateAll((elements) =>
      elements.map((element) => {
        const bounds = element.getBoundingClientRect();
        return { top: bounds.top, bottom: bounds.bottom };
      }),
    );
  expect(flowElements[1].top).toBeGreaterThanOrEqual(flowElements[0].bottom - 1);
  await assertNoBodyOverflow(page);
});

test("keeps a crowded room scrollable without hiding the composer", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  const users = [
    selfUser,
    ...Array.from({ length: 49 }, (_, index) => ({
      connection_id: `connection-${index}`,
      username: `Visitor ${index} ${"界".repeat(8)}`,
    })),
  ];
  await joinOffice(page, users);

  const participantList = page
    .getByRole("region", { name: "Participants" })
    .getByRole("list");
  const messageLog = page.getByRole("log", { name: "Messages" });
  await expect(participantList.getByRole("listitem")).toHaveCount(50);
  await expect(page.getByRole("button", { name: "Send message" })).toBeVisible();
  expect(
    await participantList.evaluate((element) => element.scrollHeight > element.clientHeight),
  ).toBe(true);
  expect(await messageLog.evaluate((element) => getComputedStyle(element).overflowY)).toBe(
    "auto",
  );
  await assertNoBodyOverflow(page);
});

test("keeps crowded participants and the canvas usable in mobile landscape", async ({
  page,
}) => {
  await page.setViewportSize({ width: 640, height: 320 });
  const users = [
    selfUser,
    ...Array.from({ length: 49 }, (_, index) => ({
      connection_id: `connection-${index}`,
      username: `Visitor ${index} ${"界".repeat(8)}`,
    })),
  ];
  await joinOffice(page, users);

  const participantList = page
    .getByRole("region", { name: "Participants" })
    .getByRole("list");
  const canvas = page.locator("#office-canvas");
  const composer = page.getByRole("form", { name: "Write a message" });
  const send = page.getByRole("button", { name: "Send message" });
  await expect(participantList.getByRole("listitem")).toHaveCount(50);
  await expect(composer).toBeVisible();
  await expect(composer.getByText("Enter sends. Shift+Enter adds a line break.")).toBeVisible();
  await expect(send).toBeVisible();
  expect(
    await participantList.evaluate((element) => element.scrollHeight > element.clientHeight),
  ).toBe(true);
  expect(await participantList.evaluate((element) => getComputedStyle(element).display)).not.toBe(
    "none",
  );
  const canvasBounds = await canvas.boundingBox();
  expect(canvasBounds?.width ?? 0).toBeGreaterThan(100);
  expect(canvasBounds?.height ?? 0).toBeGreaterThan(16);
  await assertNoBodyOverflow(page);
});

test("keeps blocked recovery controls reachable at a 320px viewport", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 320 });
  await page.routeWebSocket("/ws", (socket) => {
    socket.onMessage((message) => {
      if (message === '{"type":"join_room","room_id":"default","username":"Ada"}') {
        socket.send(errorFrame("room_full", "Room is full."));
      }
    });
  });

  await page.goto("/");
  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect(page.getByRole("status")).toHaveText("The office is full right now.");
  await expect(username).toBeDisabled();
  await expect(page.getByRole("button", { name: "Enter the office" })).toBeDisabled();

  for (const control of [
    page.getByRole("button", { name: "Retry connection" }),
    page.getByRole("button", { name: "Return to username" }),
  ]) {
    await expect(control).toBeVisible();
    assertVerticallyWithin(await expectBoundingBox(control), 0, 320);
  }
  await assertNoBodyOverflow(page);
});

test("keeps the composer above a reduced visual viewport", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await joinOffice(page);
  await page.setViewportSize({ width: 320, height: 420 });

  const send = page.getByRole("button", { name: "Send message" });
  assertVerticallyWithin(await expectBoundingBox(send), 0, 420);
  await assertNoBodyOverflow(page);
});

test("reflows essential controls after text enlargement", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await joinOffice(page);
  await page.evaluate(() => {
    document.documentElement.style.fontSize = "200%";
  });

  const composer = page.getByRole("form", { name: "Write a message" });
  const send = page.getByRole("button", { name: "Send message" });
  await expect(composer).toBeVisible();
  await expect(send).toBeVisible();
  await assertNoBodyOverflow(page);
});

test("keeps reconnecting controls reachable", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  const socketRoute = await joinOffice(page);
  await socketRoute?.close();

  await expect(page.getByRole("status")).toContainText("Connection lost. Reconnecting");
  await expect(page.getByRole("button", { name: "Retry now" })).toBeVisible();
  await expect(page.getByRole("textbox", { name: "Message" })).toBeDisabled();
  await expect(page.getByRole("button", { name: "Return to username" })).toBeVisible();
  await assertNoBodyOverflow(page);
});
