import gleam/option.{type Option, Some}
import lustre
import lustre/effect
import lustre/element
import pixel_scribe_frontend/browser
import pixel_scribe_frontend/model
import pixel_scribe_frontend/runtime
import pixel_scribe_frontend/update
import pixel_scribe_frontend/view as app_view

type AppMsg {
  BrowserReady(Option(String), Int, Bool)
  Application(update.Msg)
}

pub fn main() {
  let application =
    lustre.application(
      init: fn(_args: Nil) { #(model.initial(), startup_effect()) },
      update: app_update,
      view: view,
    )

  case lustre.start(application, "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

fn startup_effect() -> effect.Effect(AppMsg) {
  effect.from(fn(dispatch) {
    dispatch(BrowserReady(
      browser.read_username_preference(),
      browser.page_seed(),
      browser.prefers_reduced_motion(),
    ))
  })
}

fn app_update(
  model: model.Model,
  message: AppMsg,
) -> #(model.Model, effect.Effect(AppMsg)) {
  case message {
    BrowserReady(preference, seed, reduced_motion) -> #(
      update.set_reduced_motion(
        update.apply_browser_startup(model, preference, seed),
        reduced_motion,
      ),
      effect.none(),
    )
    Application(message) -> {
      let #(updated, next_effect) = runtime.update(model, message)
      let focus_effect = case message, model.phase, updated.feedback {
        update.SubmitUsername, model.ChoosingUsername, Some(_) ->
          browser.focus_username()
        _, _, _ -> effect.none()
      }
      #(
        updated,
        effect.batch([
          effect.map(next_effect, Application),
          focus_effect,
        ]),
      )
    }
  }
}

fn view(model: model.Model) -> element.Element(AppMsg) {
  element.map(app_view.view(model), Application)
}
