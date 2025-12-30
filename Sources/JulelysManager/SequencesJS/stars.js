// Stars - Twinkling stars with elastic easing animation
const numberOfStars = 600;
const color = { r: 0, g: 0, b: 0, w: 255 }; // True white

// Elastic ease in-out function for smooth pulsing
function easeInOutElastic(x) {
    const c5 = (2 * Math.PI) / 4.5;

    if (x === 0) return 0;
    if (x === 1) return 1;
    if (x < 0.5) {
        return -(Math.pow(2, 20 * x - 10) * Math.sin((20 * x - 11.125) * c5)) / 2;
    }
    return (Math.pow(2, -20 * x + 10) * Math.sin((20 * x - 11.125) * c5)) / 2 + 1;
}

// Active stars
let stars = [];
let remainingToAdd = numberOfStars;

// Add a new star at random position
function addStar() {
    if (remainingToAdd <= 0) return;

    const col = Math.floor(Math.random() * (matrix.width + 1));
    if (col >= matrix.width) return;

    const row = Math.floor(Math.random() * matrix.height);
    const point = { x: row, y: col };

    // Don't add if a star already exists at this position
    if (stars.some(s => s.x === point.x && s.y === point.y)) return;

    stars.push({
        x: point.x,
        y: point.y,
        time: 0,
        value: 0.1,
        isDone: false
    });

    remainingToAdd--;
}

// Clamp value to 0-255 range
function clamp(val) {
    return Math.max(0, Math.min(255, Math.floor(val)));
}

// Get current star brightness
function getStarColor(star) {
    star.time += star.value;

    if (star.time >= 1) {
        star.value = -0.1;
    }

    if (star.time <= 0) {
        star.time = 0;
        star.isDone = true;
    }

    const factor = easeInOutElastic(star.time);
    return {
        r: clamp(color.r * factor),
        g: clamp(color.g * factor),
        b: clamp(color.b * factor),
        w: clamp(color.w * factor)
    };
}

// Main animation loop
while (remainingToAdd > 0 || stars.length > 0) {
    // Clear all pixels to black
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            setPixelColor(0, 0, 0, 0, x, y);
        }
    }

    // Update and draw each star
    for (let i = stars.length - 1; i >= 0; i--) {
        const star = stars[i];
        const starColor = getStarColor(star);

        setPixelColor(starColor.r, starColor.g, starColor.b, starColor.w, star.x, star.y);

        if (star.isDone) {
            stars.splice(i, 1);
        }
    }

    // Add multiple stars per frame
    for (let j = 0; j < 5; j++) {
        addStar();
    }

    updatePixels();
    delay(16); // ~60fps
}
