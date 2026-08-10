import gleam/float
import gleam/int

const minimum_random = 0.0

const maximum_random = 1.0

/// Return the uncoupled exponential part of the reconnect delay.
///
/// Attempts below zero use the first delay and attempts at or above six use
/// the 30-second cap. A case table keeps the calculation bounded without
/// exponentiating a caller-controlled integer.
pub fn base_delay_ms(attempt: Int) -> Int {
  case attempt {
    attempt if attempt <= 0 -> 500
    1 -> 1000
    2 -> 2000
    3 -> 4000
    4 -> 8000
    5 -> 16_000
    _ -> 30_000
  }
}

/// Return a capped exponential delay with +/-25% jitter.
///
/// The random input is an injected test/runtime value. Values outside [0, 1]
/// are clamped so the result always remains inside the documented jitter
/// bounds. The runtime contract supplies a finite random value.
pub fn delay_ms(attempt: Int, random_unit: Float) -> Int {
  let random_unit = normalize_random(random_unit)
  let jitter_factor = 0.75 +. random_unit *. 0.5
  float.round(int.to_float(base_delay_ms(attempt)) *. jitter_factor)
}

fn normalize_random(random_unit: Float) -> Float {
  float.clamp(random_unit, minimum_random, maximum_random)
}
