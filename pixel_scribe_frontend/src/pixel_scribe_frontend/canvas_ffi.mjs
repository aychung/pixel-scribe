const CANVAS_ID = "office-canvas";

const CANVAS_UNAVAILABLE = 0;
const CONTEXT_UNAVAILABLE = 1;
const RESIZE_OBSERVER_UNAVAILABLE = 2;
const GEOMETRY_UNAVAILABLE = 3;
const INITIALIZATION_FAILED = 4;
const FAILED = Symbol("canvas-ffi-failed");

let activeRenderer = null;

function safeCall(callback, ...arguments_) {
  try {
    if (typeof callback === "function") callback(...arguments_);
  } catch (_) {
    // Application callbacks must not tear down the browser observer.
  }
}

function readProperty(target, name) {
  if (target === null || target === undefined) return FAILED;
  try {
    return target[name];
  } catch (_) {
    return FAILED;
  }
}

function call(target, name, ...arguments_) {
  const method = readProperty(target, name);
  if (typeof method !== "function") return FAILED;
  try {
    return method.apply(target, arguments_);
  } catch (_) {
    return FAILED;
  }
}

function browserObject(name) {
  const value = readProperty(globalThis, name);
  return value !== FAILED && typeof value === "object" ? value : null;
}

function readDpr() {
  const browser = browserObject("window");
  if (!browser) return 1;

  const value = readProperty(browser, "devicePixelRatio");
  if (value === FAILED) return null;

  try {
    if (!Number.isFinite(value)) return 1;
    return value > 0 ? value : 1;
  } catch (_) {
    return null;
  }
}

function finiteDimension(value) {
  try {
    return Number.isFinite(value) && value >= 0 ? value : null;
  } catch (_) {
    return null;
  }
}

function contentBox(canvas, entry) {
  let rect = null;
  if (entry !== null && entry !== undefined) {
    rect = readProperty(entry, "contentRect");
    if (rect === FAILED) return null;
  }
  if (!rect) {
    rect = call(canvas, "getBoundingClientRect");
    if (rect === FAILED) return null;
  }

  const widthValue = readProperty(rect, "width");
  const heightValue = readProperty(rect, "height");
  if (widthValue === FAILED || heightValue === FAILED) return null;

  const width = finiteDimension(widthValue);
  const height = finiteDimension(heightValue);
  return width === null || height === null ? null : { width, height };
}

function report(state, code) {
  if (state && !state.disposed) safeCall(state.onError, code);
}

function failRenderer(state, code) {
  report(state, code);
  disposeRenderer(state);
}

function removeDprListener(state) {
  const media = state.dprMedia;
  const listener = state.dprListener;
  state.dprMedia = null;
  state.dprListener = null;
  if (!media || !listener) return;

  if (call(media, "removeEventListener", "change", listener) === FAILED) {
    call(media, "removeListener", listener);
  }
}

function installDprListener(state) {
  const browser = browserObject("window");
  if (!browser) return true;

  const matchMedia = readProperty(browser, "matchMedia");
  if (matchMedia === FAILED) return false;
  if (typeof matchMedia !== "function") return true;

  const media = call(browser, "matchMedia", `(resolution: ${readDpr() ?? 1}dppx)`);
  if (media === FAILED) return false;

  const listener = () => {
    if (activeRenderer !== state || state.disposed) return;
    removeDprListener(state);
    if (!installDprListener(state)) {
      failRenderer(state, INITIALIZATION_FAILED);
      return;
    }
    measureAndApply(state, null, false);
  };

  const addEventListener = readProperty(media, "addEventListener");
  if (addEventListener === FAILED) return false;
  if (typeof addEventListener === "function") {
    if (call(media, "addEventListener", "change", listener) === FAILED) {
      if (call(media, "addListener", listener) === FAILED) return false;
    }
  } else {
    const addListener = readProperty(media, "addListener");
    if (addListener === FAILED) return false;
    if (typeof addListener !== "function") return true;
    if (call(media, "addListener", listener) === FAILED) return false;
  }

  state.dprMedia = media;
  state.dprListener = listener;
  return true;
}

function measureAndApply(state, entry, initial) {
  if (state.disposed || activeRenderer !== state) return;

  const size = contentBox(state.canvas, entry);
  if (!size) {
    failRenderer(state, GEOMETRY_UNAVAILABLE);
    return;
  }

  const dpr = readDpr();
  if (dpr === null) {
    failRenderer(state, INITIALIZATION_FAILED);
    return;
  }

  const deviceWidth = Math.max(1, Math.round(size.width * dpr));
  const deviceHeight = Math.max(1, Math.round(size.height * dpr));
  const changed =
    state.cssWidth !== size.width ||
    state.cssHeight !== size.height ||
    state.dpr !== dpr ||
    state.deviceWidth !== deviceWidth ||
    state.deviceHeight !== deviceHeight;

  if (!initial && !changed) return;

  try {
    state.canvas.width = deviceWidth;
    state.canvas.height = deviceHeight;
  } catch (_) {
    failRenderer(state, INITIALIZATION_FAILED);
    return;
  }
  if (call(state.context, "setTransform", dpr, 0, 0, dpr, 0, 0) === FAILED) {
    failRenderer(state, INITIALIZATION_FAILED);
    return;
  }

  state.cssWidth = size.width;
  state.cssHeight = size.height;
  state.dpr = dpr;
  state.deviceWidth = deviceWidth;
  state.deviceHeight = deviceHeight;

  safeCall(initial ? state.onReady : state.onResize, Math.round(size.width), Math.round(size.height), dpr);
}

function disposeRenderer(state) {
  if (!state) return;
  if (state.disposed) {
    if (activeRenderer === state) activeRenderer = null;
    return;
  }

  state.disposed = true;
  if (activeRenderer === state) activeRenderer = null;

  const observer = state.observer;
  state.observer = null;
  call(observer, "disconnect");

  const browser = browserObject("window");
  const windowResizeListener = state.windowResizeListener;
  state.windowResizeListener = null;
  call(browser, "removeEventListener", "resize", windowResizeListener);

  removeDprListener(state);

  const pendingFrame = state.pendingFrame;
  state.pendingFrame = null;
  if (pendingFrame !== null) call(globalThis, "cancelAnimationFrame", pendingFrame);

  const imageReferences = state.imageReferences;
  state.imageReferences = null;
  call(imageReferences, "clear");

  state.canvas = null;
  state.context = null;
  state.onReady = null;
  state.onResize = null;
  state.onError = null;
}

export function initialize_canvas(onReady, onResize, onError) {
  const documentObject = browserObject("document");
  if (!documentObject) {
    safeCall(onError, CANVAS_UNAVAILABLE);
    return;
  }

  const canvas = call(documentObject, "getElementById", CANVAS_ID);
  if (canvas === FAILED || !canvas) {
    safeCall(onError, CANVAS_UNAVAILABLE);
    return;
  }

  if (activeRenderer && activeRenderer.canvas === canvas && !activeRenderer.disposed) {
    activeRenderer.onReady = onReady;
    activeRenderer.onResize = onResize;
    activeRenderer.onError = onError;
    measureAndApply(activeRenderer, null, true);
    return;
  }

  disposeRenderer(activeRenderer);

  const context = call(canvas, "getContext", "2d");
  if (context === FAILED || !context) {
    safeCall(onError, CONTEXT_UNAVAILABLE);
    return;
  }

  const state = {
    canvas,
    context,
    onReady,
    onResize,
    onError,
    observer: null,
    dprMedia: null,
    dprListener: null,
    windowResizeListener: null,
    pendingFrame: null,
    imageReferences: new Set(),
    cssWidth: null,
    cssHeight: null,
    dpr: null,
    deviceWidth: null,
    deviceHeight: null,
    disposed: false,
  };
  activeRenderer = state;

  try {
    const ResizeObserverConstructor = readProperty(globalThis, "ResizeObserver");
    if (typeof ResizeObserverConstructor !== "function") {
      failRenderer(state, RESIZE_OBSERVER_UNAVAILABLE);
      return;
    }

    state.observer = new ResizeObserverConstructor((entries) => {
      let entry;
      try {
        entry = entries?.[entries.length - 1];
      } catch (_) {
        failRenderer(state, GEOMETRY_UNAVAILABLE);
        return;
      }
      measureAndApply(state, entry, false);
    });
    if (call(state.observer, "observe", canvas, { box: "content-box" }) === FAILED) {
      failRenderer(state, RESIZE_OBSERVER_UNAVAILABLE);
      return;
    }

    const browser = browserObject("window");
    if (browser) {
      state.windowResizeListener = () => measureAndApply(state, null, false);
      if (
        call(browser, "addEventListener", "resize", state.windowResizeListener, {
          passive: true,
        }) === FAILED
      ) {
        failRenderer(state, INITIALIZATION_FAILED);
        return;
      }
    }
    if (!installDprListener(state)) {
      failRenderer(state, INITIALIZATION_FAILED);
      return;
    }
    measureAndApply(state, null, true);
  } catch (_) {
    failRenderer(state, INITIALIZATION_FAILED);
  }
}

export function dispose_canvas() {
  disposeRenderer(activeRenderer);
}
