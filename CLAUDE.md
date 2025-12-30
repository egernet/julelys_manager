# CLAUDE.md

This file provides guidance for Claude Code when working with the Julelys Manager codebase.

## Project Overview

Julelys Manager is a Swift-based command-line tool for controlling a programmable LED matrix (8x55 = 440 SK6812 LEDs) over SPI. It supports multiple execution modes and can be controlled via MCP (Model Context Protocol) for AI integration.

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
│ - Auto-discovers JS sequences from SequencesJS/             │
│ - Executes JavaScript via SwiftJS engine                    │
│ - Double-buffered SPI output (30 FPS)                       │
│ - Persistence of active sequences                           │
└─────────────────┬───────────────────────────────────────────┘
                  │ SPI (2.5 Mbps)
┌─────────────────▼───────────────────────────────────────────┐
│ ESP32 (julelys_pcb_v2) → SK6812 LEDs                        │
└─────────────────────────────────────────────────────────────┘
```

## Build Commands

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run manager (debug)
.build/debug/JulelysManager --mode console

# Run manager (release)
.build/release/JulelysManager --mode real

# Run MCP server
.build/release/JulelysMCP
```

## Project Structure

```
Sources/
├── Entities/                    # Shared data types
│   └── Command/
│       ├── RequestCommand.swift      # Commands sent to daemon
│       ├── AllSequences.swift        # Sequence list response
│       ├── SequenceInfo.swift        # Sequence metadata
│       ├── CreateSequenceResponse.swift
│       ├── StatusResponse.swift
│       ├── SequenceCodeResponse.swift
│       ├── PreviewResponse.swift
│       └── RunSequencesResponse.swift
├── JulelysManager/              # Main daemon
│   ├── JulelysManager.swift          # Entry point, CLI args, auto-discovery
│   ├── JulelysDaemon.swift           # Unix socket server
│   ├── Controllers/
│   │   ├── LedControllerProtocol.swift
│   │   ├── SPIBasedLedController.swift  # Double-buffered SPI output
│   │   ├── ConsoleController.swift      # Terminal simulation
│   │   ├── WindowController.swift       # macOS GUI
│   │   └── PreviewController.swift      # HTML preview generation
│   ├── Sequences/
│   │   ├── SequenceType.swift           # Protocol definition
│   │   └── JSSequence.swift             # JavaScript engine wrapper
│   ├── SequencesJS/                     # All sequences (auto-discovered)
│   │   ├── stars.js                     # Sequence code
│   │   ├── stars.json                   # Sequence metadata
│   │   ├── matrix.js
│   │   ├── matrix.json
│   │   └── ...                          # 10 built-in sequences
│   └── Library/
│       ├── Color.swift                  # RGBW color struct
│       ├── Point.swift                  # x,y coordinate
│       └── Console.swift                # ANSI terminal helpers
└── JulelysMCP/                  # MCP server
    └── JulelysMCP.swift              # Tool definitions & handlers
```

## Key Concepts

### Coordinate System
- `x` = row position (0 to matrix.height-1, vertical along LED string)
- `y` = column/string number (0 to matrix.width-1, horizontal)
- Default matrix: 8 columns × 55 rows = 440 LEDs

### Sequence Protocol
All sequences implement `SequenceType`:
```swift
protocol SequenceType {
    var delegate: SequenceDelegate? { get set }
    var matrixWidth: Int { get }
    var matrixHeight: Int { get }
    var name: String { get }
    var stop: Bool { get set }
    func runSequence()
}
```

### JavaScript API (for sequences)
```javascript
setPixelColor(r, g, b, w, x, y)  // Set pixel (RGBW 0-255)
updatePixels()                   // Send frame to LEDs (triggers buffer swap)
delay(ms)                        // Wait milliseconds
matrix.width                     // Number of strings (8)
matrix.height                    // LEDs per string (55)
```

**Recommended helper function** (prevents UInt8 overflow errors):
```javascript
function clamp(val) {
    return Math.max(0, Math.min(255, Math.floor(val)));
}
```

### Built-in Sequences (10 total)
All in `Sources/JulelysManager/SequencesJS/`:
| File | Description |
|------|-------------|
| `twist.js` | Spiral pattern moving upward |
| `rainbow_cycle.js` | Color wheel rotation |
| `stars.js` | Twinkling stars with elastic easing |
| `fireworks.js` | Bursting colorful fireworks |
| `test_color.js` | Sequential RGBW test |
| `fade_color.js` | Red/green alternating fade |
| `matrix.js` | Green Matrix streams |
| `matrix_4colors.js` | Multi-color Matrix |
| `matrix_dannebrog.js` | Danish flag colors |
| `skyblue.js` | "Dejlig er den himmel blå" music animation |

### MCP Tools
| Tool | Description |
|------|-------------|
| `allSequences` | List all available sequences |
| `runSequences` | Start sequences by name |
| `createSequence` | Create new JS sequence |
| `updateSequence` | Update existing custom sequence |
| `getSequenceCode` | Get JS code for a sequence |
| `getStatus` | Get manager status |
| `previewSequence` | Generate HTML preview |

## Platform-Specific Code

When adding socket or system code, handle Linux differences:
```swift
#if os(Linux)
let sock = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
#else
let sock = socket(AF_UNIX, SOCK_STREAM, 0)
#endif
```

## Storage Locations

- **macOS**: `~/Library/Application Support/Julelys/`
- **Linux**: `~/Julelys/`

Subdirectories:
- `CustomSequences/` - Custom JS sequences (.js + .json metadata)
- `Previews/` - Generated HTML previews
- `active_sequences.json` - Persisted active sequence list

## Testing

Run in console mode to test without hardware:
```bash
.build/debug/JulelysManager --mode console
```

Test MCP tools by connecting with Claude Desktop or using stdin/stdout directly.

## Common Tasks

### Adding a New MCP Tool
1. Add case to `RegisteredTools` enum in `JulelysMCP.swift`
2. Add `Tool` definition in `registerTools()`
3. Add case handler in `toolsHandler()`
4. Add handler function (e.g., `myToolHandler()`)
5. If needed, add command to `RequestCommand.Command` enum
6. Add response type in `Sources/Entities/Command/`
7. Add daemon handler in `JulelysManager.startDaemon()`

### Adding a New Built-in Sequence
All sequences are JavaScript-based and auto-discovered:

1. Create `your_sequence.js` in `Sources/JulelysManager/SequencesJS/`
2. Create `your_sequence.json` with metadata:
   ```json
   {
       "id": "YourSequenceId",
       "name": "Your Sequence Name",
       "description": "Description of what it does"
   }
   ```
3. Rebuild - the sequence is auto-discovered from the SequencesJS folder

**Important for JS sequences:**
- Always use `clamp()` function when calculating color values to prevent UInt8 overflow
- Use `delay(ms)` between frames to control animation speed
- Call `updatePixels()` after setting all pixels for a frame

### Adding a Custom Sequence via MCP
Use the `createSequence` tool with name, description, and jsCode parameters.
Custom sequences are stored in `~/Library/Application Support/Julelys/CustomSequences/` (macOS)
or `~/Julelys/CustomSequences/` (Linux).

### Double Buffering (SPIBasedLedController)
The SPI controller uses double buffering to prevent tearing:
- `backBuffer` - Sequences write pixels here
- `frontBuffer` - SPI loop reads from here
- Buffers are swapped atomically when `updatePixels()` is called
- SPI loop runs at 30 FPS independently of sequence frame rate
