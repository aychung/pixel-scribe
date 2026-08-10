import gleam/erlang/atom
import gleam/int

pub const capacity = 5

const refill_interval_ms = 1000

pub opaque type Bucket {
  Bucket(tokens: Int, last_refill_ms: Int)
}

pub type ConsumeResult {
  Allowed(Bucket)
  Rejected(Bucket)
}

pub fn new(now_ms: Int) -> Bucket {
  Bucket(capacity, now_ms)
}

pub fn consume(bucket: Bucket, now_ms: Int) -> ConsumeResult {
  let Bucket(tokens, last_refill_ms) = bucket
  let #(tokens, last_refill_ms) = refill(tokens, last_refill_ms, now_ms)

  case tokens > 0 {
    True -> Allowed(Bucket(tokens - 1, last_refill_ms))
    False -> Rejected(Bucket(tokens, last_refill_ms))
  }
}

pub fn monotonic_time_ms() -> Int {
  erlang_monotonic_time(atom.create("millisecond"))
}

fn refill(tokens: Int, last_refill_ms: Int, now_ms: Int) -> #(Int, Int) {
  case now_ms > last_refill_ms {
    False -> #(tokens, last_refill_ms)
    True -> {
      let elapsed_ms = now_ms - last_refill_ms
      let refilled = elapsed_ms / refill_interval_ms
      let tokens = int.min(capacity, tokens + refilled)

      case tokens == capacity {
        True -> #(tokens, now_ms)
        False -> #(tokens, last_refill_ms + refilled * refill_interval_ms)
      }
    }
  }
}

@external(erlang, "erlang", "monotonic_time")
fn erlang_monotonic_time(unit: atom.Atom) -> Int
