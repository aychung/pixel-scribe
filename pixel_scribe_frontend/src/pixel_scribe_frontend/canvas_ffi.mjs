const CANVAS_ID = "office-canvas";

const CANVAS_UNAVAILABLE = 0;
const CONTEXT_UNAVAILABLE = 1;
const RESIZE_OBSERVER_UNAVAILABLE = 2;
const GEOMETRY_UNAVAILABLE = 3;
const INITIALIZATION_FAILED = 4;
const ASSET_UNAVAILABLE = 5;
const SCENE_UNAVAILABLE = 6;
const FAILED = Symbol("canvas-ffi-failed");
const TILE_SIZE = 16;
const WORLD_WIDTH = 1536;
const WORLD_HEIGHT = 1024;
const TILE_URL = "/pixel-art/office-tiles-16.png";
const AVATAR_URL = "/pixel-art/office-avatars-16.png";
// This matches the protocol's bounded text-frame scale while leaving room for
// opaque IDs that are longer than the server's generated IDs.
const MAX_RENDER_STRING_LENGTH = 8192;

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

function createImage() {
  const ImageConstructor = readProperty(globalThis, "Image");
  if (typeof ImageConstructor !== "function") return FAILED;
  try {
    return new ImageConstructor();
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
  drawCurrent(state);
}

function reportSceneError(state, code) {
  if (state.sceneErrorReported) return;
  state.sceneErrorReported = true;
  safeCall(state.onSceneError, code);
}

function validScene(payload) {
  if (typeof payload !== "string" || payload.length > 100_000) return null;

  let parsed;
  try {
    parsed = JSON.parse(payload);
  } catch (_) {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || !Array.isArray(parsed.avatars)) {
    return null;
  }
  if (parsed.avatars.length > 50) return null;

  const avatars = [];
  const ids = new Set();
  for (const avatar of parsed.avatars) {
    if (!avatar || typeof avatar !== "object") return null;
    if (
      typeof avatar.id !== "string" ||
      avatar.id.length === 0 ||
      avatar.id.length > MAX_RENDER_STRING_LENGTH ||
      ids.has(avatar.id)
    ) {
      return null;
    }
    if (
      typeof avatar.username !== "string" ||
      avatar.username.length === 0 ||
      avatar.username.length > MAX_RENDER_STRING_LENGTH ||
      /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u.test(avatar.username)
    ) {
      return null;
    }
    if (
      !Number.isSafeInteger(avatar.x) ||
      !Number.isSafeInteger(avatar.y) ||
      avatar.x < -WORLD_WIDTH ||
      avatar.x > WORLD_WIDTH * 2 ||
      avatar.y < -WORLD_HEIGHT ||
      avatar.y > WORLD_HEIGHT * 2 ||
      !Number.isInteger(avatar.variant) ||
      avatar.variant < 0 ||
      avatar.variant > 3 ||
      typeof avatar.self !== "boolean" ||
      (avatar.status !== "online" && avatar.status !== "reconnecting")
    ) {
      return null;
    }
    ids.add(avatar.id);
    avatars.push({
      id: avatar.id,
      username: avatar.username,
      x: avatar.x,
      y: avatar.y,
      variant: avatar.variant,
      self: avatar.self,
      status: avatar.status,
    });
  }
  return { avatars };
}

function markAssetFailed(state, name) {
  if (state.disposed || activeRenderer !== state || !state.assets) return;
  state.assets[name] = { status: "failed", image: null };
  reportSceneError(state, ASSET_UNAVAILABLE);
  drawCurrent(state);
}

function startAsset(state, name, url) {
  const asset = state.assets[name];
  if (asset.status !== "idle") return;

  const image = createImage();
  if (image === FAILED) {
    markAssetFailed(state, name);
    return;
  }
  state.assets[name] = { status: "loading", image };
  if (call(state.imageReferences, "add", image) === FAILED) {
    markAssetFailed(state, name);
    return;
  }

  try {
    image.onload = () => {
      if (state.disposed || activeRenderer !== state || !state.assets) return;
      state.assets[name] = { status: "loaded", image };
      drawCurrent(state);
    };
    image.onerror = () => markAssetFailed(state, name);
    image.src = url;
  } catch (_) {
    markAssetFailed(state, name);
  }
}

function ensureAssets(state) {
  startAsset(state, "tiles", TILE_URL);
  startAsset(state, "avatars", AVATAR_URL);
}

function canvasSize(state) {
  const width = state.cssWidth ?? state.canvas.width / (state.dpr || 1);
  const height = state.cssHeight ?? state.canvas.height / (state.dpr || 1);
  return {
    width: Math.max(1, Number.isFinite(width) ? width : 1),
    height: Math.max(1, Number.isFinite(height) ? height : 1),
  };
}

function drawCurrent(state) {
  if (state.disposed || activeRenderer !== state || !state.lastScene) return;
  drawScene(state, state.lastScene);
}

function drawScene(state, scene) {
  const { width, height } = canvasSize(state);
  const tiles = state.assets.tiles;
  const avatars = state.assets.avatars;
  const hasTiles = tiles.status === "loaded";
  const hasAvatars = avatars.status === "loaded";

  if (!hasTiles || !hasAvatars) {
    drawFallback(state, scene.avatars);
    return;
  }

  try {
    const context = state.context;
    context.save();
    context.imageSmoothingEnabled = false;
    context.clearRect(0, 0, width, height);
    drawFloorAndWalls(context, width, height, hasTiles ? tiles.image : null);
    drawFurniture(context, width, height, hasTiles ? tiles.image : null);
    drawAvatars(context, width, height, scene.avatars, hasAvatars ? avatars.image : null);
    drawNamesAndAccents(context, width, height, scene.avatars);
    drawSpeechBubbles(context, width, height, scene.avatars);
    context.restore();
  } catch (_) {
    try {
      state.context.restore();
    } catch (_) {
      // A broken browser context cannot be repaired here.
    }
    drawFallback(state, scene.avatars);
    reportSceneError(state, SCENE_UNAVAILABLE);
  }
}

function drawFloorAndWalls(context, width, height, tiles) {
  if (!tiles) {
    context.fillStyle = "#18232a";
    context.fillRect(0, 0, width, height);
    context.fillStyle = "#304852";
    context.fillRect(0, 0, width, Math.min(32, height));
    context.fillRect(0, Math.max(0, height - 32), width, Math.min(32, height));
    return;
  }
  for (let y = 0; y < height; y += TILE_SIZE) {
    for (let x = 0; x < width; x += TILE_SIZE) {
      context.drawImage(tiles, 0, 0, TILE_SIZE, TILE_SIZE, x, y, TILE_SIZE, TILE_SIZE);
    }
  }
  for (let x = 0; x < width; x += TILE_SIZE) {
    context.drawImage(tiles, TILE_SIZE, 0, TILE_SIZE, TILE_SIZE, x, 0, TILE_SIZE, TILE_SIZE);
    context.drawImage(
      tiles,
      TILE_SIZE,
      0,
      TILE_SIZE,
      TILE_SIZE,
      x,
      Math.max(0, height - TILE_SIZE),
      TILE_SIZE,
      TILE_SIZE,
    );
  }
}

function drawFurniture(context, width, height, tiles) {
  const furniture = [
    [0.2, 0.3, 0.16, 0.08],
    [0.52, 0.26, 0.16, 0.08],
    [0.25, 0.62, 0.16, 0.08],
    [0.62, 0.66, 0.16, 0.08],
    [0.8, 0.42, 0.12, 0.08],
  ];
  for (const [left, top, widthRatio, heightRatio] of furniture) {
    const x = width * left;
    const y = height * top;
    const furnitureWidth = width * widthRatio;
    const furnitureHeight = height * heightRatio;
    context.fillStyle = "#8b5e4a";
    context.fillRect(x, y, furnitureWidth, furnitureHeight);
    context.fillStyle = "#d8a66f";
    context.fillRect(x + 4, y + 4, Math.max(1, furnitureWidth - 8), 4);
    if (tiles) {
      context.drawImage(tiles, 48, 16, TILE_SIZE, TILE_SIZE, x, y, 32, 32);
    }
  }
}

function drawAvatars(context, width, height, avatars, image) {
  const sorted = [...avatars].sort((left, right) => left.y - right.y || left.id.localeCompare(right.id));
  for (const avatar of sorted) {
    const { x, y } = avatarPosition(avatar, width, height);
    context.globalAlpha = avatar.status === "reconnecting" ? 0.55 : 1;
    if (image) {
      context.drawImage(image, avatar.variant * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE, x - 8, y - 16, TILE_SIZE, TILE_SIZE);
    } else {
      context.fillStyle = avatar.self ? "#f3d36a" : "#72b7a1";
      context.fillRect(x - 6, y - 14, 12, 14);
      context.fillStyle = "#18232a";
      context.fillRect(x - 4, y - 11, 2, 2);
      context.fillRect(x + 2, y - 11, 2, 2);
    }
    context.globalAlpha = 1;
  }
}

function drawNamesAndAccents(context, width, height, avatars) {
  context.font = "12px monospace";
  context.textAlign = "center";
  for (const avatar of avatars) {
    const { x, y } = avatarPosition(avatar, width, height);
    context.fillStyle = avatar.self ? "#f3d36a" : "#f2ead8";
    context.fillText(
      avatar.username,
      x,
      Math.max(12, y - 20),
      Math.max(1, Math.min(160, width - 16)),
    );
    if (avatar.self) {
      context.strokeStyle = "#f3d36a";
      context.strokeRect(x - 11, y - 19, 22, 21);
    }
  }
}

function drawSpeechBubbles(_context, _width, _height, _avatars) {
  // The pass is deliberately empty until chat bubbles have a bounded scene
  // contract; keeping it explicit preserves the renderer's draw order.
}

function avatarPosition(avatar, width, height) {
  return {
    x: clamp((avatar.x / WORLD_WIDTH) * width, 8, Math.max(8, width - 8)),
    y: clamp((avatar.y / WORLD_HEIGHT) * height, 20, Math.max(20, height - 4)),
  };
}

function drawFallback(state, avatars) {
  const { width, height } = canvasSize(state);
  try {
    const context = state.context;
    context.save();
    context.imageSmoothingEnabled = false;
    context.clearRect(0, 0, width, height);
    context.fillStyle = "#18232a";
    context.fillRect(0, 0, width, height);
    context.fillStyle = "#304852";
    context.fillRect(0, 0, width, Math.min(32, height));
    context.fillRect(0, Math.max(0, height - 32), width, Math.min(32, height));
    for (const avatar of avatars) {
      const { x, y } = avatarPosition(avatar, width, height);
      context.fillStyle = avatar.self ? "#f3d36a" : "#72b7a1";
      context.fillRect(x - 6, y - 14, 12, 14);
      context.fillStyle = "#18232a";
      context.fillRect(x - 4, y - 11, 2, 2);
      context.fillRect(x + 2, y - 11, 2, 2);
    }
    context.restore();
  } catch (_) {
    try {
      state.context.restore();
    } catch (_) {
      // The browser context remains unavailable.
    }
  }
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value));
}

function detachImageCallbacks(imageReferences) {
  try {
    for (const image of imageReferences) {
      try {
        image.onload = null;
      } catch (_) {
        // A hostile image object must not block the remaining detachments.
      }
      try {
        image.onerror = null;
      } catch (_) {
        // A hostile image object must not block disposal.
      }
    }
  } catch (_) {
    // Iteration itself can be replaced by an untrusted fake in tests.
  }
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
  if (imageReferences) detachImageCallbacks(imageReferences);
  call(imageReferences, "clear");

  state.canvas = null;
  state.context = null;
  state.onReady = null;
  state.onResize = null;
  state.onError = null;
  state.onSceneError = null;
  state.lastScene = null;
  state.assets = null;
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
    assets: {
      tiles: { status: "idle", image: null },
      avatars: { status: "idle", image: null },
    },
    lastScene: null,
    onSceneError: null,
    sceneErrorReported: false,
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

export function render_canvas(sceneJson, onError) {
  const state = activeRenderer;
  if (!state || state.disposed) return;

  const scene = validScene(sceneJson);
  state.onSceneError = onError;
  if (!scene) {
    state.lastScene = { avatars: [] };
    drawFallback(state, []);
    reportSceneError(state, SCENE_UNAVAILABLE);
    return;
  }

  state.lastScene = scene;
  ensureAssets(state);
  drawScene(state, scene);
}
