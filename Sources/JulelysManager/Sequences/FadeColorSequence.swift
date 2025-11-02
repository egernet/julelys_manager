import Foundation

final class FadeColorSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    var color: Color = .black
    var goUp: Bool = true
    var ledInLive: Int = 0
    var stop: Bool = false

    init(matrixWidth: Int, matrixHeight: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
    }

    func runSequence() {
        stop = false
        while true, stop == false {
            switchColor()
        }
    }

    private func switchColor() {
        let numberOfLeds = matrixHeight * matrixWidth
        for i in 0..<numberOfLeds {
            if i.isMultiple(of: 2) {
                delegate?.sequenceSetPixelColor(self, pos: i, color: color)
            } else {
                delegate?.sequenceSetPixelColor(self, pos: i, color: .green)
            }
        }

        delegate?.sequenceUpdatePixels(self)

        ledInLive = ledInLive + 1
        if ledInLive == numberOfLeds {
            ledInLive = 0
        }

        var colorInt: Int = Int(color.red)

        if goUp {
            colorInt = colorInt + 1
        } else {
            colorInt = colorInt - 1
        }

        if colorInt >= 255 {
            colorInt = 255
            goUp = false
        } else if colorInt <= 0 {
            colorInt = 0
            goUp = true
        }

        color.red = UInt8(colorInt)
    }
}
