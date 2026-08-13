import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import pixel_scribe_frontend/browser
import pixel_scribe_frontend/domain
import pixel_scribe_frontend/model.{type Model}
import pixel_scribe_frontend/update.{type Msg}

pub fn view(model: Model) -> Element(Msg) {
  html.main([attribute.class("app-shell")], [
    app_header(),
    case model.room_snapshot {
      Some(snapshot) -> joined_workspace(model, snapshot)
      None ->
        html.div([attribute.class("workspace-shell")], [
          office_preview(),
          username_panel(model),
        ])
    },
  ])
}

fn app_header() -> Element(Msg) {
  html.header([attribute.class("app-header")], [
    html.h1([], [html.text("Pixel Scribe")]),
    html.p([attribute.class("app-introduction")], [
      html.text("A small virtual office for focused conversations."),
    ]),
  ])
}

fn office_preview() -> Element(Msg) {
  html.section(
    [
      attribute.class("office-preview"),
      attribute.aria_labelledby("office-preview-label"),
    ],
    [
      html.p(
        [attribute.id("office-preview-label"), attribute.class("section-label")],
        [html.text("Office preview")],
      ),
      html.div(
        [
          attribute.class("preview-frame"),
          attribute.role("img"),
          attribute.aria_label("A quiet pixel-art office waiting for visitors"),
        ],
        [
          html.div([attribute.class("preview-sun")], []),
          html.div([attribute.class("preview-desk")], []),
          html.div([attribute.class("preview-chair")], []),
          html.div([attribute.class("preview-plant")], []),
        ],
      ),
      html.p([attribute.class("preview-description")], [
        html.text(
          "The office is ready. Choose a display name to see who is around.",
        ),
      ]),
    ],
  )
}

fn username_panel(model: Model) -> Element(Msg) {
  html.section(
    [
      attribute.class("join-panel"),
      attribute.aria_labelledby("join-panel-label"),
    ],
    [
      html.p(
        [attribute.id("join-panel-label"), attribute.class("section-label")],
        [html.text("Join the office")],
      ),
      html.form(
        [
          attribute.class("username-form"),
          event.on_submit(fn(_fields) { update.SubmitUsername }),
        ],
        [
          html.label([attribute.for("username")], [html.text("Display name")]),
          html.input([
            attribute.id("username"),
            attribute.name("username"),
            attribute.type_("text"),
            attribute.autocomplete("nickname"),
            attribute.placeholder("e.g. Ada"),
            attribute.value(model.username_input),
            attribute.required(True),
            attribute.aria_describedby(username_description_ids(model.feedback)),
            event.on_input(update.UsernameInput),
          ]),
          html.p(
            [attribute.id("username-help"), attribute.class("field-help")],
            [html.text("Use 1–32 characters. Spaces and emoji are welcome.")],
          ),
          feedback_message("username-feedback", model.feedback),
          feedback_message("connection-feedback", model.connection_feedback),
          html.button(
            [attribute.type_("submit"), attribute.class("join-button")],
            [html.text("Enter the office")],
          ),
        ],
      ),
      html.p(
        [
          attribute.class("status-copy"),
          attribute.role("status"),
          attribute.aria_live("polite"),
        ],
        [html.text(connection_status(model, False))],
      ),
      username_retry_controls(model),
    ],
  )
}

fn joined_workspace(
  model: Model,
  snapshot: model.RoomSnapshot,
) -> Element(Msg) {
  html.div([attribute.class("workspace-shell joined-workspace")], [
    office_stage(),
    html.aside(
      [
        attribute.class("chat-rail"),
        attribute.aria_labelledby("chat-rail-label"),
      ],
      [
        html.header([attribute.class("chat-rail-header")], [
          html.h2([attribute.id("chat-rail-label")], [html.text("Office chat")]),
        ]),
        status_region(model, snapshot.stale),
        participants_panel(snapshot),
        chat_log(snapshot),
        composer(model),
        retry_controls(model),
      ],
    ),
  ])
}

fn office_stage() -> Element(Msg) {
  html.section(
    [
      attribute.class("office-stage"),
      attribute.aria_labelledby("office-stage-label"),
    ],
    [
      html.header([attribute.class("office-stage-header")], [
        html.h2([attribute.id("office-stage-label")], [html.text("Office")]),
        html.p([attribute.class("office-stage-note")], [
          html.text("A shared space for the people in this room."),
        ]),
      ]),
      html.figure([attribute.class("canvas-placeholder")], [
        html.canvas([
          attribute.class("office-canvas"),
          attribute.role("img"),
          attribute.aria_label("Pixel-art office canvas"),
          attribute.aria_describedby("canvas-fallback"),
        ]),
        html.figcaption(
          [attribute.id("canvas-fallback"), attribute.class("canvas-fallback")],
          [html.text("The office canvas will appear here.")],
        ),
      ]),
    ],
  )
}

fn status_region(model: Model, stale: Bool) -> Element(Msg) {
  let connection_feedback = case model.connection_feedback {
    Some(message) ->
      html.p([attribute.class("connection-feedback"), attribute.role("alert")], [
        html.text(message),
      ])
    None -> element.none()
  }
  html.div([attribute.class("status-region")], [
    html.p(
      [
        attribute.class("status-copy"),
        attribute.role("status"),
        attribute.aria_live("polite"),
      ],
      [html.text(connection_status(model, stale))],
    ),
    connection_feedback,
  ])
}

fn participants_panel(snapshot: model.RoomSnapshot) -> Element(Msg) {
  let participant_items =
    list.map(snapshot.participants, fn(presence) {
      let domain.Presence(connection_id, _) = presence
      #(
        domain.connection_id_to_string(connection_id),
        participant_item(presence, snapshot.self_id),
      )
    })
  html.section(
    [
      attribute.class("participants-panel"),
      attribute.aria_labelledby("participants-label"),
    ],
    [
      html.h3([attribute.id("participants-label")], [html.text("Participants")]),
      html.p([attribute.class("participant-count")], [
        html.text(participant_count(snapshot.participants)),
      ]),
      keyed.ul(
        [attribute.class("participant-list"), attribute.role("list")],
        participant_items,
      ),
    ],
  )
}

fn participant_item(
  presence: domain.Presence,
  self_id: domain.ConnectionId,
) -> Element(Msg) {
  let domain.Presence(connection_id, username) = presence
  let self_marker = case connection_id == self_id {
    True ->
      html.span([attribute.class("participant-self")], [html.text(" (You)")])
    False -> element.none()
  }
  html.li([attribute.class("participant-item")], [
    html.span([attribute.class("participant-name")], [html.text(username)]),
    self_marker,
  ])
}

fn participant_count(participants: List(domain.Presence)) -> String {
  let count = list.length(participants)
  case count {
    1 -> "1 participant"
    _ -> int.to_string(count) <> " participants"
  }
}

fn chat_log(snapshot: model.RoomSnapshot) -> Element(Msg) {
  let message_items =
    list.map(snapshot.messages, fn(message) {
      #(
        domain.message_id_to_string(message.message_id),
        chat_message(message, snapshot.self_id),
      )
    })
  let log_contents = case message_items {
    [] -> [
      html.p([attribute.class("empty-chat")], [
        html.text("No messages yet. Start the conversation when you are ready."),
      ]),
    ]
    _ -> [keyed.fragment(message_items)]
  }
  html.section(
    [
      attribute.class("chat-log-panel"),
      attribute.aria_labelledby("chat-log-label"),
    ],
    [
      html.h3([attribute.id("chat-log-label")], [html.text("Messages")]),
      html.div(
        [
          attribute.id("chat-log"),
          attribute.class("message-log"),
          attribute.role("log"),
          attribute.tabindex(0),
          attribute.aria_live("polite"),
          attribute.aria_labelledby("chat-log-label"),
        ],
        log_contents,
      ),
      html.p([attribute.class("history-note")], [
        html.text(
          "Messages are temporary and kept in memory; they may disappear after a backend restart.",
        ),
      ]),
    ],
  )
}

fn chat_message(
  message: domain.ChatMessage,
  self_id: domain.ConnectionId,
) -> Element(Msg) {
  let domain.ChatMessage(_, sender_id, username, text, sent_at) = message
  let self_marker = case sender_id == self_id {
    True -> html.span([attribute.class("message-self")], [html.text(" (You)")])
    False -> element.none()
  }
  html.article([attribute.class("chat-message")], [
    html.header([attribute.class("message-header")], [
      html.span([attribute.class("message-sender")], [html.text(username)]),
      self_marker,
      html.time(
        [
          attribute.class("message-time"),
          attribute.datetime(sent_at),
        ],
        [html.text(browser.format_timestamp_local(sent_at))],
      ),
    ]),
    html.p([attribute.class("message-text")], message_text_nodes(text)),
  ])
}

fn message_text_nodes(text: String) -> List(Element(Msg)) {
  message_lines(string.split(text, on: "\n"))
}

fn message_lines(lines: List(String)) -> List(Element(Msg)) {
  case lines {
    [] -> []
    [line] -> [html.text(line)]
    [line, ..rest] -> [html.text(line), html.br([]), ..message_lines(rest)]
  }
}

fn composer(model: Model) -> Element(Msg) {
  let disabled = !composer_enabled(model)
  let busy = case model.send_in_flight {
    Some(_) -> True
    None -> False
  }
  let throttled = case model.rate_limit_until {
    Some(_) -> True
    None -> False
  }
  let send_disabled = disabled || busy || throttled
  let button_label = case busy {
    True -> "Sending…"
    False if disabled -> "Unavailable"
    False if throttled -> "Temporarily throttled"
    False -> "Send message"
  }
  html.form(
    [
      attribute.class("composer"),
      attribute.aria_labelledby("composer-label"),
      attribute.aria_busy(busy),
      event.on_submit(fn(_fields) { update.SubmitMessage }),
    ],
    [
      html.h3([attribute.id("composer-label")], [html.text("Write a message")]),
      html.label([attribute.for("message-draft")], [html.text("Message")]),
      html.textarea(
        [
          attribute.id("message-draft"),
          attribute.name("message"),
          attribute.rows(3),
          attribute.placeholder("Write a plain-text message"),
          attribute.disabled(disabled),
          attribute.aria_describedby(composer_description_ids(model.feedback)),
          event.on_input(update.DraftInput),
          composer_keydown(),
        ],
        model.draft,
      ),
      html.p([attribute.id("composer-help"), attribute.class("field-help")], [
        html.text("Enter sends. Shift+Enter adds a line break."),
      ]),
      feedback_message("composer-feedback", model.feedback),
      html.button(
        [
          attribute.type_("submit"),
          attribute.class("send-button"),
          attribute.disabled(send_disabled),
          attribute.aria_disabled(send_disabled),
        ],
        [html.text(button_label)],
      ),
    ],
  )
}

fn composer_keydown() -> attribute.Attribute(Msg) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)
    use shift_key <- decode.field("shiftKey", decode.bool)
    use is_composing <- decode.field("isComposing", decode.bool)

    case key, shift_key, is_composing {
      "Enter", False, False ->
        decode.success(event.handler(update.SubmitMessage, True, False))
      _, _, _ ->
        decode.failure(
          event.handler(update.SubmitMessage, False, False),
          "plain Enter",
        )
    }
  })
}

fn composer_enabled(model: Model) -> Bool {
  case model.phase, model.room_snapshot {
    model.Joined(generation, self_id), Some(snapshot) ->
      generation == model.socket_generation
      && self_id == snapshot.self_id
      && snapshot.room_id == domain.default_room_id
      && !snapshot.stale
    _, _ -> False
  }
}

fn connection_status(model: Model, stale: Bool) -> String {
  case model.phase {
    model.ChoosingUsername -> "You will join the built-in default office."
    model.Connecting(_, _) if stale -> "Reconnecting to the office…"
    model.Connecting(_, _) -> "Connecting to the office…"
    model.AwaitingRoomState(_, _) if stale ->
      "Reconnecting; waiting for the office snapshot…"
    model.AwaitingRoomState(_, _) -> "Waiting for the office snapshot…"
    model.Joined(_, _) if stale -> "The office view is stale while reconnecting."
    model.Joined(_, _) -> "Joined the default office."
    model.WaitingToReconnect(_, _, _) -> "Connection lost. Reconnecting…"
    model.Blocked(model.ProtocolFailure) -> "The office is unavailable."
    model.Blocked(model.OfficeUnavailable) -> "The office is unavailable."
    model.Blocked(model.RoomFull) -> "The office is full right now."
  }
}

fn feedback_message(id: String, feedback: Option(String)) -> Element(Msg) {
  case feedback {
    None -> element.none()
    Some(message) ->
      html.p(
        [
          attribute.id(id),
          attribute.class("form-feedback"),
          attribute.role("alert"),
        ],
        [html.text(message)],
      )
  }
}

fn username_description_ids(feedback: Option(String)) -> String {
  case feedback {
    Some(_) -> "username-help username-feedback"
    None -> "username-help"
  }
}

fn composer_description_ids(feedback: Option(String)) -> String {
  case feedback {
    Some(_) -> "composer-help composer-feedback"
    None -> "composer-help"
  }
}

fn username_retry_controls(model: Model) -> Element(Msg) {
  case model.phase {
    model.WaitingToReconnect(_, _, _) -> retry_button("Retry now")
    model.Blocked(_) -> retry_button("Retry connection")
    _ -> element.none()
  }
}

fn retry_controls(model: Model) -> Element(Msg) {
  case model.phase {
    model.WaitingToReconnect(_, _, _) -> recovery_buttons("Retry now")
    model.Blocked(_) -> recovery_buttons("Retry connection")
    _ -> element.none()
  }
}

fn recovery_buttons(retry_label: String) -> Element(Msg) {
  html.div([attribute.class("connection-actions")], [
    retry_button(retry_label),
    html.button(
      [attribute.type_("button"), event.on_click(update.ReturnToUsername)],
      [html.text("Return to username")],
    ),
  ])
}

fn retry_button(label: String) -> Element(Msg) {
  html.div([attribute.class("connection-actions")], [
    html.button(
      [attribute.type_("button"), event.on_click(update.RetryRequested)],
      [html.text(label)],
    ),
  ])
}
