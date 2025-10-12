import Foundation
import rpi_ws281x_swift

class ConsoleController: LedControllerProtocol {
    var matrixHeight: Int
    let matrixWidth: Int
    let sequences: [SequenceType]
    let stop = false

    init(sequences: [SequenceType], matrixWidth: Int, matrixHeight: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.sequences = sequences

        setup()
    }

    func setup() {
        for var sequence in sequences {
            sequence.delegate = self
        }
    }

    func start() {
        while stop == false {
            runSequence()
        }
    }

    func runSequence() {
        for sequence in sequences {
            sequence.runSequence()
        }
    }

    private func updatePixels() {
        let point = Point(x: 0, y: 1)
        Console.moveCursor(point)
        sleep()
    }

    private func setPixelColor(point: Point, color: Color) {
        if point.x == 0 && point.y > 0 {
            Console.writeLine("")
        }
        Console.write("● ", color: color)
    }

    private func setPixelColor(pos: Int, color: Color) {
        let point = fromPostionToPoint(pos)
        setPixelColor(point: point, color: color)
    }
}

extension ConsoleController: SequenceDelegate {
    func sequenceUpdatePixels(_ sequence: SequenceType) {
        updatePixels()
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, point: Point, color: rpi_ws281x_swift.Color) {
        setPixelColor(point: point, color: color)
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, pos: Int, color: rpi_ws281x_swift.Color) {
        setPixelColor(pos: pos, color: color)
    }
}
