const USERNAME_COOKIE_PREFIX = "pixel_scribe_username=";

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
