// 🎶 Dejlig er den himmel blå - lyssekvens
// Alle 8 LED-strenge viser samme node-farve
// Hver node falder ned over 1.5 sek, og ny starter hver 0.4 sek

// Matrix info
let WIDTH = matrix.width;
let HEIGHT = matrix.height;

// Boomwhacker farver (C' = hvid)
let noteColors = {
    "C":  [255, 0, 0, 0],      // Red
    "D":  [255, 128, 0, 0],    // Orange
    "E":  [255, 255, 0, 0],    // Yellow
    "F":  [0, 255, 0, 0],      // Green
    "G":  [0, 255, 255, 0],    // Cyan
    "A":  [0, 0, 255, 0],      // Blue
    "H":  [127, 0, 255, 0],    // Purple
    "C2": [255, 255, 255, 0]   // White (C′)
};

// Melodi (12 toner)
let melody = ["G","A","H","C","C","H","A","G","E","C","E","G"];

// Konstanter for animation
let durationMs = 1500;  // tid fra top til bund
let intervalMs = 400;   // mellemrum mellem noder
let fps = 24;           // 24 billeder/sekund
let totalFrames = Math.ceil(((melody.length - 1) * intervalMs + durationMs) / (1000 / fps));
let trail = 8;          // hale-længde i pixels

// Aktiv note-struktur
let activeNotes = [];

for (let frame = 0; frame < totalFrames; frame++) {

    // Start nye noter i rækkefølge
    for (let i = 0; i < melody.length; i++) {
        let startFrame = Math.floor((i * intervalMs) / (1000 / fps));
        if (frame === startFrame) {
            activeNotes.push({
                note: melody[i],
                frameStart: frame
            });
        }
    }

    // Ryd matrix
    for (let y = 0; y < WIDTH; y++) {
        for (let x = 0; x < HEIGHT; x++) {
            setPixelColor(0, 0, 0, 0, x, y);
        }
    }

    // Tegn aktive noter
    let stillActive = [];
    for (let n of activeNotes) {
        let t = frame - n.frameStart;
        let totalNoteFrames = Math.floor(durationMs / (1000 / fps));
        if (t < totalNoteFrames) {
            let pos = (t / totalNoteFrames) * (HEIGHT + trail * 2) - trail;
            let c = noteColors[n.note] || [255,255,255,0];
            for (let y = 0; y < HEIGHT; y++) {
                let dist = pos - y;
                if (dist >= 0 && dist < trail) {
                    let fade = 1.0 - (dist / trail);
                    let r = Math.floor(c[0] * fade);
                    let g = Math.floor(c[1] * fade);
                    let b = Math.floor(c[2] * fade);
                    let w = Math.floor(c[3] * fade);
                    for (let x = 0; x < WIDTH; x++) {
                        setPixelColor(r, g, b, w, y, x);
                    }
                }
            }
            stillActive.push(n);
        }
    }

    activeNotes = stillActive;
    updatePixels();
}
