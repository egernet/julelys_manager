// Matrix effect - falling streams like The Matrix movie
const maxLength = 4;
const numberOfStreams = 100;
const frameDelay = 100;

// Colors for the streams (green by default)
const colors = [
    { r: 0, g: 255, b: 0, w: 0 }
];

// Active streams
let streams = [];
let remainingToAdd = numberOfStreams;

// Create a new stream at random position
function addStream() {
    if (remainingToAdd <= 0) return;

    // Random chance to add (not every frame)
    const startCol = Math.floor(Math.random() * (matrix.width + 1));
    if (startCol >= matrix.width) return;

    const colorIndex = Math.floor(Math.random() * colors.length);
    streams.push({
        x: matrix.height,  // Start above the top
        y: startCol,
        length: Math.floor(Math.random() * maxLength) + 1,
        speed: Math.floor(Math.random() * 2) + 1,
        color: colors[colorIndex]
    });

    remainingToAdd--;
}

// Clamp value to 0-255 range
function clamp(val) {
    return Math.max(0, Math.min(255, Math.floor(val)));
}

// Calculate tail color with fade effect
function getTailColor(stream, tailIndex) {
    const factor = 0.5 * (1 - tailIndex / stream.length) + 0.2;
    return {
        r: clamp(stream.color.r * factor),
        g: clamp(stream.color.g * factor),
        b: clamp(stream.color.b * factor),
        w: clamp(stream.color.w * factor)
    };
}

// Main animation loop
while (remainingToAdd > 0 || streams.length > 0) {
    // Clear all pixels to black
    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            setPixelColor(0, 0, 0, 0, x, y);
        }
    }

    // Update and draw each stream
    for (let i = streams.length - 1; i >= 0; i--) {
        const stream = streams[i];

        // Move stream down
        stream.x -= stream.speed;

        // Draw head
        setPixelColor(
            stream.color.r, stream.color.g,
            stream.color.b, stream.color.w,
            stream.x, stream.y
        );

        // Draw tail with fading
        for (let t = 1; t <= stream.length; t++) {
            const tailColor = getTailColor(stream, t);
            setPixelColor(
                tailColor.r, tailColor.g,
                tailColor.b, tailColor.w,
                stream.x + t, stream.y
            );
        }

        // Remove stream if it has fallen off
        if (stream.x <= -stream.length) {
            streams.splice(i, 1);
        }
    }

    // Try to add a new stream
    addStream();

    updatePixels();
    delay(frameDelay);
}
