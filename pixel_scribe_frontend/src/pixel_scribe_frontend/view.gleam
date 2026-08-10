import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import pixel_scribe_frontend/model.{type Model}
import pixel_scribe_frontend/update.{type Msg}

pub fn view(model: Model) -> Element(Msg) {
  html.main([attribute.class("app-shell")], [
    html.header([attribute.class("app-header")], [
      html.h1([], [html.text("Pixel Scribe")]),
      html.p([attribute.class("app-introduction")], [
        html.text("A small virtual office for focused conversations."),
      ]),
    ]),
    html.div([attribute.class("workspace-shell")], [
      office_preview(),
      username_panel(model.username_input, model.feedback),
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

fn username_panel(
  username_input: String,
  feedback: Option(String),
) -> Element(Msg) {
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
            attribute.value(username_input),
            attribute.required(True),
            attribute.aria_describedby("username-help username-feedback"),
            event.on_input(update.UsernameInput),
          ]),
          html.p(
            [attribute.id("username-help"), attribute.class("field-help")],
            [html.text("Use 1–32 characters. Spaces and emoji are welcome.")],
          ),
          feedback_message(feedback),
          html.button(
            [attribute.type_("submit"), attribute.class("join-button")],
            [html.text("Enter the office")],
          ),
        ],
      ),
      html.p([attribute.class("status-copy"), attribute.role("status")], [
        html.text("You will join the built-in default office."),
      ]),
    ],
  )
}

fn feedback_message(feedback: Option(String)) -> Element(Msg) {
  case feedback {
    None -> element.none()
    Some(message) ->
      html.p(
        [
          attribute.id("username-feedback"),
          attribute.class("form-feedback"),
          attribute.role("alert"),
        ],
        [html.text(message)],
      )
  }
}
