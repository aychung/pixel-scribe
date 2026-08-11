import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Pid}
import gleam/list
import gleam/result
import pixel_scribe_backend/supervisor

const test_key_base = "0123456789012345678901234567890123456789012345678901234567890123"

type ChildPids {
  ChildPids(directory: Pid, factory: Pid, web: Pid)
}

pub fn directory_failure_restarts_directory_factory_and_web_test() {
  let root = start_root()
  let before = child_pids(root)
  let after = case before {
    Ok(before) -> {
      process.kill(before.directory)
      wait_for_children(root, fn(after) { all_restarted(before, after) }, 1000)
    }
    Error(Nil) -> Error(Nil)
  }
  stop_root(root)

  let assert Ok(before) = before
  let assert Ok(after) = after
  assert after.directory != before.directory
  assert after.factory != before.factory
  assert after.web != before.web
}

pub fn factory_failure_keeps_directory_and_restarts_factory_and_web_test() {
  let root = start_root()
  let before = child_pids(root)
  let after = case before {
    Ok(before) -> {
      process.kill(before.factory)
      wait_for_children(
        root,
        fn(after) { factory_and_web_restarted(before, after) },
        1000,
      )
    }
    Error(Nil) -> Error(Nil)
  }
  stop_root(root)

  let assert Ok(before) = before
  let assert Ok(after) = after
  assert after.directory == before.directory
  assert after.factory != before.factory
  assert after.web != before.web
}

pub fn startup_configuration_rejects_invalid_values_test() {
  assert supervisor.startup_configuration(-1) == Error(Nil)
  assert supervisor.startup_configuration(65_536) == Error(Nil)
  assert supervisor.startup_configuration_with_bind_address(
      0,
      "127.0.0.1; touch /tmp/pwned",
    )
    == Error(Nil)
}

pub fn startup_configuration_accepts_ephemeral_test_values_test() {
  assert supervisor.startup_configuration(0) != Error(Nil)
  assert supervisor.startup_configuration_with_bind_address(0, "0.0.0.0")
    != Error(Nil)
}

fn start_root() -> Pid {
  let assert Ok(started) = supervisor.start(0, test_key_base)
  process.unlink(started.pid)
  started.pid
}

fn stop_root(root: Pid) -> Nil {
  let _ = stop_supervisor(root)
  Nil
}

fn wait_for_children(
  root: Pid,
  matches: fn(ChildPids) -> Bool,
  attempts: Int,
) -> Result(ChildPids, Nil) {
  case child_pids(root) {
    Ok(children) ->
      case matches(children) {
        True -> Ok(children)
        False -> retry_wait(root, matches, attempts)
      }
    Error(Nil) -> retry_wait(root, matches, attempts)
  }
}

fn retry_wait(
  root: Pid,
  matches: fn(ChildPids) -> Bool,
  attempts: Int,
) -> Result(ChildPids, Nil) {
  case attempts {
    _ if attempts > 0 -> {
      process.sleep(1)
      wait_for_children(root, matches, attempts - 1)
    }
    _ -> Error(Nil)
  }
}

fn all_restarted(before: ChildPids, after: ChildPids) -> Bool {
  after.directory != before.directory
  && after.factory != before.factory
  && after.web != before.web
}

fn factory_and_web_restarted(before: ChildPids, after: ChildPids) -> Bool {
  after.directory == before.directory
  && after.factory != before.factory
  && after.web != before.web
}

fn child_pids(root: Pid) -> Result(ChildPids, Nil) {
  let children = which_children(root)
  // start/2 adds directory, factory, and web as child IDs 0, 1, and 2.
  use directory <- result.try(child_pid(children, 0))
  use factory <- result.try(child_pid(children, 1))
  use web <- result.try(child_pid(children, 2))
  Ok(ChildPids(directory:, factory:, web:))
}

fn child_pid(
  children: List(#(Int, Dynamic, Dynamic, Dynamic)),
  id: Int,
) -> Result(Pid, Nil) {
  use child <- result.try(list.find(children, fn(child) { child.0 == id }))
  pid_from_dynamic(child.1)
}

fn pid_from_dynamic(value: Dynamic) -> Result(Pid, Nil) {
  case is_pid(value) {
    True -> {
      let pid = cast_pid(value)
      case process.is_alive(pid) {
        True -> Ok(pid)
        False -> Error(Nil)
      }
    }
    False -> Error(Nil)
  }
}

@external(erlang, "supervisor", "which_children")
fn which_children(root: Pid) -> List(#(Int, Dynamic, Dynamic, Dynamic))

@external(erlang, "supervisor", "stop")
fn stop_supervisor(root: Pid) -> Dynamic

@external(erlang, "erlang", "is_pid")
fn is_pid(value: Dynamic) -> Bool

@external(erlang, "gleam_erlang_ffi", "identity")
fn cast_pid(value: Dynamic) -> Pid
