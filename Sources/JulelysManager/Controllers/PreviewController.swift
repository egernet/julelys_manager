import Foundation

/// Controller that generates HTML previews for LED sequences
class PreviewController {
    let matrixHeight: Int
    let matrixWidth: Int

    init(matrixWidth: Int, matrixHeight: Int, maxFrames: Int = 30, frameDelay: Int = 33) {
        self.matrixWidth = matrixWidth
        self.matrixHeight = matrixHeight
    }

    /// Generate HTML with embedded JS code that runs in the browser
    func generateHTMLWithCode(sequenceName: String, jsCode: String) -> String {
        // Transform delay(ms) to await delay(ms) for browser async compatibility
        let transformedCode = jsCode
            .replacingOccurrences(of: "delay(", with: "await delay(", options: [], range: nil)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Preview: \(sequenceName)</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: #111;
                    color: #fff;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    padding: 20px;
                }
                h1 { margin-bottom: 10px; font-size: 1.5em; }
                .info { color: #888; margin-bottom: 20px; font-size: 0.9em; }
                canvas {
                    border-radius: 8px;
                    box-shadow: 0 0 30px rgba(255,255,255,0.1);
                }
                .controls {
                    margin-top: 20px;
                    display: flex;
                    gap: 10px;
                    align-items: center;
                    flex-wrap: wrap;
                    justify-content: center;
                }
                button {
                    background: #333;
                    color: #fff;
                    border: none;
                    padding: 8px 16px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 14px;
                }
                button:hover { background: #444; }
                button.active { background: #0a0; }
                button:disabled { opacity: 0.5; cursor: not-allowed; }
                .speed-control {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                input[type="range"] { width: 100px; }
                .status {
                    color: #888;
                    font-size: 0.85em;
                    min-width: 100px;
                    text-align: center;
                }
                .status.running { color: #0f0; }
            </style>
        </head>
        <body>
            <h1>\(sequenceName)</h1>
            <div class="info">\(matrixWidth) x \(matrixHeight) LED matrix</div>
            <canvas id="led"></canvas>
            <div class="controls">
                <button id="startStop" class="active">⏹ Stop</button>
                <button id="restart">🔄 Restart</button>
                <div class="speed-control">
                    <span>Speed:</span>
                    <input type="range" id="speed" min="10" max="200" value="100">
                    <span id="speedLabel">1x</span>
                </div>
                <div class="status" id="status">Running...</div>
            </div>

            <script>
            // LED Matrix simulation
            const WIDTH = \(matrixWidth);
            const HEIGHT = \(matrixHeight);
            const SCALE = 12;
            const LED_RADIUS = 5;

            const canvas = document.getElementById('led');
            const ctx = canvas.getContext('2d');
            canvas.width = WIDTH * SCALE;
            canvas.height = HEIGHT * SCALE;

            // Pixel buffer [row][col] = [r, g, b, w]
            let pixels = [];
            for (let row = 0; row < HEIGHT; row++) {
                pixels[row] = [];
                for (let col = 0; col < WIDTH; col++) {
                    pixels[row][col] = [0, 0, 0, 0];
                }
            }

            let speedMultiplier = 1.0;
            let shouldStop = false;
            let isRunning = false;

            // API functions matching the Swift implementation
            const matrix = {
                width: WIDTH,
                height: HEIGHT
            };

            function setPixelColor(r, g, b, w, x, y) {
                if (x >= 0 && x < HEIGHT && y >= 0 && y < WIDTH) {
                    pixels[x][y] = [r, g, b, w];
                }
            }

            function updatePixels() {
                ctx.fillStyle = '#000';
                ctx.fillRect(0, 0, canvas.width, canvas.height);

                for (let row = 0; row < HEIGHT; row++) {
                    for (let col = 0; col < WIDTH; col++) {
                        const [r, g, b, w] = pixels[row][col];
                        // Combine RGBW to RGB
                        const rr = Math.min(255, r + w / 2);
                        const gg = Math.min(255, g + w / 2);
                        const bb = Math.min(255, b + w / 2);

                        const x = col * SCALE + SCALE / 2;
                        const y = row * SCALE + SCALE / 2;

                        // Glow effect
                        if (rr > 20 || gg > 20 || bb > 20) {
                            const gradient = ctx.createRadialGradient(x, y, 0, x, y, LED_RADIUS * 1.5);
                            gradient.addColorStop(0, `rgba(${rr},${gg},${bb},0.8)`);
                            gradient.addColorStop(1, `rgba(${rr},${gg},${bb},0)`);
                            ctx.fillStyle = gradient;
                            ctx.beginPath();
                            ctx.arc(x, y, LED_RADIUS * 1.5, 0, Math.PI * 2);
                            ctx.fill();
                        }

                        // LED circle
                        ctx.fillStyle = `rgb(${rr},${gg},${bb})`;
                        ctx.beginPath();
                        ctx.arc(x, y, LED_RADIUS, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }

            function delay(ms) {
                if (shouldStop) throw new Error('stopped');
                return new Promise((resolve, reject) => {
                    const timeout = setTimeout(() => resolve(), ms / speedMultiplier);
                    // Check for stop during delay
                    const check = setInterval(() => {
                        if (shouldStop) {
                            clearTimeout(timeout);
                            clearInterval(check);
                            reject(new Error('stopped'));
                        }
                    }, 50);
                });
            }

            // Clear all pixels
            function clearPixels() {
                for (let row = 0; row < HEIGHT; row++) {
                    for (let col = 0; col < WIDTH; col++) {
                        pixels[row][col] = [0, 0, 0, 0];
                    }
                }
                updatePixels();
            }

            // The sequence code
            async function runSequence() {
                \(transformedCode)
            }

            async function start() {
                shouldStop = false;
                isRunning = true;
                document.getElementById('status').textContent = 'Running...';
                document.getElementById('status').className = 'status running';
                document.getElementById('startStop').textContent = '⏹ Stop';
                document.getElementById('startStop').classList.add('active');

                try {
                    await runSequence();
                    document.getElementById('status').textContent = 'Finished';
                } catch (e) {
                    if (e.message !== 'stopped') {
                        document.getElementById('status').textContent = 'Error: ' + e.message;
                        console.error(e);
                    } else {
                        document.getElementById('status').textContent = 'Stopped';
                    }
                }

                isRunning = false;
                document.getElementById('status').className = 'status';
                document.getElementById('startStop').textContent = '▶ Start';
                document.getElementById('startStop').classList.remove('active');
            }

            function stop() {
                shouldStop = true;
            }

            // Controls
            document.getElementById('startStop').addEventListener('click', function() {
                if (isRunning) {
                    stop();
                } else {
                    start();
                }
            });

            document.getElementById('restart').addEventListener('click', function() {
                stop();
                clearPixels();
                setTimeout(() => start(), 100);
            });

            document.getElementById('speed').addEventListener('input', function() {
                speedMultiplier = this.value / 100;
                document.getElementById('speedLabel').textContent = speedMultiplier.toFixed(1) + 'x';
            });

            // Initial render and start
            updatePixels();
            start();
            </script>
        </body>
        </html>
        """
    }
}
