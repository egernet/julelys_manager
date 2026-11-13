// Julelys web: chat with Claude to write sequences, preview them in the browser
// and send them to the lights through the manager's unix socket.
//
// Runs next to JulelysManager. Plain node:http, no framework; Node >= 22.18 runs
// this file directly (type stripping), so only erasable TypeScript is used.

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { connect } from "node:net";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { join, extname, normalize } from "node:path";
import { homedir } from "node:os";
import { query } from "@anthropic-ai/claude-agent-sdk";

const PORT = Number(process.env.JULELYS_WEB_PORT ?? 8080);
const SOCKET = process.env.JULELYS_SOCKET ?? "/tmp/julelys.sock";
const MODEL = process.env.JULELYS_MODEL ?? "claude-sonnet-5-5";
const PUBLIC_DIR = join(import.meta.dirname, "public");
// Claude sessions are stored per working directory, so keep them out of the way.
const SESSION_DIR = join(homedir(), "Julelys", "web-sessions");

// ---------------------------------------------------------------- manager ---

type Json = Record<string, unknown>;

/** Sends one request to the manager and returns its JSON reply. */
function manager(request: Json): Promise<Json> {
  return new Promise((resolve, reject) => {
    const socket = connect(SOCKET);
    const chunks: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("Manageren svarer ikke")));
    socket.on("connect", () => socket.write(JSON.stringify(request) + "\n"));
    socket.on("data", (chunk) => chunks.push(chunk));
    socket.on("error", (err) => reject(new Error(`Kan ikke tale med manageren: ${err.message}`)));
    socket.on("end", () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch {
        reject(new Error("Ugyldigt svar fra manageren"));
      }
    });
  });
}

// ----------------------------------------------------------------- claude ---

function systemPrompt(width: number, height: number): string {
  return `Du skriver lyssekvenser i JavaScript til et juletræ med LED-lyskæder.

Træet: ${width} lyskæder med ${height} RGB-LED'er hver. Kæderne hænger fra toppen af en
stang og spredes ud som en kegle, så de danner et juletræ set udefra.

Koordinater:
- x = LED'ens nummer langs kæden: 0 er nederst ved jorden, ${height - 1} er i toppen.
- y = kædens nummer, 0 .. ${width - 1}, rundt om træet.

API (det er alt, der findes - ingen DOM, ingen setTimeout, ingen async/await):
- setPixelColor(r, g, b, w, x, y)  sætter én LED. Værdier 0-255. w lægges oven i r, g og b.
- updatePixels()                    viser det, der er sat, som ét billede.
- delay(ms)                         venter synkront.
- matrix.width (= ${width}) og matrix.height (= ${height}).
- Math og almindelig JavaScript virker.

Regler for koden:
- Skriv en fast løkke over frames: sæt alle LED'er, kald updatePixels(), og derefter delay(20-50).
- Scriptet skal slutte af sig selv efter 20-60 sekunder (fx en for-løkke over et antal frames).
  Det bliver startet forfra automatisk, og sekvenser kører på skift med andre.
- Brug en clamp-funktion, så farver altid er heltal mellem 0 og 255.
- Hold lysstyrken moderat: samlet set højst omkring 40 % af fuld hvid på alle LED'er,
  ellers bliver strømforbruget for stort. Enkelte LED'er må gerne være klare.
- Brug matrix.width og matrix.height i stedet for faste tal.
- Pixels bevarer deres farve, til de sættes igen, så sæt alle LED'er i hver frame.

Svar på dansk. Skriv kort, hvad sekvensen gør, og giv derefter præcis én komplet
kodeblok i \`\`\`javascript. De to første linjer i koden skal være:
// Navn: <kort navn på dansk>
// Beskrivelse: <én sætning>
Når brugeren beder om ændringer, så giv hele den opdaterede kode igen, ikke kun et uddrag.`;
}

/** Maps the browser's chat id to the Claude session, so follow-ups resume it. */
const sessions = new Map<string, string>();

async function chat(res: ServerResponse, body: Json): Promise<void> {
  const chatId = String(body.chatId ?? "");
  const message = String(body.message ?? "").trim();
  const code = typeof body.code === "string" ? body.code : "";
  if (!chatId || !message) return sendJson(res, 400, { error: "chatId og message mangler" });

  const status = await manager({ cmd: "getStatus" }).catch(() => ({} as Json));
  const width = Number(status.matrixWidth ?? 4);
  const height = Number(status.matrixHeight ?? 125);

  // The browser sends the code when it was changed outside this chat (loaded
  // from the lights or edited by hand), so Claude works from what is on screen.
  const prompt = code
    ? `Her er den kode, der vises lige nu:\n\`\`\`javascript\n${code}\n\`\`\`\n\n${message}`
    : message;

  res.writeHead(200, {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  const send = (event: Json) => res.write(`data: ${JSON.stringify(event)}\n\n`);

  const abort = new AbortController();
  res.on("close", () => abort.abort());

  try {
    await mkdir(SESSION_DIR, { recursive: true });
    const resume = sessions.get(chatId);
    for await (const msg of query({
      prompt,
      options: {
        model: MODEL,
        systemPrompt: systemPrompt(width, height),
        tools: [],
        settingSources: [],
        maxTurns: 1,
        permissionMode: "dontAsk",
        includePartialMessages: true,
        cwd: SESSION_DIR,
        resume,
        abortController: abort,
        env: { ...process.env, CLAUDE_AGENT_SDK_CLIENT_APP: "julelys-web/1.0" },
      },
    })) {
      if (msg.type === "stream_event") {
        const event = msg.event;
        if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
          send({ type: "text", text: event.delta.text });
        }
      } else if (msg.type === "result") {
        sessions.set(chatId, msg.session_id);
        if (msg.subtype === "success") {
          send({ type: "done", text: msg.result });
        } else {
          send({ type: "error", error: `Claude stoppede: ${msg.subtype}` });
        }
      }
    }
  } catch (err) {
    if (!abort.signal.aborted) send({ type: "error", error: errorText(err) });
  }
  res.end();
}

// ------------------------------------------------------------------ deploy ---

/** True when the manager lists the name but has no custom code for it. */
async function isBuiltIn(name: string): Promise<boolean> {
  const list = await manager({ cmd: "getSequences" });
  const known = ((list.sequences as Json[] | undefined) ?? []).some((s) => s.name === name);
  if (!known) return false;
  const seq = await manager({ cmd: "getSequenceCode", sequenceName: name });
  return seq.isCustom !== true;
}

/** Saves a sequence on the manager and starts it, alone or added to the rotation. */
async function deploy(body: Json): Promise<Json> {
  const name = String(body.name ?? "").trim();
  const description = String(body.description ?? "").trim() || name;
  const code = String(body.code ?? "");
  const mode = body.mode === "add" ? "add" : "only";
  if (!name || !code) throw new Error("Navn og kode mangler");

  // getSequenceCode says isCustom false both for built-ins and for names it does
  // not know, so look the name up in the list to tell a new name from a built-in.
  if (await isBuiltIn(name)) {
    throw new Error(`"${name}" er en indbygget sekvens. Vælg et andet navn.`);
  }
  const existing = await manager({ cmd: "getSequenceCode", sequenceName: name });
  if (existing.isCustom === true) {
    const updated = await manager({
      cmd: "updateSequence", sequenceName: name, sequenceDescription: description, jsCode: code,
    });
    if (updated.status === "error") throw new Error(String(updated.error));
  } else {
    const created = await manager({
      cmd: "createSequence", sequenceName: name, sequenceDescription: description, jsCode: code,
    });
    if (created.status !== "created") throw new Error(String(created.error ?? "Kunne ikke gemme"));
  }

  let names = [name];
  if (mode === "add") {
    // Adding while the tree is off continues the rotation from before "Sluk".
    const active = await rotation();
    names = active.includes(name) ? active : [...active, name];
  }
  await manager({ cmd: "runSequences", names });
  return { ok: true, active: names };
}

// ------------------------------------------------------------------- power ---

/** The all-black sequence. It never belongs in a rotation. */
const OFF = "Sluk";
const BEFORE_OFF_FILE = join(homedir(), "Julelys", "web-before-off.json");

async function activeSequences(): Promise<string[]> {
  const status = await manager({ cmd: "getStatus" });
  return ((status.activeSequences as string[] | undefined) ?? []).filter((n) => n !== OFF);
}

/** What is running now, or what ran before the tree was switched off. */
async function rotation(): Promise<string[]> {
  const active = await activeSequences();
  if (active.length) return active;
  try {
    const saved = JSON.parse(await readFile(BEFORE_OFF_FILE, "utf8"));
    return Array.isArray(saved) ? saved.map(String).filter((n) => n !== OFF) : [];
  } catch {
    return [];
  }
}

async function power(on: boolean): Promise<Json> {
  if (on) {
    const names = await rotation();
    if (!names.length) throw new Error("Der er ingen tidligere sekvenser at tænde med");
    await manager({ cmd: "runSequences", names });
    return { ok: true, active: names };
  }
  const active = await activeSequences();
  if (active.length) await writeFile(BEFORE_OFF_FILE, JSON.stringify(active));
  await manager({ cmd: "runSequences", names: [OFF] });
  return { ok: true, active: [OFF] };
}

// ------------------------------------------------------------------- http ---

const CONTENT_TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
};

function sendJson(res: ServerResponse, status: number, data: unknown): void {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(data));
}

function errorText(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

async function readBody(req: IncomingMessage): Promise<Json> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 1 << 20) throw new Error("For stor forespørgsel");
    chunks.push(chunk);
  }
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString("utf8")) : {};
}

async function serveStatic(res: ServerResponse, path: string): Promise<void> {
  const file = normalize(join(PUBLIC_DIR, path === "/" ? "index.html" : path));
  if (!file.startsWith(PUBLIC_DIR)) return sendJson(res, 404, { error: "Ikke fundet" });
  try {
    const data = await readFile(file);
    res.writeHead(200, {
      "Content-Type": CONTENT_TYPES[extname(file)] ?? "application/octet-stream",
      "Cache-Control": "no-cache",
    });
    res.end(data);
  } catch {
    sendJson(res, 404, { error: "Ikke fundet" });
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", "http://localhost");
  try {
    if (req.method === "POST" && url.pathname === "/api/chat") {
      return await chat(res, await readBody(req));
    }
    if (req.method === "POST" && url.pathname === "/api/deploy") {
      return sendJson(res, 200, await deploy(await readBody(req)));
    }
    if (req.method === "POST" && url.pathname === "/api/power") {
      const body = await readBody(req);
      return sendJson(res, 200, await power(body.on === true));
    }
    if (req.method === "POST" && url.pathname === "/api/run") {
      const body = await readBody(req);
      const names = Array.isArray(body.names) ? body.names.map(String) : [];
      return sendJson(res, 200, await manager({ cmd: "runSequences", names }));
    }
    if (req.method === "GET" && url.pathname === "/api/status") {
      return sendJson(res, 200, await manager({ cmd: "getStatus" }));
    }
    if (req.method === "GET" && url.pathname === "/api/sequences") {
      return sendJson(res, 200, await manager({ cmd: "getSequences" }));
    }
    if (req.method === "GET" && url.pathname === "/api/sequence") {
      const name = url.searchParams.get("name") ?? "";
      const seq = await manager({ cmd: "getSequenceCode", sequenceName: name });
      // Built-ins come back with their code too, but isCustom false.
      if (typeof seq.jsCode !== "string") {
        const error = (await isBuiltIn(name))
          ? `Kunne ikke læse koden til "${name}"`
          : `Sekvensen "${name}" findes ikke`;
        return sendJson(res, 200, { ...seq, error });
      }
      return sendJson(res, 200, { ...seq, error: undefined });
    }
    if (req.method === "GET") return await serveStatic(res, url.pathname);
    sendJson(res, 404, { error: "Ikke fundet" });
  } catch (err) {
    if (!res.headersSent) sendJson(res, 500, { error: errorText(err) });
    else res.end();
  }
});

server.listen(PORT, () => {
  console.log(`🎄 Julelys web på http://0.0.0.0:${PORT} (model ${MODEL}, socket ${SOCKET})`);
});
