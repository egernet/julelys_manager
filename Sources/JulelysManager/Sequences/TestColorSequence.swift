import Foundation

final class TestColorSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let colors: [Color] = [.red, .green, .blue, .trueWhite, .black]
    var stop: Bool = false
    
    init(matrixWidth: Int, matrixHeight: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
    }

    func runSequence() {
        stop = false
        switchColor()
    }

    private func switchColor() {
        let numberOfLeds = matrixHeight * matrixWidth

        for color in colors {
            for i in 0..<numberOfLeds {
                guard stop == false else { return }
                delegate?.sequenceSetPixelColor(self, pos: i, color: color)
            }

            delegate?.sequenceUpdatePixels(self)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    private func staticColor() {
        let numberOfLeds = matrixHeight * matrixWidth

        for i in 0..<numberOfLeds {
            guard stop == false else { return }
            delegate?.sequenceSetPixelColor(self, pos: i, color: colors[i % 5])
        }

        delegate?.sequenceUpdatePixels(self)
        Thread.sleep(forTimeInterval: 1)
    }
}

final class TestOneLEDColorSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let colors: [Color] = [.red, .green, .blue, .trueWhite, .black]
    var stop: Bool = false

    init(matrixWidth: Int, matrixHeight: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
    }

    func runSequence() {
        stop = false
        switchColor()
    }

    private func switchColor() {
        let numberOfLeds = matrixHeight * matrixWidth

        for color in colors {
            guard stop == false else { return }
            
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
            guard stop == false else { return }
            delegate?.sequenceSetPixelColor(self, pos: i, color: colors[i % 5])
        }

        delegate?.sequenceUpdatePixels(self)
        Thread.sleep(forTimeInterval: 1)
    }
}
