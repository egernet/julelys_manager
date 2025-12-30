// Twist - Spiral pattern moving upward with fading tail
const tailLength = 4;
const color = { r: 0, g: 0, b: 0, w: 255 }; // True white

// Clamp value to 0-255 range
function clamp(val) {
    return Math.max(0, Math.min(255, Math.floor(val)));
}

// Calculate tail color with fade effect
function getTailColor(tailIndex) {
    const factor = 0.5 * (1 - tailIndex / tailLength) + 0.2;
    return {
        r: clamp(color.r * factor),
        g: clamp(color.g * factor),
        b: clamp(color.b * factor),
        w: clamp(color.w * factor)
    };
}

// Initialize balls - one per column, staggered start positions
let balls = [];
for (let i = 0; i < matrix.width; i++) {
    balls.push({
        x: -i,  // Staggered start below visible area
        y: i
    });
}

// Animation loop - run until all balls have passed through
while (balls.length > 0) {
    // Clear all pixels to black
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            setPixelColor(0, 0, 0, 0, x, y);
        }
    }

    // Update and draw each ball
    for (let i = balls.length - 1; i >= 0; i--) {
        const ball = balls[i];

        // Move ball up
        ball.x += 1;

        // Draw head
        setPixelColor(color.r, color.g, color.b, color.w, ball.x, ball.y);

        // Draw tail with fading
        for (let t = 1; t <= tailLength; t++) {
            const tailColor = getTailColor(t);
            setPixelColor(
                tailColor.r, tailColor.g,
                tailColor.b, tailColor.w,
                ball.x - t, ball.y
            );
        }

        // Remove ball if it has passed through
        if (ball.x > matrix.height) {
            balls.splice(i, 1);
        }
    }

    updatePixels();
    delay(50);
}
