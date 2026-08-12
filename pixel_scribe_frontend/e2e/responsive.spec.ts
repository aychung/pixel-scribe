import { expect, test } from "@playwright/test";

for (const viewportWidth of [768, 1024, 1440] as const) {
  test(`keeps the desktop composer reachable at ${viewportWidth}×320`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: viewportWidth, height: 320 });

    await page.routeWebSocket("/ws", (socket) => {
      socket.onMessage((message) => {
        if (
          message !==
          '{"type":"join_room","room_id":"default","username":"Ada"}'
        ) {
          return;
        }

        socket.send(
          JSON.stringify({
            type: "room_state",
            room_id: "default",
            self_id: "connection-self",
            users: [{ connection_id: "connection-self", username: "Ada" }],
            messages: [],
          }),
        );
      });
    });

    await page.goto("/");
    const username = page.getByRole("textbox", { name: "Display name" });
    await username.fill("Ada");
    await username.press("Enter");

    const composer = page.getByRole("form", { name: "Write a message" });
    const messageLog = page.getByRole("log", { name: "Messages" });
    const textarea = composer.getByRole("textbox", { name: "Message" });
    const send = page.getByRole("button", { name: "Send message" });
    await expect(composer).toBeVisible();
    await expect(send).toBeVisible();

    await page.keyboard.press("Tab");
    await expect(messageLog).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(textarea).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(send).toBeFocused();

    const viewportHeight = page.viewportSize()?.height;
    expect(viewportHeight).toBe(320);
    for (const control of [composer, send]) {
      const bounds = await control.boundingBox();
      expect(bounds).not.toBeNull();
      expect(bounds?.y).toBeGreaterThanOrEqual(0);
      expect((bounds?.y ?? 0) + (bounds?.height ?? 0)).toBeLessThanOrEqual(
        viewportHeight ?? 0,
      );
    }
  });
}
