import exception
import gleam/option.{Some}
import gleam/string
import gleam/time/timestamp
import pixel_scribe_backend/integration_support as support

pub fn entry_page_and_static_assets_are_served_by_live_server_test() {
  let server =
    support.start_server(
      static_fixture_directory(),
      Some("https://example.test"),
      [],
    )

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let entry_page = support.get_http(support.server_port(server), "/")
    assert entry_page.status == 200
    assert support.response_header(entry_page.headers, "content-type")
      == Ok("text/html; charset=utf-8")
    assert support.response_header(entry_page.headers, "x-content-type-options")
      == Ok("nosniff")
    assert support.response_header(entry_page.headers, "x-frame-options")
      == Ok("DENY")
    assert string.contains(entry_page.body, "<title>Pixel Scribe</title>")

    let stylesheet =
      support.get_http(support.server_port(server), "/styles.css")
    assert stylesheet.status == 200
    assert support.response_header(stylesheet.headers, "content-type")
      == Ok("text/css; charset=utf-8")
    assert string.contains(stylesheet.body, "--chat-rail-width")

    let bundle =
      support.get_http(support.server_port(server), "/pixel_scribe_frontend.js")
    assert bundle.status == 200
    assert support.response_header(bundle.headers, "content-type")
      == Ok("text/javascript; charset=utf-8")
    assert string.contains(bundle.body, "Pixel Scribe")

    let missing_asset =
      support.get_http(support.server_port(server), "/missing.js")
    assert missing_asset.status == 404
  })
}

pub fn two_clients_complete_the_mvp_lifecycle_test() {
  let server =
    support.start_server(
      static_fixture_directory(),
      Some("https://example.test"),
      [],
    )

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let first =
      support.connect_websocket(
        support.server_port(server),
        "example.test",
        "https://example.test",
      )

    exception.defer(fn() { support.close_client(first) }, fn() {
      support.send_join(first, "Ada")
      let assert Ok(#(first_payload, first)) = support.read_frame(first, 1000)
      let assert Ok(first_state) = support.decode_room_state(first_payload)

      assert first_state.room_id == "default"
      assert first_state.self_id != ""
      assert first_state.users
        == [support.WirePresence(first_state.self_id, "Ada")]
      assert first_state.messages == []

      let second =
        support.connect_websocket(
          support.server_port(server),
          "example.test",
          "https://example.test",
        )

      exception.defer(fn() { support.close_client(second) }, fn() {
        support.send_join(second, "Grace")
        let assert Ok(#(second_payload, second)) =
          support.read_frame(second, 1000)
        let assert Ok(second_state) = support.decode_room_state(second_payload)

        assert second_state.room_id == "default"
        assert second_state.self_id != first_state.self_id
        assert second_state.users
          == [
            support.WirePresence(first_state.self_id, "Ada"),
            support.WirePresence(second_state.self_id, "Grace"),
          ]
        assert second_state.messages == []

        let assert Ok(#(joined_payload, first)) =
          support.read_frame(first, 1000)
        let assert Ok(joined) = support.decode_user_joined(joined_payload)
        assert joined.room_id == "default"
        assert joined.user
          == support.WirePresence(second_state.self_id, "Grace")
        assert support.read_frame(first, 50) == Error(Nil)

        support.send_message(first, "Hello from Ada")
        let assert Ok(#(first_message_payload, first)) =
          support.read_frame(first, 1000)
        let assert Ok(#(second_message_payload, second)) =
          support.read_frame(second, 1000)
        let assert Ok(first_message) =
          support.decode_message_sent(first_message_payload)
        let assert Ok(second_message) =
          support.decode_message_sent(second_message_payload)

        assert first_message == second_message
        assert first_message.room_id == "default"
        assert first_message.message.message_id != ""
        assert first_message.message.sender_id == first_state.self_id
        assert first_message.message.username == "Ada"
        assert first_message.message.text == "Hello from Ada"
        assert first_message.message.sent_at != ""
        let assert Ok(_) =
          timestamp.parse_rfc3339(first_message.message.sent_at)
        assert support.read_frame(first, 50) == Error(Nil)
        assert support.read_frame(second, 50) == Error(Nil)

        support.close_client(second)
        let assert Ok(#(left_payload, first)) = support.read_frame(first, 1000)
        let assert Ok(left) = support.decode_user_left(left_payload)
        assert left.room_id == "default"
        assert left.connection_id == second_state.self_id
        assert support.read_frame(first, 50) == Error(Nil)

        let reconnect =
          support.connect_websocket(
            support.server_port(server),
            "example.test",
            "https://example.test",
          )

        exception.defer(fn() { support.close_client(reconnect) }, fn() {
          support.send_join(reconnect, "Grace")
          let assert Ok(#(reconnect_payload, _reconnect)) =
            support.read_frame(reconnect, 1000)
          let assert Ok(reconnect_state) =
            support.decode_room_state(reconnect_payload)

          assert reconnect_state.room_id == "default"
          assert reconnect_state.self_id != second_state.self_id
          assert reconnect_state.self_id != first_state.self_id
          assert reconnect_state.users
            == [
              support.WirePresence(first_state.self_id, "Ada"),
              support.WirePresence(reconnect_state.self_id, "Grace"),
            ]
          assert reconnect_state.messages == [first_message.message]

          let assert Ok(#(rejoined_payload, first)) =
            support.read_frame(first, 1000)
          let assert Ok(rejoined) = support.decode_user_joined(rejoined_payload)
          assert rejoined.room_id == "default"
          assert rejoined.user
            == support.WirePresence(reconnect_state.self_id, "Grace")
          assert support.read_frame(first, 50) == Error(Nil)
        })
      })
    })
  })
}

pub fn proxied_https_origin_is_accepted_by_configured_handler_test() {
  let server =
    support.start_server(
      static_fixture_directory(),
      Some("https://example.test"),
      [],
    )

  exception.defer(fn() { support.stop_server(server) }, fn() {
    let client =
      support.connect_websocket(
        support.server_port(server),
        "example.test",
        "https://example.test",
      )
    support.close_client(client)
  })
}

pub fn mismatched_origin_is_rejected_by_configured_handler_test() {
  let server =
    support.start_server(
      static_fixture_directory(),
      Some("https://example.test"),
      [],
    )

  exception.defer(fn() { support.stop_server(server) }, fn() {
    assert support.websocket_status(
        support.server_port(server),
        "example.test",
        "https://evil.example",
      )
      == 403
  })
}

fn static_fixture_directory() -> String {
  "test/fixtures/public"
}
