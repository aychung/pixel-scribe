import {
  expect,
  test,
  type Page,
  type WebSocketRoute,
} from "@playwright/test";

type Session = {
  socket: WebSocketRoute;
  clientFrames: string[];
};

const joinFrame = (username: string) =>
  JSON.stringify({ type: "join_room", room_id: "default", username });

function roomState(
  selfId: string,
  users: Array<{ connection_id: string; username: string }>,
  messages: object[] = [],
) {
  return JSON.stringify({
    type: "room_state",
    room_id: "default",
    self_id: selfId,
    users,
    messages,
  });
}

function messageFrame(
  messageId: string,
  senderId: string,
  username: string,
  text: string,
) {
  return JSON.stringify({
    type: "message_sent",
    room_id: "default",
    message: {
      message_id: messageId,
      sender_id: senderId,
      username,
      text,
      sent_at: "2026-08-13T12:00:00Z",
    },
  });
}

function sendMessageFrame(text: string) {
  return JSON.stringify({ type: "send_message", room_id: "default", text });
}

async function routePage(page: Page) {
  const sessions: Session[] = [];
  await page.routeWebSocket("/ws", (socket) => {
    const session = { socket, clientFrames: [] };
    sessions.push(session);
    socket.onMessage((message) => {
      session.clientFrames.push(
        typeof message === "string" ? message : message.toString(),
      );
    });
  });
  return sessions;
}

async function enterOffice(
  page: Page,
  sessions: Session[],
  username: string,
) {
  await page.goto("/");
  const field = page.getByRole("textbox", { name: "Display name" });
  await field.fill(username);
  await field.press("Enter");
  await expect.poll(() => sessions).toHaveLength(1);
  await expect.poll(() => sessions[0].clientFrames).toEqual([
    joinFrame(username),
  ]);
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

test("two routed pages exchange chat and rejoin with a fresh snapshot", async ({
  browser,
}) => {
  const context = await browser.newContext();
  const adaPage = await context.newPage();
  const secondAdaPage = await context.newPage();
  await Promise.all([
    adaPage.clock.install({ time: new Date("2026-08-13T12:00:00Z") }),
    secondAdaPage.clock.install({ time: new Date("2026-08-13T12:00:00Z") }),
  ]);
  const assertAdaIsClean = observeBrowserErrors(adaPage);
  const assertSecondAdaIsClean = observeBrowserErrors(secondAdaPage);
  const adaSessions = await routePage(adaPage);
  const secondAdaSessions = await routePage(secondAdaPage);

  await Promise.all([
    enterOffice(adaPage, adaSessions, "Ada"),
    enterOffice(secondAdaPage, secondAdaSessions, "Ada"),
  ]);

  const initialUsers = [
    { connection_id: "connection-ada", username: "Ada" },
    { connection_id: "connection-second-ada", username: "Ada" },
  ];
  adaSessions[0].socket.send(roomState("connection-ada", initialUsers));
  secondAdaSessions[0].socket.send(
    roomState("connection-second-ada", initialUsers),
  );
  await expect(adaPage.getByRole("status")).toHaveText(
    "Joined the default office.",
  );
  await expect(secondAdaPage.getByRole("status")).toHaveText(
    "Joined the default office.",
  );

  for (const [page, expectedParticipants] of [
    [adaPage, ["Ada (You)", "Ada"]],
    [secondAdaPage, ["Ada", "Ada (You)"]],
  ] as const) {
    await expect(
      page
        .getByRole("region", { name: "Participants" })
        .getByRole("list")
        .locator("li"),
    ).toHaveText(expectedParticipants);
  }

  const adaMessage = "Hello, other Ada";
  const secondAdaMessage = "Hello back";
  const adaComposer = adaPage.getByRole("textbox", { name: "Message" });
  const secondAdaComposer = secondAdaPage.getByRole("textbox", {
    name: "Message",
  });
  await adaComposer.fill(adaMessage);
  await adaComposer.press("Enter");
  await expect.poll(() => adaSessions[0].clientFrames).toEqual([
    joinFrame("Ada"),
    sendMessageFrame(adaMessage),
  ]);
  await expect(adaPage.locator("#chat-log .chat-message")).toHaveCount(0);

  const firstMessage = messageFrame(
    "message-from-ada",
    "connection-ada",
    "Ada",
    adaMessage,
  );
  adaSessions[0].socket.send(firstMessage);
  secondAdaSessions[0].socket.send(firstMessage);
  await expect(adaPage.locator("#chat-log .message-text")).toHaveText(
    adaMessage,
  );
  await expect(secondAdaPage.locator("#chat-log .message-text")).toHaveText(
    adaMessage,
  );

  await secondAdaComposer.fill(secondAdaMessage);
  await secondAdaComposer.press("Enter");
  await expect.poll(() => secondAdaSessions[0].clientFrames).toEqual([
    joinFrame("Ada"),
    sendMessageFrame(secondAdaMessage),
  ]);
  const secondMessage = messageFrame(
    "message-from-second-ada",
    "connection-second-ada",
    "Ada",
    secondAdaMessage,
  );
  adaSessions[0].socket.send(secondMessage);
  secondAdaSessions[0].socket.send(secondMessage);
  await expect(adaPage.locator("#chat-log .chat-message")).toHaveCount(2);
  await expect(secondAdaPage.locator("#chat-log .chat-message")).toHaveCount(2);

  await secondAdaComposer.fill("draft kept across reconnect");
  await secondAdaSessions[0].socket.close();
  adaSessions[0].socket.send(
    JSON.stringify({
      type: "user_left",
      room_id: "default",
      connection_id: "connection-second-ada",
    }),
  );
  await expect(
    adaPage
      .getByRole("region", { name: "Participants" })
      .getByRole("list")
      .locator("li"),
  ).toHaveText(["Ada (You)"]);

  await expect(secondAdaPage.getByRole("status")).toHaveText(
    "Connection lost. Reconnecting…",
  );
  await secondAdaPage.clock.fastForward(500);
  await expect.poll(() => secondAdaSessions).toHaveLength(2);
  await expect.poll(() => secondAdaSessions[1].clientFrames).toEqual([
    joinFrame("Ada"),
  ]);

  const rejoinedUsers = [
    { connection_id: "connection-ada", username: "Ada" },
    { connection_id: "connection-second-ada-rejoined", username: "Ada" },
  ];
  secondAdaSessions[1].socket.send(
    roomState("connection-second-ada-rejoined", rejoinedUsers, [
      {
        message_id: "reconnected-history",
        sender_id: "connection-ada",
        username: "Ada",
        text: "fresh snapshot",
        sent_at: "2026-08-13T12:01:00Z",
      },
    ]),
  );
  adaSessions[0].socket.send(
    JSON.stringify({
      type: "user_joined",
      room_id: "default",
      user: {
        connection_id: "connection-second-ada-rejoined",
        username: "Ada",
      },
    }),
  );

  await expect(secondAdaPage.getByRole("status")).toHaveText(
    "Joined the default office.",
  );
  await expect(secondAdaPage.locator("#chat-log .message-text")).toHaveText(
    "fresh snapshot",
  );
  await expect(secondAdaPage.locator("#chat-log")).not.toContainText(
    adaMessage,
  );
  await expect(secondAdaComposer).toHaveValue("draft kept across reconnect");
  await expect(
    secondAdaPage
      .getByRole("region", { name: "Participants" })
      .getByRole("list")
      .locator("li"),
  ).toHaveText(["Ada", "Ada (You)"]);
  expect(secondAdaSessions[1].clientFrames).toEqual([joinFrame("Ada")]);

  assertAdaIsClean();
  assertSecondAdaIsClean();
  await context.close();
});
