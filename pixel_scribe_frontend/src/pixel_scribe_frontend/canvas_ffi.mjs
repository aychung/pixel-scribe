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
const MAX_VIEWPORT_EXTENT = 8192;

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

function validCamera(payload) {
  if (typeof payload !== "string" || payload.length > 1024) return null;

  let parsed;
  try {
    parsed = JSON.parse(payload);
  } catch (_) {
    return null;
  }
  if (!parsed || typeof parsed !== "object") return null;
  if (
    !Number.isSafeInteger(parsed.origin_x) ||
    !Number.isSafeInteger(parsed.origin_y) ||
    !Number.isSafeInteger(parsed.viewport_width) ||
    !Number.isSafeInteger(parsed.viewport_height) ||
    parsed.origin_x < -WORLD_WIDTH * 2 ||
    parsed.origin_x > WORLD_WIDTH * 2 ||
    parsed.origin_y < -WORLD_HEIGHT * 2 ||
    parsed.origin_y > WORLD_HEIGHT * 2 ||
    parsed.viewport_width <= 0 ||
    parsed.viewport_width > MAX_VIEWPORT_EXTENT ||
    parsed.viewport_height <= 0 ||
    parsed.viewport_height > MAX_VIEWPORT_EXTENT
  ) {
    return null;
  }
  return {
    originX: parsed.origin_x,
    originY: parsed.origin_y,
    viewportWidth: parsed.viewport_width,
    viewportHeight: parsed.viewport_height,
  };
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
  const camera = state.camera;
  const tiles = state.assets.tiles;
  const avatars = state.assets.avatars;
  const hasTiles = tiles.status === "loaded";
  const hasAvatars = avatars.status === "loaded";

  if (!camera || !hasTiles || !hasAvatars) {
    drawFallback(state, scene.avatars, camera);
    return;
  }

  try {
    const context = state.context;
    context.save();
    context.imageSmoothingEnabled = false;
    context.clearRect(0, 0, width, height);
    context.fillStyle = "#18232a";
    context.fillRect(0, 0, width, height);
    context.beginPath();
    context.rect(0, 0, camera.viewportWidth, camera.viewportHeight);
    context.clip();
    drawFloorAndWalls(context, camera, tiles.image);
    drawFurniture(context, camera, tiles.image);
    drawAvatars(context, camera, scene.avatars, avatars.image);
    drawNamesAndAccents(context, camera, scene.avatars);
    drawSpeechBubbles(context, camera, scene.avatars);
    context.restore();
  } catch (_) {
    try {
      state.context.restore();
    } catch (_) {
      // A broken browser context cannot be repaired here.
    }
    drawFallback(state, scene.avatars, camera);
    reportSceneError(state, SCENE_UNAVAILABLE);
  }
}

function visibleWorldRange(camera) {
  return {
    left: Math.max(0, camera.originX),
    top: Math.max(0, camera.originY),
    right: Math.min(WORLD_WIDTH, camera.originX + camera.viewportWidth),
    bottom: Math.min(WORLD_HEIGHT, camera.originY + camera.viewportHeight),
  };
}

function drawFloorAndWalls(context, camera, tiles) {
  const range = visibleWorldRange(camera);
  const startX = Math.floor(range.left / TILE_SIZE) * TILE_SIZE;
  const startY = Math.floor(range.top / TILE_SIZE) * TILE_SIZE;
  const endX = Math.ceil(range.right / TILE_SIZE) * TILE_SIZE;
  const endY = Math.ceil(range.bottom / TILE_SIZE) * TILE_SIZE;
  for (let worldY = startY; worldY < endY; worldY += TILE_SIZE) {
    for (let worldX = startX; worldX < endX; worldX += TILE_SIZE) {
      const x = worldX - camera.originX;
      const y = worldY - camera.originY;
      context.drawImage(tiles, 0, 0, TILE_SIZE, TILE_SIZE, x, y, TILE_SIZE, TILE_SIZE);
    }
  }
  for (let worldX = startX; worldX < endX; worldX += TILE_SIZE) {
    const x = worldX - camera.originX;
    context.drawImage(tiles, TILE_SIZE, 0, TILE_SIZE, TILE_SIZE, x, -camera.originY, TILE_SIZE, TILE_SIZE);
    context.drawImage(
      tiles,
      TILE_SIZE,
      0,
      TILE_SIZE,
      TILE_SIZE,
      x,
      WORLD_HEIGHT - TILE_SIZE - camera.originY,
      TILE_SIZE,
      TILE_SIZE,
    );
  }
}

function drawFurniture(context, camera, tiles) {
  const furniture = [
    [160, 176, 96, 80],
    [432, 336, 96, 80],
    [720, 672, 96, 80],
    [1008, 176, 96, 80],
    [1200, 496, 96, 80],
  ];
  for (const [worldX, worldY, furnitureWidth, furnitureHeight] of furniture) {
    if (!rectVisible(worldX, worldY, furnitureWidth, furnitureHeight, camera)) continue;
    const x = worldX - camera.originX;
    const y = worldY - camera.originY;
    context.fillStyle = "#8b5e4a";
    context.fillRect(x, y, furnitureWidth, furnitureHeight);
    context.fillStyle = "#d8a66f";
    context.fillRect(x + 4, y + 4, Math.max(1, furnitureWidth - 8), 4);
    if (tiles) {
      context.drawImage(tiles, 48, 16, TILE_SIZE, TILE_SIZE, x, y, 32, 32);
    }
  }
}

function drawAvatars(context, camera, avatars, image) {
  const sorted = [...avatars].sort((left, right) => left.y - right.y || left.id.localeCompare(right.id));
  for (const avatar of sorted) {
    const { x, y } = avatarPosition(avatar, camera);
    if (!rectVisible(x - 8, y - 16, TILE_SIZE, TILE_SIZE, camera, true)) continue;
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

function drawNamesAndAccents(context, camera, avatars) {
  context.font = "12px monospace";
  context.textAlign = "center";
  for (const avatar of avatars) {
    const { x, y } = avatarPosition(avatar, camera);
    if (!rectVisible(x - 80, y - 32, 160, 40, camera, true)) continue;
    context.fillStyle = avatar.self ? "#f3d36a" : "#f2ead8";
    context.fillText(
      avatar.username,
      x,
      Math.max(12, y - 20),
      Math.max(1, Math.min(160, camera.viewportWidth - 16)),
    );
    if (avatar.self) {
      context.strokeStyle = "#f3d36a";
      context.strokeRect(x - 11, y - 19, 22, 21);
      context.fillStyle = "#f3d36a";
      context.fillRect(x - 1, y - 9, 2, 2);
    }
  }
}

function drawSpeechBubbles(_context, _camera, _avatars) {
  // The pass is deliberately empty until chat bubbles have a bounded scene
  // contract; keeping it explicit preserves the renderer's draw order.
}

function avatarPosition(avatar, camera) {
  return {
    x: avatar.x - camera.originX,
    y: avatar.y - camera.originY,
  };
}

function rectVisible(x, y, width, height, camera, viewportCoordinates = false) {
  const left = viewportCoordinates ? 0 : camera.originX;
  const top = viewportCoordinates ? 0 : camera.originY;
  const right = viewportCoordinates
    ? camera.viewportWidth
    : camera.originX + camera.viewportWidth;
  const bottom = viewportCoordinates
    ? camera.viewportHeight
    : camera.originY + camera.viewportHeight;
  return x < right && x + width > left && y < bottom && y + height > top;
}

function drawFallback(state, avatars, camera) {
  const { width, height } = canvasSize(state);
  const fallbackCamera = camera ?? {
    originX: 0,
    originY: 0,
    viewportWidth: width,
    viewportHeight: height,
  };
  try {
    const context = state.context;
    context.save();
    context.imageSmoothingEnabled = false;
    context.clearRect(0, 0, width, height);
    context.fillStyle = "#18232a";
    context.fillRect(0, 0, width, height);
    context.save();
    context.beginPath();
    context.rect(0, 0, fallbackCamera.viewportWidth, fallbackCamera.viewportHeight);
    context.clip();
    for (const avatar of avatars) {
      const { x, y } = avatarPosition(avatar, fallbackCamera);
      if (!rectVisible(x - 6, y - 14, 12, 14, fallbackCamera, true)) continue;
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
  state.camera = null;
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
    camera: null,
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

export function render_canvas(sceneJson, cameraJson, onError) {
  const state = activeRenderer;
  if (!state || state.disposed) return;

  const scene = validScene(sceneJson);
  const camera = validCamera(cameraJson);
  state.onSceneError = onError;
  if (!scene || !camera) {
    state.lastScene = { avatars: [] };
    state.camera = camera;
    drawFallback(state, [], camera);
    reportSceneError(state, SCENE_UNAVAILABLE);
    return;
  }

  state.lastScene = scene;
  state.camera = camera;
  ensureAssets(state);
  drawScene(state, scene);
}
