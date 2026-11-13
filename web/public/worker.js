// Runs a sequence exactly as the manager does: synchronously, with a blocking
// delay(). That is why it lives in a worker - an endless loop or a long delay
// only blocks this thread, and stopping is worker.terminate().
//
// delay() waits with Atomics.wait when the page is cross-origin isolated
// (localhost, https). On plain http over the LAN SharedArrayBuffer is missing,
// so it falls back to a busy wait.

let width = 4;
let height = 125;
let speed = 1;
let pixels;               // RGBW per LED, string-major like the manager's buffer
let lastPost = 0;
let frames = 0;

const sleeper = typeof SharedArrayBuffer !== "undefined"
  ? new Int32Array(new SharedArrayBuffer(4))
  : null;

function byte(v) {
  // Same rule as the manager: non-finite -> 0, otherwise floor and clamp.
  if (typeof v !== "number" || !Number.isFinite(v)) return 0;
  return Math.min(255, Math.max(0, Math.floor(v)));
}

const matrix = Object.freeze({
  get width() { return width; },
  get height() { return height; },
});

function setPixelColor(r, g, b, w, x, y) {
  if (typeof x !== "number" || typeof y !== "number") return;
  x = Math.floor(x);
  y = Math.floor(y);
  if (x < 0 || x >= height || y < 0 || y >= width) return;
  const i = (y * height + x) * 4;
  pixels[i] = byte(r);
  pixels[i + 1] = byte(g);
  pixels[i + 2] = byte(b);
  pixels[i + 3] = byte(w);
}

function updatePixels() {
  frames++;
  // A script that never calls delay() would flood the page; cap at ~60 fps.
  const now = performance.now();
  if (now - lastPost < 16) return;
  lastPost = now;
  postMessage({ type: "frame", pixels: pixels.slice() });
}

function delay(ms) {
  const wait = Math.max(0, Number(ms) || 0) / speed;
  if (sleeper) {
    Atomics.wait(sleeper, 0, 0, wait);
  } else {
    const end = performance.now() + wait;
    while (performance.now() < end) { /* busy wait, see top of file */ }
  }
}

self.onmessage = (event) => {
  const { code } = event.data;
  width = event.data.width;
  height = event.data.height;
  speed = event.data.speed || 1;
  pixels = new Uint8ClampedArray(width * height * 4);

  let run;
  try {
    run = new Function("matrix", "setPixelColor", "updatePixels", "delay", code);
  } catch (err) {
    postMessage({ type: "error", error: `Syntaksfejl: ${err.message}` });
    return;
  }

  // The manager starts a script again when it ends, so the preview does too.
  for (let round = 1; ; round++) {
    const started = performance.now();
    frames = 0;
    try {
      run(matrix, setPixelColor, updatePixels, delay);
    } catch (err) {
      postMessage({ type: "error", error: `Fejl under kørsel: ${err.message}` });
      return;
    }
    const seconds = (performance.now() - started) / 1000;
    postMessage({ type: "ended", round, seconds, frames });
    if (frames === 0) {
      postMessage({ type: "error", error: "Scriptet kalder aldrig updatePixels()" });
      return;
    }
  }
};
