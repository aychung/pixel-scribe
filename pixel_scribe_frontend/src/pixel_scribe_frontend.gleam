import lustre
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import pixel_scribe_frontend/model.{type Model}
import pixel_scribe_frontend/update.{type Msg}

pub fn main() {
  let application =
    lustre.application(
      init: fn(_args: Nil) { #(model.initial(), effect.none()) },
      update: update.update,
      view: view,
    )

  case lustre.start(application, "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

fn view(_model: Model) -> Element(Msg) {
  html.div([], [])
}
