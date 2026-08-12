import { expect, test, type Page, type WebSocketRoute } from "@playwright/test";

const roomState = JSON.stringify({
  type: "room_state",
  room_id: "default",
  self_id: "connection-ada",
  users: [{ connection_id: "connection-ada", username: "Ada" }],
  messages: [],
});

function collectTextFrames(frames: string[]) {
  return (message: string | { toString(): string }) => {
    frames.push(typeof message === "string" ? message : message.toString());
  };
}

async function enterWithRoutedSocket(
  page: Page,
  onSocket: (socket: WebSocketRoute) => void,
) {
  const joinFrames: string[] = [];
  let socketCount = 0;

  await page.routeWebSocket("/ws", (socket) => {
    socketCount += 1;
    socket.onMessage(collectTextFrames(joinFrames));
    onSocket(socket);
  });
  await page.goto("/");

  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect(page.getByRole("status")).toContainText(
    "Waiting for the office snapshot",
  );
  await expect.poll(() => joinFrames).toHaveLength(1);

  return { joinFrames, getSocketCount: () => socketCount };
}

test.describe("username join", () => {
  test("sends one join and waits for the matching room snapshot", async ({
    page,
  }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const joinFrames: string[] = [];
    let socketCount = 0;
    let sendSnapshot: (() => void) | undefined;

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));

    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      sendSnapshot = () => socket.send(roomState);
      socket.onMessage(collectTextFrames(joinFrames));
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    const status = page.getByRole("status");
    await username.fill("Ada");
    await username.press("Enter");

    await expect(status).toContainText(/Connecting|Waiting/);
    await expect(status).toContainText("Waiting for the office snapshot");
    await expect
      .poll(() => joinFrames)
      .toEqual(['{"type":"join_room","room_id":"default","username":"Ada"}']);
    expect(socketCount).toBe(1);

    sendSnapshot?.();
    await expect(status).toContainText("Joined the default office");
    expect(socketCount).toBe(1);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });

  test("reports an oversized valid username without opening a socket", async ({
    page,
  }) => {
    let socketCount = 0;
    await page.routeWebSocket("/ws", () => {
      socketCount += 1;
    });
    await page.goto("/");

    // One grapheme cluster with enough combining marks to exceed the final
    // UTF-8 join frame while remaining within the 32-grapheme username limit.
    const oversizedUsername = `a${"\u0301".repeat(5000)}`;
    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill(oversizedUsername);
    await username.press("Enter");

    await expect(page.getByRole("alert")).toHaveText(
      "Username is too large to send.",
    );
    expect(socketCount).toBe(0);
  });

  test("ignores a duplicate submit while the first join awaits its snapshot", async ({
    page,
  }) => {
    const joinFrames: string[] = [];
    let socketCount = 0;

    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      socket.onMessage(collectTextFrames(joinFrames));
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toContainText(
      "Waiting for the office snapshot",
    );
    await username.press("Enter");

    await expect.poll(() => joinFrames).toHaveLength(1);
    expect(joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(socketCount).toBe(1);
  });

  test("ignores presence deltas that arrive before the room snapshot", async ({
    page,
  }) => {
    let socket: WebSocketRoute | undefined;
    const joined = await enterWithRoutedSocket(page, (candidate) => {
      socket = candidate;
    });

    socket?.send(
      JSON.stringify({
        type: "user_joined",
        room_id: "default",
        user: { connection_id: "connection-grace", username: "Grace" },
      }),
    );
    await expect(page.getByRole("status")).toContainText(
      "Waiting for the office snapshot",
    );

    socket?.send(roomState);
    await expect(page.getByRole("status")).toContainText(
      "Joined the default office",
    );
    expect(joined.joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(joined.getSocketCount()).toBe(1);
  });

  test("fails closed on a current-generation wrong-room frame", async ({
    page,
  }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const joinFrames: string[] = [];
    let socketCount = 0;
    let closeCount = 0;

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      socket.onMessage(collectTextFrames(joinFrames));
      socket.onClose(() => {
        closeCount += 1;
      });
      socket.send(
        JSON.stringify({
          type: "user_joined",
          room_id: "other",
          user: { connection_id: "connection-grace", username: "Grace" },
        }),
      );
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toHaveText(
      "The office is unavailable.",
    );
    await expect.poll(() => closeCount).toBe(1);
    expect(joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(socketCount).toBe(1);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });

  test("blocks a malformed known frame and closes the socket", async ({
    page,
  }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const joinFrames: string[] = [];
    let socketCount = 0;
    let closeCount = 0;

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      socket.onMessage(collectTextFrames(joinFrames));
      socket.onClose(() => {
        closeCount += 1;
      });
      socket.send('{"type":"room_state","room_id":"default"}');
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toHaveText(
      "The office is unavailable.",
    );
    await expect.poll(() => closeCount).toBe(1);
    expect(joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(socketCount).toBe(1);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });

  test("blocks a binary frame and closes the socket", async ({ page }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const joinFrames: string[] = [];
    let socketCount = 0;
    let closeCount = 0;

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      socket.onMessage(collectTextFrames(joinFrames));
      socket.onClose(() => {
        closeCount += 1;
      });
      socket.send(
        Buffer.from(
          '{"type":"room_state","room_id":"default","self_id":"connection-ada","users":[],"messages":[]}',
        ),
      );
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toHaveText(
      "The office is unavailable.",
    );
    await expect.poll(() => closeCount).toBe(1);
    expect(joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(socketCount).toBe(1);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });

  test("fails closed when a matching snapshot omits its self presence", async ({
    page,
  }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const joinFrames: string[] = [];
    let socketCount = 0;
    let closeCount = 0;

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("pageerror", (error) => pageErrors.push(error.message));
    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      socket.onMessage(collectTextFrames(joinFrames));
      socket.onClose(() => {
        closeCount += 1;
      });
      socket.send(
        JSON.stringify({
          type: "room_state",
          room_id: "default",
          self_id: "connection-ada",
          users: [{ connection_id: "connection-grace", username: "Grace" }],
          messages: [],
        }),
      );
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toHaveText(
      "The office is unavailable.",
    );
    await expect.poll(() => closeCount).toBe(1);
    expect(joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(socketCount).toBe(1);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });

  test("fails closed when a snapshot repeats a connection ID", async ({
    page,
  }) => {
    const joinFrames: string[] = [];
    let socketCount = 0;
    let closeCount = 0;

    await page.routeWebSocket("/ws", (socket) => {
      socketCount += 1;
      socket.onMessage(collectTextFrames(joinFrames));
      socket.onClose(() => {
        closeCount += 1;
      });
      socket.send(
        JSON.stringify({
          type: "room_state",
          room_id: "default",
          self_id: "connection-ada",
          users: [
            { connection_id: "connection-ada", username: "Ada" },
            { connection_id: "connection-ada", username: "Ada again" },
          ],
          messages: [],
        }),
      );
    });
    await page.goto("/");

    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");
    await expect(page.getByRole("status")).toHaveText(
      "The office is unavailable.",
    );
    await expect.poll(() => closeCount).toBe(1);
    expect(joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(socketCount).toBe(1);
  });

  test("ignores an unknown future event and still joins from its snapshot", async ({
    page,
  }) => {
    let socket: WebSocketRoute | undefined;
    const joined = await enterWithRoutedSocket(page, (candidate) => {
      socket = candidate;
    });

    socket?.send(
      JSON.stringify({
        type: "future_event",
        room_id: "default",
        private_payload: "discard me",
      }),
    );
    await expect(page.getByRole("status")).toContainText(
      "Waiting for the office snapshot",
    );

    socket?.send(roomState);
    await expect(page.getByRole("status")).toContainText(
      "Joined the default office",
    );
    expect(joined.joinFrames).toEqual([
      '{"type":"join_room","room_id":"default","username":"Ada"}',
    ]);
    expect(joined.getSocketCount()).toBe(1);
  });

});
