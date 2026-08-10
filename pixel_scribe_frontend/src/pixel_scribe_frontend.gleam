import lustre
import lustre/effect
import pixel_scribe_frontend/model
import pixel_scribe_frontend/update
import pixel_scribe_frontend/view as app_view

pub fn main() {
  let application =
    lustre.application(
      init: fn(_args: Nil) { #(model.initial(), effect.none()) },
      update: update.update,
      view: app_view.view,
    )

  case lustre.start(application, "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}
