// Fade Color - Alternating red fade with green stripes
const fadeSpeed = 1;
const iterations = 510; // Full fade up and down

let redValue = 0;
let goingUp = true;

for (let frame = 0; frame < iterations; frame++) {
    // Draw alternating pattern
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            const pos = y * matrix.height + x;

            if (pos % 2 === 0) {
                // Even pixels: fading red
                setPixelColor(redValue, 0, 0, 0, x, y);
            } else {
                // Odd pixels: static green
                setPixelColor(0, 255, 0, 0, x, y);
            }
        }
    }

    updatePixels();

    // Update red value
    if (goingUp) {
        redValue += fadeSpeed;
        if (redValue >= 255) {
            redValue = 255;
            goingUp = false;
        }
    } else {
        redValue -= fadeSpeed;
        if (redValue <= 0) {
            redValue = 0;
            goingUp = true;
        }
    }

    delay(10);
}
