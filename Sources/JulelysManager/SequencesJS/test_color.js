// Test Color - Sequential RGBW color test
const colors = [
    { r: 255, g: 0, b: 0, w: 0 },    // Red
    { r: 0, g: 255, b: 0, w: 0 },    // Green
    { r: 0, g: 0, b: 255, w: 0 },    // Blue
    { r: 0, g: 0, b: 0, w: 255 },    // True White
    { r: 0, g: 0, b: 0, w: 0 }       // Black (off)
];

const holdTime = 1000; // 1 second per color

// Cycle through each color
for (let c = 0; c < colors.length; c++) {
    const color = colors[c];

    // Fill entire matrix with current color
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            setPixelColor(color.r, color.g, color.b, color.w, x, y);
        }
    }

    updatePixels();
    delay(holdTime);
}
