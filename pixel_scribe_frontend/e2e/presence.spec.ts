import {
  expect,
  test,
  type Page,
  type WebSocketRoute,
} from "@playwright/test";
import { runAccessibilityScan } from "./support/accessibility";

const xssLikeUsername = "<script>alert(1)</script>";
const viewportWidths = [320, 1024] as const;

function collectFrames(frames: string[]) {
  return (message: string | { toString(): string }) => {
    frames.push(typeof message === "string" ? message : message.toString());
  };
}

async function joinWithRoutedPresence(
  page: Page,
  viewportWidth: number,
  consoleErrors: string[],
  pageErrors: string[],
) {
  await page.setViewportSize({
    width: viewportWidth,
    height: viewportWidth === 320 ? 720 : 768,
  });
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));

  const joinFrames: string[] = [];
  let routedSocket: WebSocketRoute | undefined;
  await page.routeWebSocket("/ws", (socket) => {
    routedSocket = socket;
    socket.onMessage(collectFrames(joinFrames));
  });

  await page.goto("/");
  const username = page.getByRole("textbox", { name: "Display name" });
  await username.fill("Ada");
  await username.press("Enter");
  await expect(page.getByRole("status")).toContainText(
    "Waiting for the office snapshot",
  );
  await expect.poll(() => joinFrames).toEqual([
    '{"type":"join_room","room_id":"default","username":"Ada"}',
  ]);

  if (routedSocket === undefined) throw new Error("WebSocket route was not opened");

  routedSocket.send(
    JSON.stringify({
      type: "room_state",
      room_id: "default",
      self_id: "connection-self",
      users: [
        { connection_id: "connection-self", username: "Ada" },
        { connection_id: "connection-duplicate-one", username: "Ada" },
        { connection_id: "connection-xss", username: xssLikeUsername },
      ],
      messages: [],
    }),
  );
  await expect(page.getByRole("status")).toHaveText(
    "Joined the default office.",
  );

  return routedSocket;
}

for (const viewportWidth of viewportWidths) {
  test(`proves joined presence semantics at ${viewportWidth}px`, async ({
    page,
  }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const socket = await joinWithRoutedPresence(
      page,
      viewportWidth,
      consoleErrors,
      pageErrors,
    );

    const participants = page.getByRole("region", { name: "Participants" });
    const participantList = participants.getByRole("list");
    const participantItems = participantList.locator("li");

    await expect(participants.getByText("3 participants", { exact: true })).toBeVisible();
    await expect(participantItems).toHaveText([
      "Ada (You)",
      "Ada",
      xssLikeUsername,
    ]);

    socket.send(
      JSON.stringify({
        type: "user_joined",
        room_id: "default",
        user: {
          connection_id: "connection-duplicate-two",
          username: "Ada",
        },
      }),
    );
    await expect(participants.getByText("4 participants", { exact: true })).toBeVisible();
    await expect(participantItems).toHaveText([
      "Ada (You)",
      "Ada",
      xssLikeUsername,
      "Ada",
    ]);

    socket.send(
      JSON.stringify({
        type: "user_left",
        room_id: "default",
        connection_id: "connection-duplicate-one",
      }),
    );
    await expect(participants.getByText("3 participants", { exact: true })).toBeVisible();
    await expect(participantItems).toHaveText([
      "Ada (You)",
      xssLikeUsername,
      "Ada",
    ]);
    await expect(participants.locator(".participant-self")).toHaveCount(1);

    const xssText = participantList.getByText(xssLikeUsername, { exact: true });
    await expect(xssText).toBeVisible();
    await expect(participantList.locator("script, img, [role]")).toHaveCount(0);
    await expect(page.locator("img[onerror]")).toHaveCount(0);
    await expect(page.getByRole("alert")).toHaveCount(0);

    const composer = page.getByRole("form", { name: "Write a message" });
    await expect(composer).toBeVisible();
    await expect(composer).toHaveAttribute("aria-busy", "false");
    await expect(composer.getByRole("textbox", { name: "Message" })).toBeEnabled();
    await expect(composer.getByRole("button", { name: "Send message" })).toBeEnabled();

    await expect(page.getByRole("log")).toContainText("No messages yet.");

    const results = await runAccessibilityScan(page);
    expect(results.violations).toEqual([]);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
  });
}
