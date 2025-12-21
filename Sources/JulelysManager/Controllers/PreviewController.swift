import Foundation

/// Controller that captures frames from a sequence for preview generation
class PreviewController: SequenceDelegate {
    let matrixHeight: Int
    let matrixWidth: Int
    private let maxFrames: Int
    private let frameDelay: Int // milliseconds between frames for GIF

    private var frameBuffer: [[Color]]
    private var capturedFrames: [[[Color]]] = []
    private var frameCount = 0
    private var shouldStop = false

    init(matrixWidth: Int, matrixHeight: Int, maxFrames: Int = 30, frameDelay: Int = 33) {
        self.matrixWidth = matrixWidth
        self.matrixHeight = matrixHeight
        self.maxFrames = maxFrames
        self.frameDelay = frameDelay

        // Initialize frame buffer [x][y] where x=row (0..height-1), y=col (0..width-1)
        self.frameBuffer = Array(repeating: Array(repeating: Color.black, count: matrixWidth), count: matrixHeight)
    }

    /// Run a sequence and capture frames, returns path to generated GIF
    func captureSequence(_ sequence: SequenceType, outputPath: String) -> Result<String, PreviewError> {
        var seq = sequence
        seq.delegate = self
        capturedFrames = []
        frameCount = 0
        shouldStop = false

        // Run sequence in a limited way - it will stop when maxFrames is reached
        seq.runSequence()

        if capturedFrames.isEmpty {
            return .failure(.noFramesCaptured)
        }

        // Generate GIF from captured frames
        return generateGIF(outputPath: outputPath)
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

    private func generateGIF(outputPath: String) -> Result<String, PreviewError> {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("julelys_preview_\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            return .failure(.fileError("Failed to create temp directory: \(error.localizedDescription)"))
        }

        // Write frames as PPM files (simple format, no external dependencies)
        for (index, frame) in capturedFrames.enumerated() {
            let ppmPath = tempDir.appendingPathComponent(String(format: "frame_%04d.ppm", index))
            if !writePPM(frame: frame, to: ppmPath) {
                return .failure(.fileError("Failed to write frame \(index)"))
            }
        }

        // Try to create GIF using available tools
        let gifResult = createGIF(fromFramesIn: tempDir, outputPath: outputPath)

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDir)

        return gifResult
    }

    private func writePPM(frame: [[Color]], to url: URL) -> Bool {
        // PPM format: simple image format
        // Scale up the LED matrix for visibility (each LED = 10x10 pixels)
        let scale = 10
        let radius = scale / 2  // Circle radius
        let radiusSquared = (radius - 1) * (radius - 1)  // Slightly smaller for nicer look

        // Image dimensions: width = columns (matrixWidth), height = rows (matrixHeight)
        let imageWidth = matrixWidth * scale
        let imageHeight = matrixHeight * scale

        let ppm = "P6\n\(imageWidth) \(imageHeight)\n255\n"
        var pixels = Data()
        pixels.reserveCapacity(imageWidth * imageHeight * 3)

        // Iterate over each pixel in the output image
        for row in 0..<imageHeight {
            let ledX = row / scale  // Which LED row
            let localY = row % scale - radius  // Y offset from LED center

            for col in 0..<imageWidth {
                let ledY = col / scale  // Which LED column
                let localX = col % scale - radius  // X offset from LED center

                // Check if this pixel is inside the circle
                let distSquared = localX * localX + localY * localY

                if distSquared <= radiusSquared {
                    // Inside circle - use LED color
                    let color = frame[ledX][ledY]
                    let r = min(255, Int(color.red) + Int(color.white) / 2)
                    let g = min(255, Int(color.green) + Int(color.white) / 2)
                    let b = min(255, Int(color.blue) + Int(color.white) / 2)
                    pixels.append(UInt8(r))
                    pixels.append(UInt8(g))
                    pixels.append(UInt8(b))
                } else {
                    // Outside circle - black background
                    pixels.append(0)
                    pixels.append(0)
                    pixels.append(0)
                }
            }
        }

        guard let headerData = ppm.data(using: .ascii) else { return false }

        var fileData = Data()
        fileData.append(headerData)
        fileData.append(pixels)

        do {
            try fileData.write(to: url)
            return true
        } catch {
            return false
        }
    }

    private func createGIF(fromFramesIn tempDir: URL, outputPath: String) -> Result<String, PreviewError> {
        let outputURL = URL(fileURLWithPath: outputPath)

        // Ensure output directory exists
        let outputDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Get list of PPM files sorted by name
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return .failure(.fileError("Could not list frame files"))
        }

        let ppmFiles = files
            .filter { $0.pathExtension == "ppm" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { $0.path }

        if ppmFiles.isEmpty {
            return .failure(.fileError("No PPM frames found"))
        }

        fputs("🎬 Found \(ppmFiles.count) frames to convert\n", stderr)

        // Try ImageMagick 7 first (uses 'magick' command)
        var magickArgs = ["magick", "-delay", "\(frameDelay / 10)", "-loop", "0"]
        magickArgs.append(contentsOf: ppmFiles)
        magickArgs.append(outputPath)

        let magickResult = runCommand("/usr/bin/env", args: magickArgs)

        if magickResult.success {
            fputs("✅ GIF created with ImageMagick 7\n", stderr)
            return .success(outputPath)
        }

        fputs("⚠️ ImageMagick 7 (magick) failed: \(magickResult.output)\n", stderr)

        // Try ImageMagick 6 (uses 'convert' command)
        var convertArgs = ["convert", "-delay", "\(frameDelay / 10)", "-loop", "0"]
        convertArgs.append(contentsOf: ppmFiles)
        convertArgs.append(outputPath)

        let convertResult = runCommand("/usr/bin/env", args: convertArgs)

        if convertResult.success {
            fputs("✅ GIF created with ImageMagick 6\n", stderr)
            return .success(outputPath)
        }

        fputs("⚠️ ImageMagick 6 (convert) failed: \(convertResult.output)\n", stderr)

        // Try ffmpeg as alternative (using image sequence with explicit pattern)
        let ffmpegResult = runCommand(
            "/usr/bin/env",
            args: ["ffmpeg", "-y", "-framerate", String(1000 / max(frameDelay, 1)),
                   "-i", tempDir.appendingPathComponent("frame_%04d.ppm").path,
                   "-vf", "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                   outputPath]
        )

        if ffmpegResult.success {
            fputs("✅ GIF created with ffmpeg\n", stderr)
            return .success(outputPath)
        }

        fputs("⚠️ ffmpeg failed: \(ffmpegResult.output)\n", stderr)

        // If neither tool is available, return base64 encoded first frame as fallback
        if let firstFrame = capturedFrames.first {
            let base64 = encodeFrameAsBase64PNG(frame: firstFrame)
            if let base64 = base64 {
                return .failure(.toolNotAvailable(base64))
            }
        }

        return .failure(.toolNotAvailable("Neither ImageMagick nor ffmpeg is installed. Install with: brew install imagemagick (macOS) or apt install imagemagick (Linux)"))
    }

    private func runCommand(_ command: String, args: [String]) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        // Set PATH to include common binary locations
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func encodeFrameAsBase64PNG(frame: [[Color]]) -> String? {
        // Create a simple base64 representation of the frame data
        // This is a fallback when no GIF tools are available
        var description = "Frame preview (text-based):\n"
        for row in frame {
            for color in row {
                if color.red > 128 || color.green > 128 || color.blue > 128 || color.white > 128 {
                    description += "●"
                } else {
                    description += "○"
                }
            }
            description += "\n"
        }
        return description
    }

    // Helper to convert position to point
    private func fromPositionToPoint(_ pos: Int) -> Point {
        let x = pos % matrixHeight
        let y = pos / matrixHeight
        return Point(x: x, y: y)
    }
}

// MARK: - SequenceDelegate
extension PreviewController {
    func sequenceUpdatePixels(_ sequence: SequenceType) {
        guard !shouldStop else { return }

        // Capture current frame
        capturedFrames.append(frameBuffer)
        frameCount += 1

        if frameCount >= maxFrames {
            shouldStop = true
            var seq = sequence
            seq.stop = true
        }

        // Small delay to simulate frame timing
        Thread.sleep(forTimeInterval: 0.001)
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, point: Point, color: Color) {
        guard !shouldStop else { return }
        // x = row (0 to matrixHeight-1), y = column (0 to matrixWidth-1)
        guard point.x >= 0 && point.x < matrixHeight && point.y >= 0 && point.y < matrixWidth else { return }
        frameBuffer[point.x][point.y] = color
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, pos: Int, color: Color) {
        let point = fromPositionToPoint(pos)
        sequenceSetPixelColor(sequence, point: point, color: color)
    }
}

// MARK: - Errors
enum PreviewError: Error, LocalizedError {
    case noFramesCaptured
    case fileError(String)
    case toolNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .noFramesCaptured:
            return "No frames were captured from the sequence"
        case .fileError(let msg):
            return "File error: \(msg)"
        case .toolNotAvailable(let msg):
            return msg
        }
    }
}
