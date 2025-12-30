// Fireworks - Bursting colorful fireworks with elastic easing
const numberOfFireworks = 800;

// Available colors for fireworks
const colors = [
    { r: 255, g: 105, b: 180, w: 0 },  // Pink
    { r: 0, g: 255, b: 0, w: 0 },      // Green
    { r: 0, g: 0, b: 255, w: 0 },      // Blue
    { r: 255, g: 0, b: 0, w: 0 },      // Red
    { r: 255, g: 255, b: 0, w: 0 },    // Yellow
    { r: 0, g: 0, b: 0, w: 255 },      // True White
    { r: 128, g: 0, b: 128, w: 0 },    // Purple
    { r: 255, g: 0, b: 255, w: 0 },    // Magenta
    { r: 255, g: 165, b: 0, w: 0 }     // Orange
];

// Elastic ease in-out function
function easeInOutElastic(x) {
    const c5 = (2 * Math.PI) / 4.5;

    if (x === 0) return 0;
    if (x === 1) return 1;
    if (x < 0.5) {
        return -(Math.pow(2, 20 * x - 10) * Math.sin((20 * x - 11.125) * c5)) / 2;
    }
    return (Math.pow(2, -20 * x + 10) * Math.sin((20 * x - 11.125) * c5)) / 2 + 1;
}

// Active fireworks
let fireworks = [];
let remainingToAdd = numberOfFireworks;

// Current batch color (changes periodically)
let currentColor = colors[Math.floor(Math.random() * colors.length)];
let colorChangeCounter = 0;

// Add a new firework at random position
function addFirework() {
    if (remainingToAdd <= 0) return;

    const col = Math.floor(Math.random() * (matrix.width + 1));
    if (col >= matrix.width) return;

    const row = Math.floor(Math.random() * matrix.height);
    const point = { x: row, y: col };

    // Don't add if a firework already exists at this position
    if (fireworks.some(f => f.x === point.x && f.y === point.y)) return;

    // Change color occasionally
    colorChangeCounter++;
    if (colorChangeCounter > 50) {
        currentColor = colors[Math.floor(Math.random() * colors.length)];
        colorChangeCounter = 0;
    }

    const factor = 0.1 + Math.random() * 0.1; // Random speed 0.1-0.2
    fireworks.push({
        x: point.x,
        y: point.y,
        color: { ...currentColor },
        time: 0,
        value: factor,
        factor: factor,
        isDone: false
    });

    remainingToAdd--;
}

// Clamp value to 0-255 range
function clamp(val) {
    return Math.max(0, Math.min(255, Math.floor(val)));
}

// Get current firework brightness
function getFireworkColor(fw) {
    fw.time += fw.value;

    if (fw.time >= 1) {
        fw.value = -fw.factor;
    }

    if (fw.time <= 0) {
        fw.time = 0;
        fw.isDone = true;
    }

    const brightness = easeInOutElastic(fw.time);
    return {
        r: clamp(fw.color.r * brightness),
        g: clamp(fw.color.g * brightness),
        b: clamp(fw.color.b * brightness),
        w: clamp(fw.color.w * brightness)
    };
}

// Main animation loop
while (remainingToAdd > 0 || fireworks.length > 0) {
    // Clear all pixels to black
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            setPixelColor(0, 0, 0, 0, x, y);
        }
    }

    // Update and draw each firework
    for (let i = fireworks.length - 1; i >= 0; i--) {
        const fw = fireworks[i];
        const fwColor = getFireworkColor(fw);

        setPixelColor(fwColor.r, fwColor.g, fwColor.b, fwColor.w, fw.x, fw.y);

        if (fw.isDone) {
            fireworks.splice(i, 1);
        }
    }

    // Add multiple fireworks per frame
    for (let j = 0; j < 5; j++) {
        addFirework();
    }

    updatePixels();
    delay(16); // ~60fps
}
