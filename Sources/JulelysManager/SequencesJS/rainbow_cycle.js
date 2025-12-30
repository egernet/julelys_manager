// Rainbow Cycle - Color wheel rotation across the LED matrix
const iterations = 5;
const frameDelay = 30;

// Color wheel function - returns RGB based on position (0-255)
function wheel(pos) {
    pos = pos & 255;

    if (pos < 85) {
        return {
            r: pos * 3,
            g: 255 - pos * 3,
            b: 0
        };
    } else if (pos < 170) {
        pos -= 85;
        return {
            r: 255 - pos * 3,
            g: 0,
            b: pos * 3
        };
    } else {
        pos -= 170;
        return {
            r: 0,
            g: pos * 3,
            b: 255 - pos * 3
        };
    }
}

// Main animation loop
for (let i = 0; i < 255 * iterations; i++) {
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            const index = Math.floor((x * 255 / matrix.height) + i) & 255;
            const color = wheel(index);
            setPixelColor(color.r, color.g, color.b, 0, x, y);
        }
    }

    updatePixels();
    delay(frameDelay);
}
