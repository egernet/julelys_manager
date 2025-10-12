import Foundation
import SwiftSPI

final class SPIBasedLedController: LedControllerProtocol {
    let matrixWidth: Int
    let matrixHeight: Int
    let sequences: [SequenceType]

    private var buffer: [UInt8]
    private let spi: SwiftSPI
    private let spiPath: String
    private let baudRate: Int
    private let lock = NSLock()
    private var isRunning = false

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
        DispatchQueue.global(qos: .userInitiated).async {
            self.spiLoop()
        }
    }

    func runSequence() {
        for var sequence in sequences {
            sequence.delegate = self
            sequence.runSequence()
        }
    }

    private func setPixel(x: Int, y: Int, color: Color) {
        guard x < matrixWidth, y < matrixHeight else { return }
        let index = (y * matrixWidth + x) * 4

        lock.lock()
        buffer[index + 0] = color.green
        buffer[index + 1] = color.red
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
