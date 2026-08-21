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
const CHARACTER_CELL_SIZE = 32;
const AVATAR_SIZE = 16;
const AVATAR_HALF_SIZE = AVATAR_SIZE / 2;
const AVATAR_LABEL_OFFSET = AVATAR_SIZE + 4;
const MAX_LABELED_AVATARS = 4;
const CHARACTER_FRONT_COLUMN = 0;
const CHARACTER_MODEL_ROWS = 6;
const CHARACTER_HAIR_ROWS = 8;
const CHARACTER_OUTFIT_ROWS = 4;
const WORLD_WIDTH = 336;
const WORLD_HEIGHT = 176;
const ASSET_URLS = Object.freeze({
  tiles: "/pixel-art/metrocity/Interior/Home/TilesHouse.png",
  cupboard: "/pixel-art/metrocity/Interior/Home/Cupboard-Sheet.png",
  miscellaneous: "/pixel-art/metrocity/Interior/Home/Miscellaneous-Sheet.png",
  flowers: "/pixel-art/metrocity/Interior/Home/Flowers-Sheet.png",
  carpet: "/pixel-art/metrocity/Interior/Home/Carpet-Sheet.png",
  livingRoom: "/pixel-art/metrocity/Interior/Home/LivingRoom-Sheet.png",
  livingRoom1: "/pixel-art/metrocity/Interior/Home/LivingRoom1-Sheet.png",
  paintings: "/pixel-art/metrocity/Interior/Home/Paintings-Sheet.png",
  characterModel: "/pixel-art/metrocity/Character/CharacterModel/Character%20Model.png",
  characterHair: "/pixel-art/metrocity/Character/Hair/Hairs.png",
  characterOutfit: "/pixel-art/metrocity/Character/Outfits/Suit.png",
});
const WALL_TILE_SOURCE = [0, 64];
const AVATAR_VARIANT_COUNT = 32;
const MIN_ZOOM = 1;
const MAX_ZOOM = 3;
// This matches the protocol's bounded text-frame scale while leaving room for
// opaque IDs that are longer than the server's generated IDs.
const MAX_RENDER_STRING_LENGTH = 8192;
const MAX_VIEWPORT_EXTENT = 8192;
const BUBBLE_LIFETIME_MS = 6000;
const BUBBLE_VISIBLE_MS = 5000;
const BUBBLE_FADE_MS = BUBBLE_LIFETIME_MS - BUBBLE_VISIBLE_MS;
const BUBBLE_MAX_WIDTH = 160;
const BUBBLE_MAX_HEIGHT = 44;

// The reference room's active 21×11 area is a workroom on the left and a
// lounge on the right. These coordinates are translated from Pixel Agents'
// 21×22 layout by removing its ten-row empty header.
const ROOM_LAYOUT = Object.freeze({
  desks: [
    [32, 32, 320],
    [96, 32, 384],
  ],
  conferenceTable: [64, 96],
  conferenceChairs: [
    [48, 96, 320],
    [48, 128, 320],
    [112, 96, 384],
    [112, 128, 384],
  ],
  loungeSofas: [
    [208, 64, 128],
    [224, 48, 64],
    [224, 96, 0],
    [256, 64, 192],
  ],
  coffeeTable: [224, 64],
});

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

function cssLength(value) {
  try {
    if (typeof value === "number") return finiteDimension(value);
    if (typeof value !== "string") return null;
    const parsed = Number.parseFloat(value);
    return finiteDimension(parsed);
  } catch (_) {
    return null;
  }
}

function computedInset(style, first, second) {
  const firstValue = cssLength(readProperty(style, first));
  const secondValue = cssLength(readProperty(style, second));
  return firstValue === null || secondValue === null ? null : firstValue + secondValue;
}

function contentBox(canvas, entry) {
  let rect = null;
  if (entry !== null && entry !== undefined) {
    rect = readProperty(entry, "contentRect");
    if (rect === FAILED) return null;
  }
  let horizontalInset = 0;
  let verticalInset = 0;
  if (!rect) {
    rect = call(canvas, "getBoundingClientRect");
    if (rect === FAILED) return null;
    const style = call(globalThis, "getComputedStyle", canvas);
    if (style === FAILED) return null;
    const horizontal = computedInset(style, "borderLeftWidth", "borderRightWidth");
    const vertical = computedInset(style, "borderTopWidth", "borderBottomWidth");
    const horizontalPadding = computedInset(style, "paddingLeft", "paddingRight");
    const verticalPadding = computedInset(style, "paddingTop", "paddingBottom");
    if (
      horizontal === null ||
      vertical === null ||
      horizontalPadding === null ||
      verticalPadding === null
    ) {
      return null;
    }
    horizontalInset = horizontal + horizontalPadding;
    verticalInset = vertical + verticalPadding;
  }

  const widthValue = readProperty(rect, "width");
  const heightValue = readProperty(rect, "height");
  if (widthValue === FAILED || heightValue === FAILED) return null;

  const width = finiteDimension(widthValue - horizontalInset);
  const height = finiteDimension(heightValue - verticalInset);
  return width === null || height === null ? null : { width, height };
}

function rawStringCompare(left, right) {
  if (left < right) return -1;
  if (left > right) return 1;
  return 0;
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
  scheduleFrame(state);
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
  let previous = null;
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
      avatar.variant >= AVATAR_VARIANT_COUNT ||
      typeof avatar.self !== "boolean" ||
      (avatar.status !== "online" && avatar.status !== "reconnecting")
    ) {
      return null;
    }
    if (!Number.isSafeInteger(avatar.size) || avatar.size !== AVATAR_SIZE) {
      return null;
    }
    if (
      previous !== null &&
      (avatar.y < previous.y ||
        (avatar.y === previous.y && rawStringCompare(avatar.id, previous.id) < 0))
    ) {
      return null;
    }
    ids.add(avatar.id);
    previous = { y: avatar.y, id: avatar.id };
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
  const parsedBubbles = parsed.bubbles === undefined ? [] : parsed.bubbles;
  if (!Array.isArray(parsedBubbles) || parsedBubbles.length > 50) return null;

  const bubbles = [];
  const bubbleIds = new Set();
  for (const bubble of parsedBubbles) {
    if (!bubble || typeof bubble !== "object") return null;
    if (
      typeof bubble.id !== "string" ||
      bubble.id.length === 0 ||
      bubble.id.length > MAX_RENDER_STRING_LENGTH ||
      bubbleIds.has(bubble.id) ||
      typeof bubble.sender_id !== "string" ||
      bubble.sender_id.length === 0 ||
      bubble.sender_id.length > MAX_RENDER_STRING_LENGTH ||
      !Array.isArray(bubble.lines) ||
      bubble.lines.length < 1 ||
      bubble.lines.length > 3 ||
      !bubble.lines.every((line) =>
        typeof line === "string" &&
        line.length <= MAX_RENDER_STRING_LENGTH &&
        !/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u.test(line)
      ) ||
      !Number.isSafeInteger(bubble.left) ||
      !Number.isSafeInteger(bubble.top) ||
      !Number.isSafeInteger(bubble.width) ||
      !Number.isSafeInteger(bubble.height) ||
      bubble.left < 0 ||
      bubble.top < 0 ||
      bubble.left > MAX_VIEWPORT_EXTENT ||
      bubble.top > MAX_VIEWPORT_EXTENT ||
      bubble.width <= 0 ||
      bubble.width > BUBBLE_MAX_WIDTH ||
      bubble.width > MAX_VIEWPORT_EXTENT ||
      bubble.height <= 0 ||
      bubble.height > BUBBLE_MAX_HEIGHT ||
      bubble.height > MAX_VIEWPORT_EXTENT ||
      bubble.left + bubble.width > MAX_VIEWPORT_EXTENT ||
      bubble.top + bubble.height > MAX_VIEWPORT_EXTENT ||
      !Number.isSafeInteger(bubble.started_at_ms) ||
      !Number.isSafeInteger(bubble.expires_at_ms) ||
      bubble.started_at_ms > Number.MAX_SAFE_INTEGER - BUBBLE_LIFETIME_MS ||
      bubble.expires_at_ms !== bubble.started_at_ms + BUBBLE_LIFETIME_MS
    ) {
      return null;
    }
    if (!ids.has(bubble.sender_id)) return null;
    bubbleIds.add(bubble.id);
    bubbles.push({
      id: bubble.id,
      senderId: bubble.sender_id,
      lines: bubble.lines,
      left: bubble.left,
      top: bubble.top,
      width: bubble.width,
      height: bubble.height,
      startedAt: bubble.started_at_ms,
      expiresAt: bubble.expires_at_ms,
    });
  }
  return { avatars, bubbles };
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
  const zoom = parsed.zoom === undefined ? 1 : parsed.zoom;
  if (
    !Number.isSafeInteger(parsed.origin_x) ||
    !Number.isSafeInteger(parsed.origin_y) ||
    !Number.isSafeInteger(parsed.viewport_width) ||
    !Number.isSafeInteger(parsed.viewport_height) ||
    !Number.isSafeInteger(zoom) ||
    parsed.origin_x < -WORLD_WIDTH * 2 ||
    parsed.origin_x > WORLD_WIDTH * 2 ||
    parsed.origin_y < -WORLD_HEIGHT * 2 ||
    parsed.origin_y > WORLD_HEIGHT * 2 ||
    parsed.viewport_width <= 0 ||
    parsed.viewport_width > MAX_VIEWPORT_EXTENT ||
    parsed.viewport_height <= 0 ||
    parsed.viewport_height > MAX_VIEWPORT_EXTENT ||
    zoom < MIN_ZOOM ||
    zoom > MAX_ZOOM
  ) {
    return null;
  }
  return {
    originX: parsed.origin_x,
    originY: parsed.origin_y,
    viewportWidth: parsed.viewport_width,
    viewportHeight: parsed.viewport_height,
    zoom,
  };
}

function markAssetFailed(state, name) {
  if (state.disposed || activeRenderer !== state || !state.assets) return;
  state.assets[name] = { status: "failed", image: null };
  reportSceneError(state, ASSET_UNAVAILABLE);
  scheduleFrame(state);
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
      scheduleFrame(state);
    };
    image.onerror = () => markAssetFailed(state, name);
    image.src = url;
  } catch (_) {
    markAssetFailed(state, name);
  }
}

function ensureAssets(state) {
  for (const [name, url] of Object.entries(ASSET_URLS)) {
    startAsset(state, name, url);
  }
}

function allAssetsLoaded(assets) {
  return Object.values(assets).every((asset) => asset.status === "loaded");
}

function initialAssets() {
  const assets = {};
  for (const name of Object.keys(ASSET_URLS)) {
    assets[name] = { status: "idle", image: null };
  }
  return assets;
}

function canvasSize(state) {
  const width = state.cssWidth ?? state.canvas.width / (state.dpr || 1);
  const height = state.cssHeight ?? state.canvas.height / (state.dpr || 1);
  return {
    width: Math.max(1, Number.isFinite(width) ? width : 1),
    height: Math.max(1, Number.isFinite(height) ? height : 1),
  };
}

function scheduleFrame(state) {
  if (state.disposed || activeRenderer !== state || state.pendingFrame !== null) return;

  const request = readProperty(globalThis, "requestAnimationFrame");
  if (request === FAILED || typeof request !== "function") {
    failRenderer(state, INITIALIZATION_FAILED);
    return;
  }

  const pendingSentinel = {};
  state.pendingFrame = pendingSentinel;
  const frame = call(globalThis, "requestAnimationFrame", (timestamp) => {
    state.pendingFrame = null;
    if (state.disposed || activeRenderer !== state) return;

    let now = timestamp;
    try {
      if (!Number.isFinite(now)) now = state.lastFrameTime ?? 0;
    } catch (_) {
      now = state.lastFrameTime ?? 0;
    }
    const previous = state.lastFrameTime;
    state.lastFrameTime = now;
    state.lastFrameDelta =
      previous === null ? 0 : Math.min(100, Math.max(0, now - previous));
    drawCurrent(state);
    if (state.animationActive) {
      if (hasFadingBubble(state)) scheduleFrame(state);
      else state.animationActive = false;
    }
  });

  if (frame === FAILED) {
    if (state.pendingFrame === pendingSentinel) state.pendingFrame = null;
    failRenderer(state, INITIALIZATION_FAILED);
    return;
  }
  if (state.pendingFrame === pendingSentinel) state.pendingFrame = frame;
}

function hasFadingBubble(state) {
  if (!state.lastScene) return false;
  const now = wallClockNow();
  const reducedMotion = prefersReducedMotion();
  return state.lastScene.bubbles.some((bubble) =>
    bubbleVisibility(bubble, now, reducedMotion)?.fading === true,
  );
}

function drawCurrent(state) {
  if (state.disposed || activeRenderer !== state || !state.lastScene) return;
  drawScene(state, state.lastScene);
}

function drawScene(state, scene) {
  const { width, height } = canvasSize(state);
  const camera = state.camera;

  if (!camera || !allAssetsLoaded(state.assets)) {
    drawFallback(state, scene, camera);
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
    context.rect(
      0,
      0,
      camera.viewportWidth * camera.zoom,
      camera.viewportHeight * camera.zoom,
    );
    context.clip();
    drawFloorAndWalls(context, camera, state.assets.tiles.image);
    drawFurniture(context, camera, state.assets);
    drawAvatars(context, camera, scene.avatars, state.assets);
    drawNamesAndAccents(context, camera, scene.avatars);
    drawSpeechBubbles(context, camera, scene);
    context.restore();
  } catch (_) {
    try {
      state.context.restore();
    } catch (_) {
      // A broken browser context cannot be repaired here.
    }
    drawFallback(state, scene, camera);
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

  fillWorldRect(context, camera, 0, 0, WORLD_WIDTH, WORLD_HEIGHT, "#3a2619");
  for (let worldY = startY; worldY < endY; worldY += TILE_SIZE) {
    for (let worldX = startX; worldX < endX; worldX += TILE_SIZE) {
      if (!isOfficeFloorTile(worldX, worldY)) continue;
      const x = (worldX - camera.originX) * camera.zoom;
      const y = (worldY - camera.originY) * camera.zoom;
      const checker = (worldX / TILE_SIZE + worldY / TILE_SIZE) % 2 === 0;
      context.fillStyle = floorColor(worldX, checker);
      context.fillRect(x, y, TILE_SIZE * camera.zoom, TILE_SIZE * camera.zoom);
    }
  }

  for (let worldX = 0; worldX < WORLD_WIDTH; worldX += TILE_SIZE) {
    drawWallTile(context, camera, tiles, worldX, 0);
    drawWallTile(context, camera, tiles, worldX, WORLD_HEIGHT - TILE_SIZE);
  }
  for (let worldY = TILE_SIZE; worldY < WORLD_HEIGHT - TILE_SIZE; worldY += TILE_SIZE) {
    drawWallTile(context, camera, tiles, 0, worldY);
    drawWallTile(context, camera, tiles, WORLD_WIDTH - TILE_SIZE, worldY);
  }
  for (let worldY = TILE_SIZE; worldY < 64; worldY += TILE_SIZE) {
    drawWallTile(context, camera, tiles, 160, worldY);
  }
  for (let worldY = 128; worldY < WORLD_HEIGHT - TILE_SIZE; worldY += TILE_SIZE) {
    drawWallTile(context, camera, tiles, 160, worldY);
  }
}

function isOfficeFloorTile(worldX, worldY) {
  return (
    worldX >= TILE_SIZE &&
    worldX < WORLD_WIDTH - TILE_SIZE &&
    worldY >= TILE_SIZE &&
    worldY < WORLD_HEIGHT - TILE_SIZE &&
    !(worldX === 160 && (worldY < 64 || worldY >= 128))
  );
}

function floorColor(worldX, checker) {
  if (worldX >= 160) return checker ? "#3f6e91" : "#477a9f";
  return checker ? "#8e5d2a" : "#956334";
}

function drawWallTile(context, camera, tiles, worldX, worldY) {
  if (!rectVisible(worldX, worldY, TILE_SIZE, TILE_SIZE, camera)) return;
  context.drawImage(
    tiles,
    WALL_TILE_SOURCE[0],
    WALL_TILE_SOURCE[1],
    TILE_SIZE,
    TILE_SIZE,
    (worldX - camera.originX) * camera.zoom,
    (worldY - camera.originY) * camera.zoom,
    TILE_SIZE * camera.zoom,
    TILE_SIZE * camera.zoom,
  );
}

function fillWorldRect(context, camera, worldX, worldY, width, height, color) {
  context.fillStyle = color;
  context.fillRect(
    (worldX - camera.originX) * camera.zoom,
    (worldY - camera.originY) * camera.zoom,
    width * camera.zoom,
    height * camera.zoom,
  );
}

function drawFurniture(context, camera, assets) {
  // Rugs and wall decor are walkable backdrops. Blocking furniture is kept in
  // ROOM_LAYOUT and mirrored by scene.furniture_exclusions.
  const carpets = [
    [176, 112, 2],
    [240, 112, 3],
  ];
  for (const [worldX, worldY, carpetColumn] of carpets) {
    drawInteriorAsset(
      context,
      camera,
      assets.carpet.image,
      carpetColumn * 64,
      0,
      64,
      64,
      worldX,
      worldY,
    );
  }

  drawRoomWallDecor(context, camera, assets);

  for (const [worldX, worldY, chairSourceX] of ROOM_LAYOUT.desks) {
    drawInteriorAsset(
      context,
      camera,
      assets.livingRoom.image,
      0,
      0,
      64,
      96,
      worldX,
      worldY,
    );
    drawInteriorAsset(
      context,
      camera,
      assets.miscellaneous.image,
      chairSourceX,
      0,
      64,
      64,
      worldX,
      worldY + 64,
    );
  }

  const [tableX, tableY] = ROOM_LAYOUT.conferenceTable;
  drawInteriorAsset(
    context,
    camera,
    assets.livingRoom.image,
    0,
    0,
    64,
    96,
    tableX,
    tableY,
  );

  for (const [worldX, worldY, sourceX] of ROOM_LAYOUT.conferenceChairs) {
    drawInteriorAsset(
      context,
      camera,
      assets.miscellaneous.image,
      sourceX,
      0,
      64,
      64,
      worldX,
      worldY,
    );
  }

  for (const [worldX, worldY, sourceX] of ROOM_LAYOUT.loungeSofas) {
    drawInteriorAsset(
      context,
      camera,
      assets.livingRoom1.image,
      sourceX,
      7 * 64,
      64,
      64,
      worldX,
      worldY,
    );
  }

  const [coffeeTableX, coffeeTableY] = ROOM_LAYOUT.coffeeTable;
  drawInteriorAsset(
    context,
    camera,
    assets.miscellaneous.image,
    256,
    0,
    64,
    64,
    coffeeTableX,
    coffeeTableY,
  );

}

function drawRoomWallDecor(context, camera, assets) {
  const bookshelves = [
    [16, 0, 192],
    [80, 0, 256],
    [176, 0, 320],
    [240, 0, 384],
  ];
  for (const [worldX, worldY, sourceX] of bookshelves) {
    drawInteriorAsset(
      context,
      camera,
      assets.cupboard.image,
      sourceX,
      0,
      64,
      96,
      worldX,
      worldY,
    );
  }

  drawInteriorAsset(context, camera, assets.flowers.image, 0, 0, 64, 96, 16, 0);
  drawInteriorAsset(context, camera, assets.flowers.image, 320, 0, 64, 96, 240, 0);
  drawInteriorAsset(context, camera, assets.paintings.image, 0, 0, 64, 32, 176, 0);
  drawInteriorAsset(context, camera, assets.paintings.image, 64, 0, 64, 32, 240, 0);
}

function drawFallbackFurniture(context, camera) {
  for (const [worldX, worldY] of ROOM_LAYOUT.desks) {
    drawFurnitureTile(context, camera, null, worldX, worldY, 0, 0, 2);
    drawFurnitureTile(context, camera, null, worldX + 32, worldY, 0, 0, 2);
    drawFurnitureTile(context, camera, null, worldX, worldY + 32, 0, 0, 1);
  }

  const [tableX, tableY] = ROOM_LAYOUT.conferenceTable;
  drawFurnitureTile(context, camera, null, tableX, tableY, 0, 0, 3);
  for (const [worldX, worldY] of ROOM_LAYOUT.conferenceChairs) {
    drawFurnitureTile(context, camera, null, worldX, worldY, 0, 0, 1);
  }
  for (const [worldX, worldY] of [
    [208, 64],
    [224, 48],
    [224, 96],
    [256, 64],
  ]) {
    drawFurnitureTile(context, camera, null, worldX, worldY, 0, 0, 2);
  }
  for (const [worldX, worldY] of [[16, 0], [80, 0], [176, 0], [240, 0]]) {
    drawFurnitureTile(context, camera, null, worldX, worldY, 0, 0, 2);
  }
}

function drawInteriorAsset(
  context,
  camera,
  image,
  sourceX,
  sourceY,
  sourceWidth,
  sourceHeight,
  worldX,
  worldY,
) {
  if (!rectVisible(worldX, worldY, sourceWidth, sourceHeight, camera)) return;
  context.drawImage(
    image,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
    (worldX - camera.originX) * camera.zoom,
    (worldY - camera.originY) * camera.zoom,
    sourceWidth * camera.zoom,
    sourceHeight * camera.zoom,
  );
}

function drawFurnitureTile(
  context,
  camera,
  tiles,
  worldX,
  worldY,
  sourceColumn,
  sourceRow,
  scale = 1,
) {
  const destinationSize = TILE_SIZE * scale;
  if (!rectVisible(worldX, worldY, destinationSize, destinationSize, camera)) return;
  const x = (worldX - camera.originX) * camera.zoom;
  const y = (worldY - camera.originY) * camera.zoom;
  const scaledDestinationSize = destinationSize * camera.zoom;
  if (tiles) {
    context.drawImage(
      tiles,
      sourceColumn * TILE_SIZE,
      sourceRow * TILE_SIZE,
      TILE_SIZE,
      TILE_SIZE,
      x,
      y,
      scaledDestinationSize,
      scaledDestinationSize,
    );
    return;
  }
  context.fillStyle = "#8b5e4a";
  context.fillRect(x, y, scaledDestinationSize, scaledDestinationSize);
  context.fillStyle = "#d8a66f";
  context.fillRect(
    x + 2 * camera.zoom,
    y + 2 * camera.zoom,
    scaledDestinationSize - 4 * camera.zoom,
    3 * camera.zoom,
  );
}

function drawAvatars(context, camera, avatars, assets) {
  // Gleam supplies this list in stable Y/connection-ID order. Re-sorting here
  // would make draw order depend on the browser's locale.
  for (const avatar of avatars) {
    const { x, y } = avatarPosition(avatar, camera);
    const zoom = camera.zoom * (AVATAR_SIZE / CHARACTER_CELL_SIZE);
    if (!rectVisible(
      x - AVATAR_HALF_SIZE * camera.zoom,
      y - AVATAR_SIZE * camera.zoom,
      AVATAR_SIZE * camera.zoom,
      AVATAR_SIZE * camera.zoom,
      camera,
      true,
    )) continue;
    context.globalAlpha = avatar.status === "reconnecting" ? 0.55 : 1;
    const left = x - AVATAR_HALF_SIZE * camera.zoom;
    const top = y - AVATAR_SIZE * camera.zoom;
    const modelRow = avatar.variant % CHARACTER_MODEL_ROWS;
    const hairRow = Math.floor(avatar.variant / 4) % CHARACTER_HAIR_ROWS;
    const outfitRow = Math.floor(avatar.variant / 8) % CHARACTER_OUTFIT_ROWS;
    drawCharacterLayer(
      context,
      assets.characterModel.image,
      CHARACTER_FRONT_COLUMN * CHARACTER_CELL_SIZE,
      modelRow * CHARACTER_CELL_SIZE,
      left,
      top,
      zoom,
    );
    drawCharacterLayer(
      context,
      assets.characterOutfit.image,
      CHARACTER_FRONT_COLUMN * CHARACTER_CELL_SIZE,
      outfitRow * CHARACTER_CELL_SIZE,
      left,
      top,
      zoom,
    );
    drawCharacterLayer(
      context,
      assets.characterHair.image,
      CHARACTER_FRONT_COLUMN * CHARACTER_CELL_SIZE,
      hairRow * CHARACTER_CELL_SIZE,
      left,
      top,
      zoom,
    );
    context.globalAlpha = 1;
  }
}

function drawCharacterLayer(context, image, sourceX, sourceY, x, y, zoom) {
  context.drawImage(
    image,
    sourceX,
    sourceY,
    CHARACTER_CELL_SIZE,
    CHARACTER_CELL_SIZE,
    x,
    y,
    CHARACTER_CELL_SIZE * zoom,
    CHARACTER_CELL_SIZE * zoom,
  );
}

function drawNamesAndAccents(context, camera, avatars) {
  context.font = `${12 * camera.zoom}px monospace`;
  context.textAlign = "center";
  const showPeerNames = avatars.length <= MAX_LABELED_AVATARS;
  for (const avatar of avatars) {
    // The participant list remains the authoritative readable name surface.
    // In a crowded room, keep only the local user's canvas label so peer
    // labels do not obscure avatars and furniture.
    if (!avatar.self && !showPeerNames) continue;
    const { x, y } = avatarPosition(avatar, camera);
    if (!rectVisible(
      x - 80 * camera.zoom,
      y - (AVATAR_LABEL_OFFSET + 16) * camera.zoom,
      160 * camera.zoom,
      (AVATAR_LABEL_OFFSET + 20) * camera.zoom,
      camera,
      true,
    )) continue;
    context.fillStyle = avatar.self ? "#f3d36a" : "#f2ead8";
    context.fillText(
      avatar.username,
      x,
      Math.max(12 * camera.zoom, y - AVATAR_LABEL_OFFSET * camera.zoom),
      Math.max(
        1,
        Math.min(
          160 * camera.zoom,
          camera.viewportWidth * camera.zoom - 16 * camera.zoom,
        ),
      ),
    );
    if (avatar.self) {
      context.strokeStyle = "#f3d36a";
      context.strokeRect(
        x - (AVATAR_HALF_SIZE + 3) * camera.zoom,
        y - (AVATAR_SIZE + 3) * camera.zoom,
        (AVATAR_SIZE + 6) * camera.zoom,
        (AVATAR_SIZE + 5) * camera.zoom,
      );
      context.fillStyle = "#f3d36a";
      context.fillRect(
        x - camera.zoom,
        y - AVATAR_HALF_SIZE * camera.zoom,
        2 * camera.zoom,
        2 * camera.zoom,
      );
    }
  }
}

function drawSpeechBubbles(context, camera, scene) {
  const now = wallClockNow();
  const reducedMotion = prefersReducedMotion();
  for (const bubble of scene.bubbles) {
    const visibility = bubbleVisibility(bubble, now, reducedMotion);
    if (!visibility) continue;
    const alpha = visibility.opacity / 100;
    let saved = false;
    try {
      context.save();
      saved = true;
      context.globalAlpha = alpha;
      context.fillStyle = "#f2ead8";
      context.strokeStyle = "#18232a";
      context.lineWidth = Math.max(1, camera.zoom);
      const left = bubble.left * camera.zoom;
      const top = bubble.top * camera.zoom;
      const width = bubble.width * camera.zoom;
      const height = bubble.height * camera.zoom;
      context.fillRect(left, top, width, height);
      context.strokeRect(left, top, width, height);
      context.fillStyle = "#18232a";
      context.font = `${12 * camera.zoom}px monospace`;
      context.textAlign = "left";
      // The layout uses a logical bubble width, while Canvas may resolve
      // emoji and other fallback glyphs wider than the monospace advance.
      // maxWidth keeps every line inside the padded rectangle without
      // clipping it at the viewport edge. Normal lines below this width are
      // unaffected; only oversized fallback glyphs are scaled by Canvas.
      const interiorWidth = Math.max(1, (bubble.width - 16) * camera.zoom);
      for (let index = 0; index < bubble.lines.length; index += 1) {
        context.fillText(
          bubble.lines[index],
          left + 8 * camera.zoom,
          top + (index + 1) * 12 * camera.zoom,
          interiorWidth,
        );
      }
    } catch (_) {
      // A failed bubble draw should not tear down the avatar scene.
    } finally {
      if (saved) {
        try {
          context.restore();
        } catch (_) {
          // A broken browser context cannot be repaired here.
        }
      }
    }
  }
}

function wallClockNow() {
  try {
    const value = Date.now();
    return Number.isSafeInteger(value) ? value : 0;
  } catch (_) {
    return 0;
  }
}

function prefersReducedMotion() {
  try {
    const browser = browserObject("window");
    const matchMedia = readProperty(browser, "matchMedia");
    if (typeof matchMedia !== "function") return false;
    const media = call(browser, "matchMedia", "(prefers-reduced-motion: reduce)");
    return media !== FAILED && readProperty(media, "matches") === true;
  } catch (_) {
    return false;
  }
}

function bubbleVisibility(bubble, now, reducedMotion) {
  if (now >= bubble.expiresAt) return null;
  if (reducedMotion || now < bubble.startedAt + BUBBLE_VISIBLE_MS) {
    return { opacity: 100, fading: false };
  }
  const progress = Math.max(
    0,
    Math.min(
      1,
      (now - bubble.startedAt - BUBBLE_VISIBLE_MS) / BUBBLE_FADE_MS,
    ),
  );
  return { opacity: Math.max(1, Math.round(100 - progress * 100)), fading: true };
}

function avatarPosition(avatar, camera) {
  return {
    x: (avatar.x - camera.originX) * camera.zoom,
    y: (avatar.y - camera.originY) * camera.zoom,
  };
}

function rectVisible(x, y, width, height, camera, viewportCoordinates = false) {
  const left = viewportCoordinates ? 0 : camera.originX;
  const top = viewportCoordinates ? 0 : camera.originY;
  const right = viewportCoordinates
    ? camera.viewportWidth * camera.zoom
    : camera.originX + camera.viewportWidth;
  const bottom = viewportCoordinates
    ? camera.viewportHeight * camera.zoom
    : camera.originY + camera.viewportHeight;
  return x < right && x + width > left && y < bottom && y + height > top;
}

function drawFallback(state, scene, camera) {
  const avatars = scene.avatars;
  const { width, height } = canvasSize(state);
  const fallbackCamera = camera ?? {
    originX: 0,
    originY: 0,
    viewportWidth: width,
    viewportHeight: height,
    zoom: 1,
  };
  let saved = false;
  try {
    const context = state.context;
    context.save();
    saved = true;
    context.imageSmoothingEnabled = false;
    context.clearRect(0, 0, width, height);
    context.fillStyle = "#18232a";
    context.fillRect(0, 0, width, height);
    context.beginPath();
    context.rect(
      0,
      0,
      fallbackCamera.viewportWidth * fallbackCamera.zoom,
      fallbackCamera.viewportHeight * fallbackCamera.zoom,
    );
    context.clip();
    drawFallbackFloorAndWalls(context, fallbackCamera);
    drawFallbackFurniture(context, fallbackCamera);
    for (const avatar of avatars) {
      const { x, y } = avatarPosition(avatar, fallbackCamera);
      if (!rectVisible(
        x - AVATAR_HALF_SIZE * fallbackCamera.zoom,
        y - AVATAR_SIZE * fallbackCamera.zoom,
        AVATAR_SIZE * fallbackCamera.zoom,
        AVATAR_SIZE * fallbackCamera.zoom,
        fallbackCamera,
        true,
      )) continue;
      context.fillStyle = avatar.self ? "#f3d36a" : "#72b7a1";
      context.fillRect(
        x - AVATAR_HALF_SIZE * fallbackCamera.zoom,
        y - AVATAR_SIZE * fallbackCamera.zoom,
        AVATAR_SIZE * fallbackCamera.zoom,
        AVATAR_SIZE * fallbackCamera.zoom,
      );
      context.fillStyle = "#18232a";
      context.fillRect(
        x - 4 * fallbackCamera.zoom,
        y - 12 * fallbackCamera.zoom,
        2 * fallbackCamera.zoom,
        2 * fallbackCamera.zoom,
      );
      context.fillRect(
        x + 2 * fallbackCamera.zoom,
        y - 12 * fallbackCamera.zoom,
        2 * fallbackCamera.zoom,
        2 * fallbackCamera.zoom,
      );
    }
    drawSpeechBubbles(context, fallbackCamera, scene);
  } catch (_) {
    // The browser context remains best-effort; the finally block still closes
    // the save scope when any drawing operation fails.
  } finally {
    if (saved) {
      try {
        state.context.restore();
      } catch (_) {
        // A broken browser context cannot be repaired here.
      }
    }
  }
}

function drawFallbackFloorAndWalls(context, camera) {
  const range = visibleWorldRange(camera);
  const startX = Math.floor(range.left / TILE_SIZE) * TILE_SIZE;
  const startY = Math.floor(range.top / TILE_SIZE) * TILE_SIZE;
  const endX = Math.ceil(range.right / TILE_SIZE) * TILE_SIZE;
  const endY = Math.ceil(range.bottom / TILE_SIZE) * TILE_SIZE;

  context.fillStyle = "#3a2619";
  context.fillRect(
    -camera.originX * camera.zoom,
    -camera.originY * camera.zoom,
    WORLD_WIDTH * camera.zoom,
    WORLD_HEIGHT * camera.zoom,
  );
  for (let worldY = startY; worldY < endY; worldY += TILE_SIZE) {
    for (let worldX = startX; worldX < endX; worldX += TILE_SIZE) {
      if (!isOfficeFloorTile(worldX, worldY)) continue;
      const x = (worldX - camera.originX) * camera.zoom;
      const y = (worldY - camera.originY) * camera.zoom;
      const checker = (worldX / TILE_SIZE + worldY / TILE_SIZE) % 2 === 0;
      context.fillStyle = floorColor(worldX, checker);
      context.fillRect(
        x,
        y,
        TILE_SIZE * camera.zoom,
        TILE_SIZE * camera.zoom,
      );
    }
  }

  context.fillStyle = "#6f8790";
  for (let worldX = 0; worldX < WORLD_WIDTH; worldX += TILE_SIZE) {
    drawFallbackWallTile(context, camera, worldX, 0);
    drawFallbackWallTile(context, camera, worldX, WORLD_HEIGHT - TILE_SIZE);
  }
  for (let worldY = TILE_SIZE; worldY < WORLD_HEIGHT - TILE_SIZE; worldY += TILE_SIZE) {
    drawFallbackWallTile(context, camera, 0, worldY);
    drawFallbackWallTile(context, camera, WORLD_WIDTH - TILE_SIZE, worldY);
  }
  for (let worldY = TILE_SIZE; worldY < 64; worldY += TILE_SIZE) {
    drawFallbackWallTile(context, camera, 160, worldY);
  }
  for (let worldY = 128; worldY < WORLD_HEIGHT - TILE_SIZE; worldY += TILE_SIZE) {
    drawFallbackWallTile(context, camera, 160, worldY);
  }
}

function drawFallbackWallTile(context, camera, worldX, worldY) {
  if (!rectVisible(worldX, worldY, TILE_SIZE, TILE_SIZE, camera)) return;
  context.fillRect(
    (worldX - camera.originX) * camera.zoom,
    (worldY - camera.originY) * camera.zoom,
    TILE_SIZE * camera.zoom,
    TILE_SIZE * camera.zoom,
  );
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
    assets: initialAssets(),
    camera: null,
    lastScene: null,
    lastFrameTime: null,
    lastFrameDelta: 0,
    animationActive: false,
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
    state.lastScene = { avatars: [], bubbles: [] };
    state.camera = camera;
    state.animationActive = false;
    scheduleFrame(state);
    reportSceneError(state, SCENE_UNAVAILABLE);
    return;
  }

  state.lastScene = scene;
  state.camera = camera;
  ensureAssets(state);
  state.animationActive = hasFadingBubble(state);
  scheduleFrame(state);
}
