import Foundation
import SwiftSPI

final class SPIBasedLedController: LedControllerProtocol {
    let matrixWidth: Int
    let matrixHeight: Int
    private(set) var sequences: [SequenceType]

    private var buffer: [UInt8]
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
        self.buffer = [UInt8](repeating: 0, count: matrixWidth * matrixHeight * 4)
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

    func runColorLoopMe() {
        let colors: [(r: UInt8, g: UInt8, b: UInt8, w: UInt8)] = [
            (255, 0, 0, 0),   // Rød
            (0, 255, 0, 0),   // Grøn
            (0, 0, 255, 0),   // Blå
            (0, 0, 0, 255)    // Hvid
        ]

        while isRunning {
            for color in colors {
                let frame = createFrame(red: color.r, green: color.g, blue: color.b, white: color.w)
                
                lock.lock()
                buffer = frame
                lock.unlock()

                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    func createFrame(red: UInt8, green: UInt8, blue: UInt8, white: UInt8) -> [UInt8] {
        var frameData: [UInt8] = []
        for _ in 0..<matrixWidth {
            for _ in 0..<matrixHeight {
                frameData.append(contentsOf: [red, green, blue, white])
            }
        }
        return frameData
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
        let col = x
        let row = y

        let indexStart = (row * matrixHeight * 4)
        let index = indexStart + (col * 4)

        // print("row: \(row) col: \(col), index: \(index)")

        guard index >= 0, index < (buffer.count - 4) else {
            return
        }

        lock.lock()
        buffer[index + 0] = color.red
        buffer[index + 1] = color.green
        buffer[index + 2] = color.blue
        buffer[index + 3] = color.white
        lock.unlock()
    }

    private func spiLoop() {
        while isRunning {
            lock.lock()
            let frame = buffer
            lock.unlock()

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
    func sequenceUpdatePixels(_ sequence: SequenceType) {}

    func sequenceSetPixelColor(_ sequence: SequenceType, point: Point, color: Color) {
        setPixel(x: point.x, y: point.y, color: color)
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, pos: Int, color: Color) {
        let point = fromPostionToPoint(pos)
        setPixel(x: point.x, y: point.y, color: color)
    }
}
