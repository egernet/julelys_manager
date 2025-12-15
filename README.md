# Julelys Manager

`julelys_manager` is a Swift-based **command-line tool** for controlling a programmable LED matrix over **SPI**. It supports multiple execution modes and can be controlled via **MCP (Model Context Protocol)** for AI integration.

---

## Features

- **Multiple execution modes**: Real hardware, macOS GUI, or console simulation
- **MCP Server**: Control your Christmas lights via Claude or other AI assistants
- **Custom JavaScript sequences**: Create and edit LED animations with JavaScript
- **Persistence**: Active sequences are saved and restored on restart
- **Built-in sequences**: 12 pre-made animations (Rainbow, Stars, Fireworks, Matrix, etc.)

---

## Execution Modes

### `real` - Hardware Control

```bash
swift run JulelysManager --mode real
```

Sends SPI frame data to the connected LED controller (ESP32). Controls **real physical LEDs**.

### `app` - macOS GUI

```bash
swift run JulelysManager --mode app
```

Launches a **macOS GUI** with visual LED preview using SwiftUI.

### `console` - Terminal Simulation

```bash
swift run JulelysManager --mode console
```

Runs a terminal-based LED simulator with ANSI colors.

### Options

```bash
swift run JulelysManager --mode real --matrixWidth 8 --matrixHeight 55
```

| Option | Default | Description |
|--------|---------|-------------|
| `--mode` | `real` | Execution mode (real/app/console) |
| `--matrixWidth` | `8` | Number of LED strings (columns) |
| `--matrixHeight` | `55` | LEDs per string (rows) |

---

## MCP Integration

The project includes an MCP server (`JulelysMCP`) that allows AI assistants like Claude to control your Christmas lights.

### Setup for Claude Desktop

1. Build the MCP server:
   ```bash
   swift build -c release
   ```

2. Add to Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):
   ```json
   {
     "mcpServers": {
       "julelys": {
         "command": "/path/to/julelys_manager/.build/release/JulelysMCP"
       }
     }
   }
   ```

3. Start the daemon:
   ```bash
   .build/release/JulelysManager --mode real
   ```

4. Restart Claude Desktop

### MCP Tools

| Tool | Description |
|------|-------------|
| `allSequences` | List all available sequences |
| `runSequences` | Start one or more sequences by name |
| `createSequence` | Create a new JavaScript sequence |
| `updateSequence` | Update an existing custom sequence |
| `getSequenceCode` | Get the JS code for a custom sequence |
| `getStatus` | Get manager status (active sequences, mode, etc.) |

---

## Custom JavaScript Sequences

Create LED animations using JavaScript via MCP:

### Available API

```javascript
setPixelColor(r, g, b, w, x, y)  // Set pixel (RGBW 0-255)
updatePixels()                   // Send frame to LEDs
delay(ms)                        // Wait milliseconds
matrix.width                     // Number of strings (8)
matrix.height                    // LEDs per string (55)
```

### Coordinate System

- `x` = row position (0 to matrix.height-1, vertical)
- `y` = column/string (0 to matrix.width-1, horizontal)

### Example Sequence

```javascript
// Simple red blink
for (let frame = 0; frame < 100; frame++) {
    let brightness = frame % 2 === 0 ? 255 : 0;

    for (let y = 0; y < matrix.width; y++) {
        for (let x = 0; x < matrix.height; x++) {
            setPixelColor(brightness, 0, 0, 0, x, y);
        }
    }
    updatePixels();
    delay(500);
}
```

### Storage

Custom sequences are saved to:
- **macOS**: `~/Library/Application Support/Julelys/CustomSequences/`
- **Linux**: `~/Julelys/CustomSequences/`

---

## Built-in Sequences

| Sequence | Description |
|----------|-------------|
| Twist | Spiral pattern moving up |
| Rainbow | Color wheel rotation |
| Rainbow Javascript | JS-based rainbow effect |
| Test red | Single LED test |
| Test Color | Sequential RGBW test |
| Stars | Twinkling white stars |
| Fireworks | Bursting colorful fireworks |
| The Matrix | Green cascading streams |
| The Matrix with 4 colors | Multi-color matrix effect |
| Dannebrog | Danish flag colors |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Claude / AI Assistant                                       │
└─────────────────┬───────────────────────────────────────────┘
                  │ MCP (stdio)
┌─────────────────▼───────────────────────────────────────────┐
│ JulelysMCP (MCP Server)                                     │
└─────────────────┬───────────────────────────────────────────┘
                  │ Unix Socket (/tmp/julelys.sock)
┌─────────────────▼───────────────────────────────────────────┐
│ JulelysManager (Daemon)                                     │
│ - Sequence management                                       │
│ - Custom JS sequences (SwiftJS/elk)                         │
│ - Persistence                                               │
└─────────────────┬───────────────────────────────────────────┘
                  │ SPI (2.5 Mbps)
┌─────────────────▼───────────────────────────────────────────┐
│ ESP32 (julelys_pcb_v2)                                      │
│ - Receives RGBW frames                                      │
│ - Drives SK6812 LEDs                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Hardware Integration

Designed to communicate with:

**[julelys_pcb_v2 – feature/v3](https://github.com/egernet/julelys_pcb_v2/tree/feature/v3)**

- Microcontroller: ESP32
- Interface: SPI (slave mode)
- Frame format: RGBW 2D-matrix (4 bytes per LED)
- LED type: SK6812 (WS2812B compatible)
- Default matrix: 8 × 55 = 440 LEDs
- Frame rate: 30 FPS

---

## Building

Requires Swift 5.10 or newer.

```bash
git clone https://github.com/egernet/julelys_manager.git
cd julelys_manager
swift build -c release
```

### Run Manager

```bash
.build/release/JulelysManager --mode real
```

### Run MCP Server (for Claude integration)

```bash
.build/release/JulelysMCP
```

---

## Requirements

- macOS 13+ or Linux
- Swift 5.10 or newer
- SPI access (e.g. `/dev/spidev1.1` or USB-to-SPI adapter)
- ESP32 running compatible firmware

---

## Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - CLI argument parsing
- [SwiftSPI](https://github.com/egernet/swift_spi) - SPI communication
- [SwiftJS](https://github.com/SusanDoggie/SwiftJS) - JavaScript engine for custom sequences
- [swift-sdk (MCP)](https://github.com/modelcontextprotocol/swift-sdk) - Model Context Protocol

---

## Author

Developed by [egernet](https://github.com/egernet)
