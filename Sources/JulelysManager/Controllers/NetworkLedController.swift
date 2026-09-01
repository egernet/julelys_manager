import Foundation

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

/// Streams frames to an ESP32 over UDP instead of SPI.
///
/// Used when no SBC is available to sit on the HAT - the ESP32 runs standalone
/// on USB-C power and pulls frames off the network. Apart from the transport
/// this behaves exactly like `SPIBasedLedController`.
///
/// Wire format matches `stream_receiver.h` in the firmware: one packet per LED
/// string, `[frame_seq: u16 BE][row: u8][flags: u8]` followed by the row's RGBW
/// bytes. Splitting per row keeps each packet inside the MTU, so a dropped
/// packet costs one string in one frame rather than the whole image.
final class NetworkLedController: LedControllerProtocol {
    private enum Wire {
        static let headerLength = 4
        static let endOfFrameFlag: UInt8 = 0x01
    }

    let matrixWidth: Int
    let matrixHeight: Int
    private(set) var sequences: [SequenceType]

    // Double buffering to prevent tearing
    private var backBuffer: [UInt8]   // Sequences write here
    private var frontBuffer: [UInt8]  // Network sends this

    private let host: String
    private let port: UInt16
    private let framesPerSecond: Double

    private var socketDescriptor: Int32 = -1
    private var destination = sockaddr_in()
    private var frameSequence: UInt16 = 0

    private let lock = NSLock()
    private var isRunning = false
    private let updateContentQueue = DispatchQueue(label: "dk.egernet.julelys.stream")

    init(sequences: [SequenceType],
         matrixWidth: Int,
         matrixHeight: Int,
         host: String,
         port: UInt16 = 2412,
         framesPerSecond: Double = 30) {
        self.matrixWidth = matrixWidth
        self.matrixHeight = matrixHeight
        self.sequences = sequences
        self.host = host
        self.port = port
        self.framesPerSecond = framesPerSecond

        let bufferSize = matrixWidth * matrixHeight * 4
        self.backBuffer = [UInt8](repeating: 0, count: bufferSize)
        self.frontBuffer = [UInt8](repeating: 0, count: bufferSize)
    }

    func start() {
        guard openSocket() else {
            fputs("❌ Could not open UDP socket to \(host):\(port)\n", stderr)
            return
        }

        fputs("📡 Streaming to \(host):\(port) at \(Int(framesPerSecond)) FPS\n", stderr)

        isRunning = true

        updateContentQueue.async { [weak self] in
            self?.streamLoop()
        }

        runSequences()
    }

    func update(_ sequences: [SequenceType]) {
        for var sequence in self.sequences {
            sequence.stop = true
        }

        self.sequences = sequences
    }

    func runSequences() {
        while isRunning {
            let sequences = self.sequences
            for var sequence in sequences {
                sequence.delegate = self
                sequence.runSequence()
            }
        }
    }

    /// Swap back and front buffers atomically
    private func swapBuffers() {
        lock.lock()
        swap(&backBuffer, &frontBuffer)
        lock.unlock()
    }

    private func setPixel(x: Int, y: Int, color: Color) {
        // x = row position (0 to height-1)
        // y = string/column (0 to width-1)

        guard x >= 0, x < matrixHeight,
              y >= 0, y < matrixWidth else {
            return
        }

        let index = (y * matrixHeight * 4) + (x * 4)

        // Write to back buffer (no lock needed - single writer)
        backBuffer[index + 0] = color.red
        backBuffer[index + 1] = color.green
        backBuffer[index + 2] = color.blue
        backBuffer[index + 3] = color.white
    }

    private func openSocket() -> Bool {
        // SOCK_DGRAM is an Int32 constant on Darwin but a __socket_type enum
        // on Glibc, so it needs unwrapping differently per platform.
        #if canImport(Glibc)
        let datagramType = Int32(SOCK_DGRAM.rawValue)
        #else
        let datagramType = SOCK_DGRAM
        #endif

        socketDescriptor = socket(AF_INET, datagramType, 0)
        guard socketDescriptor >= 0 else {
            return false
        }

        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = port.bigEndian

        guard inet_pton(AF_INET, host, &destination.sin_addr) == 1 else {
            close(socketDescriptor)
            socketDescriptor = -1
            return false
        }

        return true
    }

    private func streamLoop() {
        let bufferSize = matrixWidth * matrixHeight * 4
        let rowBytes = matrixHeight * 4
        var packet = [UInt8](repeating: 0, count: Wire.headerLength + rowBytes)

        while isRunning {
            lock.lock()
            let frame = Array(frontBuffer)
            lock.unlock()

            guard frame.count == bufferSize else {
                continue
            }

            let sequenceNumber = frameSequence
            frameSequence &+= 1

            packet[0] = UInt8(truncatingIfNeeded: sequenceNumber >> 8)
            packet[1] = UInt8(truncatingIfNeeded: sequenceNumber)

            for row in 0..<matrixWidth {
                packet[2] = UInt8(row)
                packet[3] = (row == matrixWidth - 1) ? Wire.endOfFrameFlag : 0

                let start = row * rowBytes
                packet.replaceSubrange(Wire.headerLength..., with: frame[start..<(start + rowBytes)])

                send(packet: packet)
            }

            Thread.sleep(forTimeInterval: 1.0 / framesPerSecond)
        }
    }

    private func send(packet: [UInt8]) {
        guard socketDescriptor >= 0 else { return }

        _ = withUnsafePointer(to: &destination) { addressPointer in
            addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                packet.withUnsafeBytes { bytes in
                    sendto(socketDescriptor,
                           bytes.baseAddress,
                           packet.count,
                           0,
                           socketAddress,
                           socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    deinit {
        isRunning = false
        if socketDescriptor >= 0 {
            close(socketDescriptor)
        }
    }
}

extension NetworkLedController: SequenceDelegate {
    func sequenceUpdatePixels(_ sequence: SequenceType) {
        // Swap buffers when sequence has finished writing a complete frame
        swapBuffers()
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, point: Point, color: Color) {
        setPixel(x: point.x, y: point.y, color: color)
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, pos: Int, color: Color) {
        let point = fromPostionToPoint(pos)
        setPixel(x: point.x, y: point.y, color: color)
    }
}
