// Native WebSocket handles are intentionally private to this module. Gleam
// owns the application model; this map owns only browser socket lifetimes.
const sockets = new Map();

function validGeneration(generation) {
  return Number.isSafeInteger(generation) && generation >= 0;
}

function validText(value) {
  return typeof value === "string";
}

function invoke(callback, ...args) {
  if (typeof callback !== "function") {
    return;
  }

  try {
    callback(...args);
  } catch (_error) {
    // A callback cannot be allowed to prevent native listener cleanup.
  }
}

function current(entry) {
  return sockets.get(entry.generation) === entry;
}

function removeListeners(entry) {
  if (entry.cleaned) {
    return;
  }

  entry.cleaned = true;
  try {
    entry.socket.removeEventListener("open", entry.onOpen);
    entry.socket.removeEventListener("message", entry.onMessage);
    entry.socket.removeEventListener("error", entry.onError);
    entry.socket.removeEventListener("close", entry.onClose);
  } catch (_error) {
    // A partially constructed or already-disposed socket is safe to discard.
  }

  if (sockets.get(entry.generation) === entry) {
    sockets.delete(entry.generation);
  }
}

function closeReplaced(entry) {
  entry.deliberate = true;
  removeListeners(entry);

  try {
    entry.socket.close(1000, "replaced");
  } catch (_error) {
    // Replacement cleanup is idempotent even when close races construction.
  }
}

export function location_protocol() {
  try {
    const protocol = globalThis.location?.protocol;
    return typeof protocol === "string" ? protocol : "http:";
  } catch (_error) {
    return "http:";
  }
}

export function location_host() {
  try {
    const host = globalThis.location?.host;
    return typeof host === "string" ? host : "";
  } catch (_error) {
    return "";
  }
}

export function now_ms() {
  try {
    const value = Date.now();
    return Number.isSafeInteger(value) ? value : 0;
  } catch (_error) {
    return 0;
  }
}

export function random_unit() {
  try {
    const cryptoObject = globalThis.crypto;
    if (typeof cryptoObject?.getRandomValues === "function") {
      const values = new Uint32Array(1);
      cryptoObject.getRandomValues(values);
      return values[0] / 4294967295;
    }

    const value = Math.random();
    return Number.isFinite(value) && value >= 0 && value <= 1 ? value : 0.5;
  } catch (_error) {
    return 0.5;
  }
}

export function open_socket(
  generation,
  url,
  onOpen,
  onMessage,
  onNonTextFrame,
  onError,
  onClose,
) {
  if (
    !validGeneration(generation) ||
    !validText(url) ||
    typeof onOpen !== "function" ||
    typeof onMessage !== "function" ||
    typeof onNonTextFrame !== "function" ||
    typeof onError !== "function" ||
    typeof onClose !== "function"
  ) {
    return undefined;
  }

  const previous = sockets.get(generation);
  if (previous !== undefined) {
    closeReplaced(previous);
  }

  const WebSocketConstructor = globalThis.WebSocket;
  if (typeof WebSocketConstructor !== "function") {
    invoke(onError, generation);
    invoke(onClose, generation, false);
    return undefined;
  }

  let nativeSocket;
  try {
    nativeSocket = new WebSocketConstructor(url);
  } catch (_error) {
    invoke(onError, generation);
    invoke(onClose, generation, false);
    return undefined;
  }

  const entry = {
    generation,
    socket: nativeSocket,
    deliberate: false,
    cleaned: false,
    onOpen: undefined,
    onMessage: undefined,
    onError: undefined,
    onClose: undefined,
  };

  entry.onOpen = () => {
    if (current(entry)) {
      invoke(onOpen, generation);
    }
  };

  entry.onMessage = (event) => {
    if (!current(entry)) {
      return;
    }

    if (typeof event?.data === "string") {
      invoke(onMessage, generation, event.data);
    } else {
      invoke(onNonTextFrame, generation);
    }
  };

  entry.onError = () => {
    if (current(entry)) {
      invoke(onError, generation);
    }
  };

  entry.onClose = () => {
    if (!current(entry)) {
      return;
    }

    const deliberate = entry.deliberate;
    removeListeners(entry);
    invoke(onClose, generation, deliberate);
  };

  sockets.set(generation, entry);

  try {
    nativeSocket.addEventListener("open", entry.onOpen);
    nativeSocket.addEventListener("message", entry.onMessage);
    nativeSocket.addEventListener("error", entry.onError);
    nativeSocket.addEventListener("close", entry.onClose);
  } catch (_error) {
    removeListeners(entry);
    try {
      nativeSocket.close(1000, "listener setup failed");
    } catch (_closeError) {
      // The failed socket is already unavailable to the application.
    }
    invoke(onError, generation);
    invoke(onClose, generation, false);
  }

  return undefined;
}

export function send_socket(generation, text) {
  if (!validGeneration(generation) || !validText(text)) {
    return undefined;
  }

  const entry = sockets.get(generation);
  if (entry === undefined || entry.cleaned) {
    return undefined;
  }

  const openState = globalThis.WebSocket?.OPEN;
  if (typeof openState !== "number" || entry.socket.readyState !== openState) {
    return undefined;
  }

  try {
    entry.socket.send(text);
  } catch (_error) {
    // A close can race the readyState check; no payload is logged or retried.
  }

  return undefined;
}

export function close_socket(generation) {
  if (!validGeneration(generation)) {
    return undefined;
  }

  const entry = sockets.get(generation);
  if (entry === undefined || entry.cleaned) {
    return undefined;
  }

  entry.deliberate = true;

  try {
    entry.socket.close(1000, "client closed");
  } catch (_error) {
    // Run the normal close path before removing the entry so the deliberate
    // close fact is still delivered when the native close call rejects.
    invoke(entry.onClose);
  }

  return undefined;
}
