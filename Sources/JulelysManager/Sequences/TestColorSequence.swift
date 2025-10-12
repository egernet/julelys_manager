import Foundation

final class TestColorSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let colors: [Color] = [.red, .green, .blue, .trueWhite, .black]

    init(matrixWidth: Int, matrixHeight: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
    }

    func runSequence() {
        switchColor()
    }

    private func switchColor() {
        let numberOfLeds = matrixHeight * matrixWidth

        for color in colors {
            for i in 0..<numberOfLeds {
                delegate?.sequenceSetPixelColor(self, pos: i, color: color)
            }

            delegate?.sequenceUpdatePixels(self)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    private func staticColor() {
        let numberOfLeds = matrixHeight * matrixWidth

        for i in 0..<numberOfLeds {
            delegate?.sequenceSetPixelColor(self, pos: i, color: colors[i % 5])
        }

        delegate?.sequenceUpdatePixels(self)
        Thread.sleep(forTimeInterval: 1)
    }
}
