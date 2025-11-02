import Foundation

class ConsoleController: LedControllerProtocol {
    var matrixHeight: Int
    let matrixWidth: Int
    private(set) var sequences: [SequenceType]
    private(set) var stop = false

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
    
    func update(_ sequences: [SequenceType]) {
        self.sequences = sequences
    }

    func start() {
        while stop == false {
            runSequences()
        }
    }

    func runSequences() {
        let sequences = self.sequences
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

    func sequenceSetPixelColor(_ sequence: SequenceType, point: Point, color: Color) {
        setPixelColor(point: point, color: color)
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, pos: Int, color: Color) {
        setPixelColor(pos: pos, color: color)
    }
}
