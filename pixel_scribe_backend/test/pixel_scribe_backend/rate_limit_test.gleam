import pixel_scribe_backend/rate_limit

pub fn five_message_burst_is_allowed_then_sixth_is_rejected_test() {
  let bucket = rate_limit.new(0)

  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Rejected(_) = rate_limit.consume(bucket, 0)
}

pub fn one_token_refills_after_one_second_test() {
  let bucket = rate_limit.new(0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)

  let assert rate_limit.Rejected(bucket) = rate_limit.consume(bucket, 999)
  let assert rate_limit.Allowed(_) = rate_limit.consume(bucket, 1000)
}

pub fn fractional_refill_time_is_preserved_test() {
  let bucket = rate_limit.new(0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 0)

  let assert rate_limit.Rejected(bucket) = rate_limit.consume(bucket, 500)
  let assert rate_limit.Allowed(bucket) = rate_limit.consume(bucket, 1000)
  let assert rate_limit.Rejected(_) = rate_limit.consume(bucket, 1999)
  let assert rate_limit.Allowed(_) = rate_limit.consume(bucket, 2000)
}
