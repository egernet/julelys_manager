// Julelys web front end: chat, live preview in a worker, and deploy to the tree.

const $ = (id) => document.getElementById(id);

const state = {
  // crypto.randomUUID needs a secure context, which plain http on the LAN is not.
  chatId: Date.now().toString(36) + Math.random().toString(36).slice(2),
  width: 4,
  height: 125,
  code: "",
  // True when the code on screen did not come from Claude's last answer, so the
  // next chat message has to include it.
  codeChanged: false,
  autoName: true,
  busy: false,
  isOff: false,
  sequences: [],
};

// ------------------------------------------------------------------ status ---

async function api(path, body) {
  const res = await fetch(path, body === undefined ? {} : {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.error) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

async function refreshStatus() {
  try {
    const status = await api("/api/status");
    state.width = status.matrixWidth || state.width;
    state.height = status.matrixHeight || state.height;
    const active = (status.activeSequences || []).filter((n) => n !== "Sluk");
    state.active = active;
    state.isOff = active.length === 0;
    $("now").innerHTML = active.length
      ? `På træet nu: <b>${active.map(escapeHtml).join("</b>, <b>")}</b>`
      : "Træet er slukket";
    $("off").textContent = state.isOff ? "Tænd træet" : "Sluk træet";
    $("off").classList.toggle("primary", state.isOff);
  } catch (err) {
    $("now").textContent = `Kan ikke nå manageren: ${err.message}`;
  }
}

async function refreshSequences() {
  try {
    const { sequences } = await api("/api/sequences");
    state.sequences = sequences.map((s) => s.name).sort((a, b) => a.localeCompare(b, "da"));
    const select = $("open");
    select.length = 1;
    for (const name of state.sequences) select.add(new Option(name, name));
  } catch { /* status line already shows the problem */ }
}

$("open").addEventListener("change", async (e) => {
  const name = e.target.value;
  e.target.value = "";
  if (!name) return;
  try {
    const seq = await api(`/api/sequence?name=${encodeURIComponent(name)}`);
    if (!seq.jsCode) throw new Error(seq.error || "Ingen kode");
    setCode(seq.jsCode, { fromChat: false });
    // Built-ins cannot be overwritten, so suggest a name for the copy.
    $("name").value = seq.isCustom ? seq.name : `${seq.name} (min version)`;
    $("description").value = seq.description || "";
    state.autoName = false;
    addMessage("assistant", seq.isCustom
      ? `Åbnede “${seq.name}”. Skriv hvad du vil ændre, så arbejder Claude videre på den.`
      : `Åbnede den indbyggede “${seq.name}”. Ændringer gemmes som en ny sekvens, så originalen bliver liggende.`);
  } catch (err) {
    addMessage("error", `Kunne ikke åbne ${name}: ${err.message}`);
  }
});

$("off").addEventListener("click", async () => {
  const on = state.isOff;
  $("off").disabled = true;
  try {
    await api("/api/power", { on });
    await refreshStatus();
  } catch (err) {
    $("deployNote").textContent = err.message;
  } finally {
    $("off").disabled = false;
  }
});

// -------------------------------------------------------------------- chat ---

function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

/** Small markdown subset: code fences become a collapsible block, plus `code` and **bold**. */
function renderMarkdown(text, streaming) {
  const parts = text.split(/```(?:javascript|js)?\n?/);
  let html = "";
  parts.forEach((part, i) => {
    if (i % 2 === 0) {
      html += escapeHtml(part.replace(/^\n+|\n+$/g, ""))
        .replace(/`([^`\n]+)`/g, "<code>$1</code>")
        .replace(/\*\*([^*\n]+)\*\*/g, "<b>$1</b>");
    } else {
      const open = streaming && i === parts.length - 1;
      const lines = part.split("\n").length;
      html += `<details><summary>${open ? "Skriver kode…" : `Kode (${lines} linjer)`}</summary><pre>${escapeHtml(part)}</pre></details>`;
    }
  });
  return html;
}

function addMessage(role, text) {
  $("welcome")?.remove();
  const el = document.createElement("div");
  el.className = `msg ${role}`;
  if (role === "assistant") el.innerHTML = renderMarkdown(text, false);
  else el.textContent = text;
  $("messages").appendChild(el);
  el.scrollIntoView({ block: "end" });
  return el;
}

function extractCode(text) {
  const blocks = [...text.matchAll(/```(?:javascript|js)?\n([\s\S]*?)```/g)];
  return blocks.length ? blocks[blocks.length - 1][1].trim() + "\n" : null;
}

async function sendMessage(message) {
  if (state.busy || !message.trim()) return;
  state.busy = true;
  $("send").disabled = true;
  addMessage("user", message);
  const bubble = addMessage("assistant", "");
  bubble.classList.add("typing");

  const body = { chatId: state.chatId, message };
  if (state.codeChanged && state.code) body.code = state.code;

  let text = "";
  try {
    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok || !res.body) throw new Error((await res.json().catch(() => ({}))).error || `HTTP ${res.status}`);

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let cut;
      while ((cut = buffer.indexOf("\n\n")) >= 0) {
        const line = buffer.slice(0, cut).replace(/^data: /, "");
        buffer = buffer.slice(cut + 2);
        const event = JSON.parse(line);
        if (event.type === "text") {
          text += event.text;
          bubble.innerHTML = renderMarkdown(text, true);
          bubble.scrollIntoView({ block: "end" });
        } else if (event.type === "done") {
          text = event.text || text;
        } else if (event.type === "error") {
          throw new Error(event.error);
        }
      }
    }
    bubble.classList.remove("typing");
    bubble.innerHTML = renderMarkdown(text, false);
    // Claude has now seen the code on screen.
    if (body.code) state.codeChanged = false;

    const code = extractCode(text);
    if (code) {
      setCode(code, { fromChat: true });
      const name = code.match(/^\/\/\s*Navn:\s*(.+)$/m);
      const desc = code.match(/^\/\/\s*Beskrivelse:\s*(.+)$/m);
      if (state.autoName && name) $("name").value = name[1].trim();
      if (state.autoName && desc) $("description").value = desc[1].trim();
    }
  } catch (err) {
    bubble.remove();
    addMessage("error", `Noget gik galt: ${err.message}`);
  } finally {
    state.busy = false;
    $("send").disabled = false;
    $("input").focus();
  }
}

$("composer").addEventListener("submit", (e) => {
  e.preventDefault();
  const message = $("input").value;
  $("input").value = "";
  sendMessage(message);
});
$("input").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    $("composer").requestSubmit();
  }
});
document.querySelectorAll(".ideas button").forEach((b) => {
  b.addEventListener("click", () => sendMessage(b.textContent));
});
$("name").addEventListener("input", () => { state.autoName = false; });
$("description").addEventListener("input", () => { state.autoName = false; });

// ----------------------------------------------------------------- preview ---

let worker = null;
let pixels = null;
let running = false;

function setCode(code, { fromChat }) {
  state.code = code;
  $("code").value = code;
  if (!fromChat) state.codeChanged = true;
  $("deployOnly").disabled = false;
  $("deployAdd").disabled = false;
  $("deployPlaylist").disabled = false;
  startPreview();
}

function setBadge(text, isError) {
  $("badge").textContent = text;
  $("badge").classList.toggle("err", !!isError);
}

function stopPreview() {
  worker?.terminate();
  worker = null;
  running = false;
  $("play").textContent = "▶ Start";
}

function startPreview() {
  stopPreview();
  if (!state.code) return;
  pixels = new Uint8ClampedArray(state.width * state.height * 4);
  worker = new Worker("worker.js");
  worker.onmessage = ({ data }) => {
    if (data.type === "frame") {
      pixels = data.pixels;
    } else if (data.type === "ended") {
      setBadge(`Et gennemløb tager ${data.seconds.toFixed(1)} s · ${data.frames} billeder`);
    } else if (data.type === "error") {
      setBadge(data.error, true);
      stopPreview();
    }
  };
  worker.postMessage({
    code: state.code,
    width: state.width,
    height: state.height,
    speed: Number($("speed").value) / 100,
  });
  running = true;
  setBadge(`Kører · ${state.width} kæder × ${state.height} LED'er`);
  $("play").textContent = "⏹ Stop";
  $("play").disabled = false;
  $("restart").disabled = false;
}

$("play").addEventListener("click", () => (running ? stopPreview() : startPreview()));
$("restart").addEventListener("click", startPreview);
$("speed").addEventListener("input", (e) => {
  $("speedLabel").textContent = (e.target.value / 100).toFixed(1) + "x";
});
// The worker blocks while the script runs, so a new speed means a restart.
$("speed").addEventListener("change", () => running && startPreview());
$("runCode").addEventListener("click", () => setCode($("code").value, { fromChat: false }));

// Drawing: the strings hang from the top of a pole and spread out like a cone.
const canvas = $("tree");
const ctx = canvas.getContext("2d");
let angle = 0;
let lastTime = 0;

// LEDs look much brighter than the same value on a screen; lift the low end.
const GAMMA = new Uint8Array(256).map((_, v) => Math.round(255 * Math.pow(v / 255, 0.55)));

function draw(time) {
  const dt = lastTime ? (time - lastTime) / 1000 : 0;
  lastTime = time;
  if ($("rotate").checked && !$("flat").checked) angle += dt * 0.35;

  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = "#090d0b";
  ctx.fillRect(0, 0, w, h);

  const strings = state.width;
  const leds = state.height;
  const top = 24;
  const bottom = h - 24;
  const step = (bottom - top) / Math.max(1, leds - 1);
  const flat = $("flat").checked;
  const baseRadius = Math.min(w * 0.42, (bottom - top) * 0.42);
  const ledSize = Math.max(1.2, Math.min(3.2, step * 0.42));

  // Pole
  if (!flat) {
    ctx.strokeStyle = "#1f2824";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(w / 2, top - 10);
    ctx.lineTo(w / 2, bottom + 8);
    ctx.stroke();
  }

  // Back strings first so the front ones are drawn on top.
  const order = [...Array(strings).keys()].map((y) => {
    const a = angle + (y / strings) * Math.PI * 2;
    return { y, a, depth: Math.sin(a) };
  }).sort((p, q) => p.depth - q.depth);

  ctx.globalCompositeOperation = "lighter";
  for (const { y, a, depth } of order) {
    const shade = flat ? 1 : 0.4 + 0.6 * (depth + 1) / 2;
    for (let x = 0; x < leds; x++) {
      let sx;
      if (flat) {
        sx = w / 2 + (y - (strings - 1) / 2) * Math.min(60, w / (strings + 1));
      } else {
        const radius = baseRadius * (1 - 0.94 * x / Math.max(1, leds - 1));
        sx = w / 2 + Math.cos(a) * radius;
      }
      const sy = bottom - x * step;
      const i = (y * leds + x) * 4;
      const wv = pixels ? pixels[i + 3] : 0;
      const r = pixels ? GAMMA[Math.min(255, pixels[i] + wv)] * shade : 0;
      const g = pixels ? GAMMA[Math.min(255, pixels[i + 1] + wv)] * shade : 0;
      const b = pixels ? GAMMA[Math.min(255, pixels[i + 2] + wv)] * shade : 0;

      if (r + g + b < 12) {
        ctx.fillStyle = "#1a201d";
        ctx.fillRect(sx - 1, sy - 1, 2, 2);
        continue;
      }
      ctx.fillStyle = `rgba(${r | 0},${g | 0},${b | 0},0.18)`;
      ctx.beginPath();
      ctx.arc(sx, sy, ledSize * 3.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = `rgb(${r | 0},${g | 0},${b | 0})`;
      ctx.beginPath();
      ctx.arc(sx, sy, ledSize, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.globalCompositeOperation = "source-over";
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);

// ------------------------------------------------------------------ deploy ---

async function deploy(mode, playlist) {
  const name = $("name").value.trim();
  if (!name) {
    $("deployNote").textContent = "Giv sekvensen et navn først.";
    $("name").focus();
    return;
  }

  $("deployOnly").disabled = $("deployAdd").disabled = $("deployPlaylist").disabled = true;
  $("deployNote").textContent = mode === "save" ? "Gemmer…" : "Sender til træet…";
  try {
    // The server never overwrites: a taken name becomes "Navn (2)".
    const result = await api("/api/deploy", {
      name,
      description: $("description").value.trim(),
      code: state.code,
      mode,
    });
    const saved = result.name;
    const renamed = result.renamed ? ` Navnet var taget, så den er gemt som “${saved}”; den gamle er urørt.` : "";
    if (playlist) {
      const lists = await loadPlaylists();
      const target = lists.find((p) => p.name === playlist);
      await api("/api/playlists", { name: playlist, sequences: [...(target?.sequences ?? []), saved] });
      await loadPlaylists();
      $("deployNote").textContent = `“${saved}” er gemt i playlisten “${playlist}”.${renamed}`;
    } else {
      $("deployNote").textContent = (mode === "add"
        ? `“${saved}” er med i rotationen (${result.active.length} sekvenser).`
        : `“${saved}” kører nu på træet.`) + renamed;
    }
    $("name").value = saved;
    refreshSequences();
    refreshStatus();
  } catch (err) {
    $("deployNote").textContent = `Kunne ikke gemme: ${err.message}`;
  } finally {
    $("deployOnly").disabled = $("deployAdd").disabled = $("deployPlaylist").disabled = !state.code;
  }
}

$("deployOnly").addEventListener("click", () => deploy("only"));
$("deployAdd").addEventListener("click", () => deploy("add"));
$("deployPlaylist").addEventListener("change", async (e) => {
  let target = e.target.value;
  e.target.value = "";
  if (!target) return;
  if (target === "__new__") {
    target = (prompt("Navn på den nye playliste") || "").trim();
    if (!target) return;
  }
  deploy("save", target);
});

// --------------------------------------------------------------- playlists ---

const pl = { lists: [], editing: null, items: [] };

async function loadPlaylists() {
  try {
    pl.lists = (await api("/api/playlists")).playlists;
  } catch { pl.lists = []; }
  renderPlaylists();
  const select = $("deployPlaylist");
  select.length = 1;
  for (const p of pl.lists) select.add(new Option(`Gem i “${p.name}”`, p.name));
  select.add(new Option("Gem i en ny playliste…", "__new__"));
  return pl.lists;
}

function sameList(a, b) {
  return a.length === b.length && a.every((x, i) => x === b[i]);
}

function renderPlaylists() {
  const box = $("plList");
  box.innerHTML = "";
  if (!pl.lists.length) {
    box.innerHTML = '<div class="pl-empty">Ingen playlister endnu. Lav en med “Ny playliste”.</div>';
    return;
  }
  for (const p of pl.lists) {
    const playing = sameList(p.sequences, state.active || []);
    const card = document.createElement("div");
    card.className = "pl-card" + (playing ? " playing" : "");
    card.innerHTML = `
      <div class="top"><b>${escapeHtml(p.name)}</b>
        ${playing ? '<span class="badge">kører nu</span>' : ""}
        <button class="primary" data-act="play">▶ Afspil</button>
        <button data-act="edit">Ret</button>
        <button data-act="delete">Slet</button></div>
      <div class="seqs">${p.sequences.map(escapeHtml).join(" → ")}</div>`;
    card.querySelector('[data-act="play"]').onclick = () => playPlaylist(p.name);
    card.querySelector('[data-act="edit"]').onclick = () => editPlaylist(p);
    card.querySelector('[data-act="delete"]').onclick = async () => {
      if (!confirm(`Slet playlisten “${p.name}”? Sekvenserne bliver liggende.`)) return;
      await api("/api/playlists/delete", { name: p.name });
      loadPlaylists();
    };
    box.appendChild(card);
  }
}

async function playPlaylist(name) {
  $("plNote").textContent = `Starter “${name}”…`;
  try {
    const r = await api("/api/playlists/play", { name });
    $("plNote").textContent = `“${name}” kører nu (${r.active.length} sekvenser)` +
      (r.missing.length ? `. Findes ikke længere: ${r.missing.join(", ")}` : ".");
    await refreshStatus();
    renderPlaylists();
  } catch (err) {
    $("plNote").textContent = `Kunne ikke afspille: ${err.message}`;
  }
}

function editPlaylist(p, items) {
  pl.editing = p ? p.name : null;
  pl.items = items ?? (p ? [...p.sequences] : []);
  $("plName").value = p ? p.name : "";
  $("plEdit").hidden = false;
  $("plNote").textContent = "";
  const add = $("plAdd");
  add.length = 1;
  for (const name of state.sequences.filter((n) => n !== "Sluk")) add.add(new Option(name, name));
  renderItems();
  $("plName").focus();
}

function renderItems() {
  const ul = $("plItems");
  ul.innerHTML = pl.items.length ? "" : '<li class="pl-empty">Tilføj sekvenser nedenfor. De kører i den rækkefølge.</li>';
  pl.items.forEach((name, i) => {
    const li = document.createElement("li");
    li.innerHTML = `<span>${i + 1}. ${escapeHtml(name)}</span>
      <button data-d="-1" ${i === 0 ? "disabled" : ""} aria-label="Flyt op">↑</button>
      <button data-d="1" ${i === pl.items.length - 1 ? "disabled" : ""} aria-label="Flyt ned">↓</button>
      <button data-x aria-label="Fjern">✕</button>`;
    for (const b of li.querySelectorAll("[data-d]"))
      b.onclick = () => { const j = i + Number(b.dataset.d); [pl.items[i], pl.items[j]] = [pl.items[j], pl.items[i]]; renderItems(); };
    li.querySelector("[data-x]").onclick = () => { pl.items.splice(i, 1); renderItems(); };
    ul.appendChild(li);
  });
}

async function savePlaylist(andPlay) {
  const name = $("plName").value.trim();
  try {
    await api("/api/playlists", { name, oldName: pl.editing ?? name, sequences: pl.items });
    $("plEdit").hidden = true;
    await loadPlaylists();
    if (andPlay) await playPlaylist(name);
    else $("plNote").textContent = `“${name}” er gemt.`;
  } catch (err) {
    $("plNote").textContent = err.message;
  }
}

$("plAdd").addEventListener("change", (e) => {
  if (e.target.value) pl.items.push(e.target.value);
  e.target.value = "";
  renderItems();
});
$("plNew").addEventListener("click", () => editPlaylist(null));
$("plFromNow").addEventListener("click", () => editPlaylist(null, [...(state.active || [])]));
$("plSave").addEventListener("click", () => savePlaylist(false));
$("plSavePlay").addEventListener("click", () => savePlaylist(true));
$("plCancel").addEventListener("click", () => { $("plEdit").hidden = true; });
$("plClose").addEventListener("click", () => $("playlists").close());
$("openPlaylists").addEventListener("click", async () => {
  $("plEdit").hidden = true;
  $("plNote").textContent = "";
  await refreshSequences();
  await loadPlaylists();
  $("playlists").showModal();
});

refreshStatus();
refreshSequences();
loadPlaylists();
setInterval(refreshStatus, 15000);
