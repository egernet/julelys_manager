import Foundation

final class RainbowCycleSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let iterations: Int

    init(matrixWidth: Int, matrixHeight: Int, iterations: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.iterations = iterations
    }

    func runSequence() {
        rainbowCycle(matrixWidth: matrixWidth, matrixHeight: matrixHeight, iterations: iterations)
    }

    private func rainbowCycle(matrixWidth: Int, matrixHeight: Int, iterations: Int = 1) {
        for i in 0..<255 * iterations {
            for y in 0..<matrixWidth {
                for x in 0..<matrixHeight {
                    let index = ((x * 255 / matrixHeight) + i) & 255
                    let color = wheel(index)
                    delegate?.sequenceSetPixelColor(self, point: .init(x: x, y: y), color: color)
                }
            }
            
            delegate?.sequenceUpdatePixels(self)
            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    private func wheel(_ position: Int) -> Color {
        var position: UInt8 = UInt8(position)

        if position < 85 {
            return .init(red: position * 3, green: 255 - position * 3, blue: 0)
        } else if position < 170 {
            position -= 85
            return .init(red: 255 - position * 3, green: 0, blue: position * 3)
        } else {
            position -= 170
            return .init(red: 0, green: position * 3, blue: 255 - position * 3)
        }
    }
}
