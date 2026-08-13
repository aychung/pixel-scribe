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

type ErrorCode =
  | "invalid_event"
  | "join_required"
  | "already_joined"
  | "invalid_room_id"
  | "room_not_found"
  | "room_mismatch"
  | "room_unavailable"
  | "invalid_username"
  | "invalid_message"
  | "rate_limited"
  | "room_full";

const joinFrame = '{"type":"join_room","room_id":"default","username":"Ada"}';

function roomState(selfId: string, text = "initial history") {
  return JSON.stringify({
    type: "room_state",
    room_id: "default",
    self_id: selfId,
    users: [{ connection_id: selfId, username: "Ada" }],
    messages: [
      {
        message_id: `${selfId}-message`,
        sender_id: selfId,
        username: "Ada",
        text,
        sent_at: "2026-08-13T12:00:00Z",
      },
    ],
  });
}

function errorFrame(
  code: ErrorCode,
  message = `${code} feedback`,
  recoverable = true,
) {
  return JSON.stringify({
    type: "error",
    room_id: code === "invalid_event" || code === "invalid_room_id"
      ? null
      : code === "room_mismatch"
        ? "other"
        : "default",
    code,
    message,
    recoverable,
  });
}

function installDeterminism(page: Page) {
  return Promise.all([
    page.clock.install({ time: new Date("2026-08-13T12:00:00Z") }),
    page.addInitScript(() => {
      Object.defineProperty(Math, "random", { value: () => 0.5 });
      Object.defineProperty(globalThis.crypto, "getRandomValues", {
        value: (values: Uint32Array) => {
          values[0] = 2147483648;
          return values;
        },
      });
    }),
  ]);
}

async function routeSessions(page: Page) {
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

async function enterOffice(page: Page, sessions: Session[]) {
  await page.goto("/");
  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect.poll(() => sessions).toHaveLength(1);
  await expect.poll(() => sessions[0].clientFrames).toEqual([joinFrame]);
}

async function joinOffice(
  page: Page,
  sessions: Session[],
  selfId = "self-one",
  history = "initial history",
) {
  await enterOffice(page, sessions);
  sessions[0].socket.send(roomState(selfId, history));
  await expect(page.getByRole("status")).toHaveText(
    "Joined the default office.",
  );
}

async function assertNoBrowserErrors(page: Page) {
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

test.describe("reconnect and terminal error recovery", () => {
  test("preserves stale chat and draft, retries by timer, replaces the snapshot, and never replays", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await joinOffice(page, sessions, "self-one", "old snapshot");

    const textarea = page.getByRole("textbox", { name: "Message" });
    await textarea.fill("offline draft");
    await textarea.press("Enter");
    await expect.poll(() => sessions[0].clientFrames).toHaveLength(2);
    await expect(page.getByRole("button", { name: "Sending…" })).toBeDisabled();

    await sessions[0].socket.close();
    await expect(page.getByRole("status")).toHaveText(
      "Connection lost. Reconnecting…",
    );
    await expect(textarea).toHaveValue("offline draft");
    await expect(textarea).toBeDisabled();
    await expect(page.getByText("old snapshot", { exact: true })).toBeVisible();
    await expect.poll(() => sessions[0].clientFrames).toHaveLength(2);

    await page.clock.fastForward(500);
    await expect.poll(() => sessions).toHaveLength(2);
    await expect.poll(() => sessions[1].clientFrames).toEqual([joinFrame]);
    expect(sessions[1].clientFrames).not.toContain(
      JSON.stringify({ type: "send_message", room_id: "default", text: "offline draft" }),
    );

    sessions[1].socket.send(roomState("self-two", "replacement snapshot"));
    await expect(page.getByRole("status")).toHaveText(
      "Joined the default office.",
    );
    await expect(page.getByText("replacement snapshot", { exact: true })).toBeVisible();
    await expect(page.getByText("old snapshot", { exact: true })).toHaveCount(0);
    await expect(page.locator(".participant-self")).toHaveText(" (You)");
    await expect(textarea).toHaveValue("offline draft");
    await expect(textarea).toBeEnabled();
    expect(sessions[1].clientFrames).toEqual([joinFrame]);

    assertClean();
  });

  test("offers immediate retry when the first socket drops before a snapshot", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await enterOffice(page, sessions);

    await sessions[0].socket.close();
    await expect(page.getByRole("status")).toHaveText(
      "Connection lost. Reconnecting…",
    );
    await expect(page.getByRole("button", { name: "Retry now" })).toBeVisible();

    await page.getByRole("button", { name: "Retry now" }).click();
    await expect.poll(() => sessions).toHaveLength(2);
    await expect.poll(() => sessions[1].clientFrames).toEqual([joinFrame]);
    assertClean();
  });

  test("cancels the timer for immediate retry and rejects the old generation", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await joinOffice(page, sessions);

    await sessions[0].socket.close();
    await expect(page.getByRole("button", { name: "Retry now" })).toBeVisible();
    await page.getByRole("button", { name: "Retry now" }).click();
    await expect.poll(() => sessions).toHaveLength(2);
    await expect.poll(() => sessions[1].clientFrames).toEqual([joinFrame]);

    await page.clock.fastForward(30_000);
    expect(sessions).toHaveLength(2);
    expect(sessions[1].clientFrames).toEqual([joinFrame]);

    sessions[1].socket.send(roomState("new-self", "new generation"));
    await expect(page.getByRole("status")).toHaveText(
      "Joined the default office.",
    );
    assertClean();
  });

  test("room_unavailable enters the same timed recovery path without replay", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await joinOffice(page, sessions, "self-one", "stale room");

    sessions[0].socket.send(
      errorFrame("room_unavailable", "The room is restarting.", false),
    );
    await sessions[0].socket.close();
    await expect(page.getByRole("status")).toHaveText(
      "Connection lost. Reconnecting…",
    );
    await expect(page.getByRole("alert")).toHaveText(
      "The room is restarting.",
    );
    await expect(page.getByText("stale room", { exact: true })).toBeVisible();
    await page.clock.fastForward(500);
    await expect.poll(() => sessions).toHaveLength(2);
    await expect.poll(() => sessions[1].clientFrames).toEqual([joinFrame]);
    assertClean();
  });

  test("room_full is a blocked state with explicit retry and no retry loop", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await enterOffice(page, sessions);

    sessions[0].socket.send(errorFrame("room_full", "The office is full.", false));
    await sessions[0].socket.close();
    await expect(page.getByRole("status")).toHaveText(
      "The office is full right now.",
    );
    await expect(page.getByRole("alert")).toHaveText("The office is full.");
    await expect(page.getByRole("button", { name: "Retry connection" })).toBeVisible();
    await page.clock.fastForward(30_000);
    expect(sessions).toHaveLength(1);

    await page.getByRole("button", { name: "Retry connection" }).click();
    await expect.poll(() => sessions).toHaveLength(2);
    await expect.poll(() => sessions[1].clientFrames).toEqual([joinFrame]);
    assertClean();
  });

  test("protocol failure offers return to username and ignores the late close", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await joinOffice(page, sessions);

    sessions[0].socket.send(
      errorFrame("invalid_event", "The server rejected this protocol frame.", false),
    );
    await sessions[0].socket.close();
    await expect(page.getByRole("status")).toHaveText(
      "The office is unavailable.",
    );
    await expect(page.getByRole("alert")).toHaveText("Protocol error.");
    await expect(page.getByRole("button", { name: "Return to username" })).toBeVisible();

    await page.getByRole("button", { name: "Return to username" }).click();
    await expect(page.getByRole("region", { name: "Join the office" })).toBeVisible();
    await expect(page.getByRole("textbox", { name: "Display name" })).toHaveValue("Ada");
    await page.clock.fastForward(30_000);
    expect(sessions).toHaveLength(1);
    assertClean();
  });

  test("recoverable errors stay local and do not create automatic sockets", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await joinOffice(page, sessions);

    sessions[0].socket.send(errorFrame("room_mismatch", "Wrong room."));
    await expect(page.getByRole("alert")).toHaveText("Wrong room.");
    expect(sessions).toHaveLength(1);
    await expect(page.getByRole("textbox", { name: "Message" })).toBeEnabled();

    sessions[0].socket.send(errorFrame("invalid_message", "Message is invalid."));
    await expect(page.getByRole("alert")).toHaveText("Message is invalid.");
    expect(sessions).toHaveLength(1);

    sessions[0].socket.send(errorFrame("rate_limited", "Slow down."));
    await expect(page.getByRole("alert")).toHaveText("Slow down.");
    await expect(page.getByRole("button", { name: "Temporarily throttled" })).toBeDisabled();
    await page.clock.fastForward(1000);
    await expect(page.getByRole("button", { name: "Send message" })).toBeEnabled();
    expect(sessions).toHaveLength(1);
    assertClean();
  });

  for (const code of ["join_required", "already_joined"] as const) {
    test(`${code} keeps the unjoined socket usable without a retry loop`, async ({
      page,
    }) => {
      await installDeterminism(page);
      const assertClean = await assertNoBrowserErrors(page);
      const sessions = await routeSessions(page);
      await enterOffice(page, sessions);

      sessions[0].socket.send(errorFrame(code, `${code} feedback`));
      await expect(page.getByRole("status")).toHaveText(
        "Waiting for the office snapshot…",
      );
      await expect(page.getByRole("alert")).toHaveText(`${code} feedback`);
      expect(sessions).toHaveLength(1);
      await page.clock.fastForward(30_000);
      expect(sessions).toHaveLength(1);
      assertClean();
    });
  }

  for (const code of ["invalid_room_id", "room_not_found"] as const) {
    test(`${code} enters the blocked unavailable-office state`, async ({ page }) => {
      await installDeterminism(page);
      const assertClean = await assertNoBrowserErrors(page);
      const sessions = await routeSessions(page);
      await enterOffice(page, sessions);

      sessions[0].socket.send(errorFrame(code, `${code} feedback`));
      await sessions[0].socket.close();
      await expect(page.getByRole("status")).toHaveText(
        "The office is unavailable.",
      );
      await expect(page.getByRole("alert")).toHaveText(`${code} feedback`);
      await expect(page.getByRole("button", { name: "Retry connection" })).toBeVisible();
      expect(sessions).toHaveLength(1);
      assertClean();
    });
  }

  test("invalid_username returns focus to the username form without reopening", async ({
    page,
  }) => {
    await installDeterminism(page);
    const assertClean = await assertNoBrowserErrors(page);
    const sessions = await routeSessions(page);
    await enterOffice(page, sessions);

    sessions[0].socket.send(errorFrame("invalid_username", "Name rejected."));
    await sessions[0].socket.close();
    const username = page.getByRole("textbox", { name: "Display name" });
    await expect(username).toHaveValue("Ada");
    await expect(username).toBeFocused();
    await expect(page.getByRole("alert")).toHaveText("Name rejected.");
    expect(sessions).toHaveLength(1);
    assertClean();
  });
});
