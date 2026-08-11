const USERNAME_COOKIE_PREFIX = "pixel_scribe_username=";

const USERNAME_INPUT_ID = "username";
const COMPOSER_ID = "message-draft";
const CHAT_LOG_ID = "chat-log";

// Keep the auto-scroll affordance conservative: a reader within 24 CSS pixels
// of the end is treated as following new messages, while older content remains
// anchored once they are farther away.
const CHAT_LOG_NEAR_BOTTOM_PX = 24;

// A timer is owned by its kind and opaque identity. Its generation is retained
// on the entry for cancellation checks and callback dispatch. Keeping the
// entry object in the map lets a callback prove it is still the currently
// registered timer even if clearTimeout cannot prevent an already queued
// callback.
const timerHandles = new Map();

function timerKey(timerKind, timerId) {
  return `${timerKind}:${timerId}`;
}

function validTimerArguments(timerKind, generation, timerId) {
  return (
    Number.isSafeInteger(timerKind) &&
    timerKind >= 0 &&
    timerKind <= 2 &&
    Number.isSafeInteger(generation) &&
    Number.isSafeInteger(timerId)
  );
}

export function schedule_timer(timerKind, generation, timerId, delayMs, callback) {
  if (
    !validTimerArguments(timerKind, generation, timerId) ||
    !Number.isSafeInteger(delayMs) ||
    delayMs < 0 ||
    typeof callback !== "function" ||
    typeof globalThis.setTimeout !== "function"
  ) {
    return undefined;
  }

  const key = timerKey(timerKind, timerId);
  const previous = timerHandles.get(key);
  if (previous !== undefined) {
    try {
      globalThis.clearTimeout(previous.handle);
    } catch (_error) {
      // A missing or replaced browser timer is already safe to discard.
    }
    timerHandles.delete(key);
  }

  const entry = { generation, handle: undefined };
  timerHandles.set(key, entry);

  try {
    entry.handle = globalThis.setTimeout(() => {
      if (timerHandles.get(key) !== entry) {
        return;
      }

      // Remove before dispatching so a callback that triggers cleanup cannot
      // accidentally cancel or retain an already-fired handle.
      timerHandles.delete(key);
      callback(generation, timerId);
    }, delayMs);
  } catch (_error) {
    timerHandles.delete(key);
  }

  return undefined;
}

export function cancel_timer(timerKind, generation, timerId) {
  if (
    !validTimerArguments(timerKind, generation, timerId)
  ) {
    return undefined;
  }

  const key = timerKey(timerKind, timerId);
  const entry = timerHandles.get(key);
  if (entry === undefined || entry.generation !== generation) {
    return undefined;
  }

  timerHandles.delete(key);
  if (typeof globalThis.clearTimeout === "function") {
    try {
      globalThis.clearTimeout(entry.handle);
    } catch (_error) {
      // Cleanup is idempotent even if the browser rejects an old handle.
    }
  }

  return undefined;
}

function fixedElement(id) {
  try {
    if (
      typeof document === "undefined" ||
      typeof document.getElementById !== "function"
    ) {
      return undefined;
    }

    return document.getElementById(id) ?? undefined;
  } catch (_error) {
    return undefined;
  }
}

function focusFixedElement(id) {
  const element = fixedElement(id);
  if (element === undefined || typeof element.focus !== "function") {
    return;
  }

  try {
    element.focus();
  } catch (_error) {
    // A removed or non-focusable target is safe to ignore.
  }
}

export function focus_username() {
  focusFixedElement(USERNAME_INPUT_ID);
  return undefined;
}

export function focus_composer() {
  focusFixedElement(COMPOSER_ID);
  return undefined;
}

export function scroll_chat_to_end() {
  const element = fixedElement(CHAT_LOG_ID);
  if (element === undefined) {
    return undefined;
  }

  try {
    const scrollTop = element.scrollTop;
    const scrollHeight = element.scrollHeight;
    const clientHeight = element.clientHeight;
    if (!validScrollMetrics(scrollTop, scrollHeight, clientHeight)) {
      return undefined;
    }

    element.scrollTop = scrollHeight;
  } catch (_error) {
    // A removed, non-scrollable, or malformed target is safe to ignore.
  }

  return undefined;
}

function validScrollMetric(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function validScrollMetrics(scrollTop, scrollHeight, clientHeight) {
  return (
    validScrollMetric(scrollTop) &&
    validScrollMetric(scrollHeight) &&
    validScrollMetric(clientHeight) &&
    scrollHeight >= clientHeight &&
    scrollTop <= scrollHeight
  );
}

export function chat_log_near_bottom() {
  const element = fixedElement(CHAT_LOG_ID);
  if (element === undefined) {
    return false;
  }

  try {
    const scrollTop = element.scrollTop;
    const scrollHeight = element.scrollHeight;
    const clientHeight = element.clientHeight;
    if (!validScrollMetrics(scrollTop, scrollHeight, clientHeight)) {
      return false;
    }

    const distanceFromBottom = scrollHeight - clientHeight - scrollTop;
    return distanceFromBottom <= CHAT_LOG_NEAR_BOTTOM_PX;
  } catch (_error) {
    return false;
  }
}

export function read_document_cookie() {
  try {
    if (typeof document === "undefined") {
      return "";
    }

    const cookie = document.cookie;
    return typeof cookie === "string" ? cookie : "";
  } catch (_error) {
    return "";
  }
}

export function write_username_cookie(serializedCookie) {
  if (
    typeof serializedCookie !== "string" ||
    !serializedCookie.startsWith(USERNAME_COOKIE_PREFIX)
  ) {
    return undefined;
  }

  try {
    if (typeof document !== "undefined") {
      document.cookie = serializedCookie;
    }
  } catch (_error) {
    // Cookie writes can be rejected by browser policy; the preference is best effort.
  }

  return undefined;
}

export function is_https() {
  try {
    return globalThis.location?.protocol === "https:";
  } catch (_error) {
    return false;
  }
}

export function generate_page_seed() {
  try {
    const crypto = globalThis.crypto;
    if (crypto === undefined || typeof crypto.getRandomValues !== "function") {
      return 0;
    }

    const values = new Uint32Array(1);
    crypto.getRandomValues(values);
    return values[0];
  } catch (_error) {
    return 0;
  }
}

export function format_timestamp_local(timestamp) {
  if (typeof timestamp !== "string") {
    return "";
  }

  try {
    const dateConstructor = globalThis.Date;
    const intl = globalThis.Intl;
    if (
      typeof dateConstructor !== "function" ||
      intl === undefined ||
      typeof intl.DateTimeFormat !== "function"
    ) {
      return timestamp;
    }

    const date = new dateConstructor(timestamp);
    if (
      date === undefined ||
      typeof date.getTime !== "function" ||
      Number.isNaN(date.getTime())
    ) {
      return timestamp;
    }

    const formatter = new intl.DateTimeFormat(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
    const formatted = formatter.format(date);
    return typeof formatted === "string" && formatted.length > 0
      ? formatted
      : timestamp;
  } catch (_error) {
    return timestamp;
  }
}
