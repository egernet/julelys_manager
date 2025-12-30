import Foundation
import SwiftSPI

final class SPIBasedLedController: LedControllerProtocol {
    let matrixWidth: Int
    let matrixHeight: Int
    private(set) var sequences: [SequenceType]

    // Double buffering to prevent tearing
    private var backBuffer: [UInt8]   // Sequences write here
    private var frontBuffer: [UInt8]  // SPI sends this
    private let spi: SwiftSPI
    private let spiPath: String
    private let baudRate: Int
    private let lock = NSLock()
    private var isRunning = false
    private let updateContentQueue = DispatchQueue(label: "dk.egernet.julelys")

    init(sequences: [SequenceType], matrixWidth: Int, matrixHeight: Int, spiPath: String = "/dev/spidev1.1", baudRate: Int = 2_500_000) {
        self.matrixWidth = matrixWidth
        self.matrixHeight = matrixHeight
        self.sequences = sequences
        self.spiPath = spiPath
        self.baudRate = baudRate
        let bufferSize = matrixWidth * matrixHeight * 4
        self.backBuffer = [UInt8](repeating: 0, count: bufferSize)
        self.frontBuffer = [UInt8](repeating: 0, count: bufferSize)
        self.spi = .init(spiPath: spiPath, baudRate: baudRate)
    }

    func start() {
        spi.setup()

        isRunning = true
        
        updateContentQueue.async { [weak self] in
            self?.spiLoop()
        }

        // runColorLoopMe()
        runSequences()
    }
    
    func update(_ sequences: [SequenceType]) {
        for var sequence in self.sequences {
            sequence.stop = true
        }
        
        self.sequences = sequences
    }

    /// Swap back and front buffers atomically
    private func swapBuffers() {
        lock.lock()
        swap(&backBuffer, &frontBuffer)
        lock.unlock()
    }

    func runColorLoopMe() {
        let colors: [(r: UInt8, g: UInt8, b: UInt8, w: UInt8)] = [
            (255, 0, 0, 0),   // Rød
            (0, 255, 0, 0),   // Grøn
            (0, 0, 255, 0),   // Blå
            (0, 0, 0, 255)    // Hvid
        ]

        while isRunning {
            for color in colors {
                // Write to back buffer
                for i in 0..<(matrixWidth * matrixHeight) {
                    let index = i * 4
                    backBuffer[index + 0] = color.r
                    backBuffer[index + 1] = color.g
                    backBuffer[index + 2] = color.b
                    backBuffer[index + 3] = color.w
                }

                // Swap buffers after complete frame
                swapBuffers()

                Thread.sleep(forTimeInterval: 0.5)
            }
        }
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

    private func setPixel(x: Int, y: Int, color: Color) {
        // x = row position (0 to height-1)
        // y = string/column (0 to width-1)
        let col = x
        let row = y

        let index = (row * matrixHeight * 4) + (col * 4)

        guard index >= 0, index + 3 < backBuffer.count else {
            return
        }

        // Write to back buffer (no lock needed - single writer)
        backBuffer[index + 0] = color.red
        backBuffer[index + 1] = color.green
        backBuffer[index + 2] = color.blue
        backBuffer[index + 3] = color.white
    }

    private func spiLoop() {
        let bufferSize = matrixWidth * matrixHeight * 4

        while isRunning {
            // Copy front buffer while holding lock
            lock.lock()
            let frame = Array(frontBuffer)
            lock.unlock()

            // Verify we got the right size
            guard frame.count == bufferSize else {
                continue
            }

            spi.spiWrite(buffer: frame)

            Thread.sleep(forTimeInterval: 1.0 / 30.0) // 30 fps
        }
    }

    deinit {
        isRunning = false
        spi.close()
    }
}

extension SPIBasedLedController: SequenceDelegate {
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
