# 🎄 Julelys Manager

`julelys_manager` is a Swift-based **command-line tool** for controlling a programmable LED matrix over **SPI**. It can be used in different modes:

- from the **terminal** as a standalone CLI,
- launched from a **macOS GUI app**,
- or run directly on a system with SPI access to communicate with a connected LED controller.

It’s designed to interface with [julelys_pcb_v2 (feature/v3)](https://github.com/egernet/julelys_pcb_v2/tree/feature/v3), which receives and renders the LED frames.

---

## 🚀 Execution Modes

The program supports multiple runtime modes, selected by the first argument:

### ▶️ `real`

```
swift run julelys_manager real
```

Sends SPI frame data to the connected LED controller (e.g., an ESP32 running the julelys firmware). This is used to control **real physical LEDs**.

---

### 🖥 `app`

```
swift run julelys_manager app
```

Launches a **macOS GUI app** (using SwiftUI). The app uses shared logic from `JulelysCore` and controls sequences visually. It may call into the CLI backend or handle SPI directly.

---

### 💻 `console`

```
swift run julelys_manager console
```

Runs an **interactive terminal UI** or simulator. Useful for development and testing without physical hardware or GUI.

---

## 📦 Project Structure

| Component         | Description                                           |
|-------------------|-------------------------------------------------------|
| `julelys_manager` | CLI entry point (supports `real`, `app`, `console`)   |

---

## 💡 Example Usage

```
# Run SPI sequence to real hardware
swift run julelys_manager real

# Launch GUI interface (macOS only)
swift run julelys_manager app

# Start console interface
swift run julelys_manager console
```

---

## 🧩 Hardware Integration

This tool is designed to communicate with the firmware from:

📟 [`julelys_pcb_v2` – feature/v3](https://github.com/egernet/julelys_pcb_v2/tree/feature/v3)

- Microcontroller: ESP32
- Interface: SPI (slave mode)
- Receives frames as RGBW 2D-matrix
- Controls addressable LEDs (e.g., SK6812)

---

## 🔧 Building

Requires [Swift 5.9](https://swift.org) or newer.

```
git clone https://github.com/egernet/julelys_manager.git
cd julelys_manager
swift build
```

Then run:

```
swift run julelys_manager real
```

Or try other modes:

```
swift run julelys_manager console
swift run julelys_manager app
```

---

## 🛠 Requirements

- macOS 12+ or Linux
- Swift 5.9 or newer
- SPI access (e.g. `/dev/spidev0.0` or USB-to-SPI on macOS)
- LED controller running compatible firmware

---

## 🧪 Testing

To test communication and basic LED output:

```
swift run julelys_manager real
```

This will send a default test sequence to your connected controller. Make sure SPI wiring and firmware are properly configured.

---

## 🙌 Author

Developed by [egernet](https://github.com/egernet) — because blinking lights bring joy ✨
