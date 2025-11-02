import Foundation

class TheMatrix: Equatable {
    static let maxLength: Int = 4
    let length: Int
    var posion: Point
    let speed: Int
    let color: Color

    init(color: Color, length: Int, posion: Point, speed: Int) {
        self.length = length
        self.posion = posion
        self.speed = speed
        self.color = color
    }

    func getNextPoint() -> Point {
        let posion: Point = .init(x: posion.x - speed, y: posion.y)
        self.posion = posion

        return posion
    }

    func getTheTailPoint(of index: Int) -> Point {
        return .init(x: posion.x + index, y: posion.y)
    }

    func getTheTailColor(of index: Int) -> Color {
        let factor = 0.5 * (1 - Float(index) / Float(length)) + 0.2

        return color * factor
    }

    static func == (lhs: TheMatrix, rhs: TheMatrix) -> Bool {
        return lhs.length == rhs.length && lhs.speed == rhs.speed && lhs.posion == rhs.posion
    }
}

final class MatrixSequence: SequenceType {
    let numberOfmatrixs: Int
    var delegate: SequenceDelegate?
    var number: Int = 0
    let matrixHeight: Int
    let matrixWidth: Int
    var matrixs: [TheMatrix] = []
    let colors: [Color]
    var stop: Bool = false

    var canStop: Bool {
        return !(number > 0 || matrixs.isEmpty == false)
    }

    init(matrixWidth: Int, matrixHeight: Int, colors: [Color], numberOfmatrixs: Int = 100) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.colors = colors
        self.numberOfmatrixs = numberOfmatrixs
    }

    func runSequence() {
        reset()

        while canStop == false, stop == false {
            moveColors()
        }
    }

    func reset() {
        stop = false
        number = numberOfmatrixs
        matrixs = []
    }

    private func moveColors() {
        for x in 0..<matrixHeight {
            for y in 0..<matrixWidth {
                guard stop == false else { return }
                delegate?.sequenceSetPixelColor(self, point: .init(x: x, y: y), color: .black)
            }
        }

        let matrixs = self.matrixs

        matrixs.forEach { theMatrix in
            guard stop == false else { return }
            delegate?.sequenceSetPixelColor(self, point: theMatrix.getNextPoint(), color: theMatrix.color)

            for i in 1...theMatrix.length {
                delegate?.sequenceSetPixelColor(
                    self,
                    point: theMatrix.getTheTailPoint(of: i),
                    color: theMatrix.getTheTailColor(of: i)
                )
            }

            if theMatrix.posion.x <= -theMatrix.length {
                self.matrixs.removeAll(where: { $0 == theMatrix })
            }
        }

        addMatrix()

        delegate?.sequenceUpdatePixels(self)
        Thread.sleep(forTimeInterval: 0.1)
    }

    private func addMatrix() {
        let index = Int.random(in: 0...(colors.count - 1))

        let color = colors[index]

        if number > 0 {
            let startRow = Int.random(in: 0...matrixWidth)

            if startRow < matrixWidth {
                self.matrixs.append(
                    .init(
                        color: color,
                        length: Int.random(in: 1...TheMatrix.maxLength),
                        posion: .init(x: matrixHeight, y: startRow),
                        speed: Int.random(in: 1...2)
                    )
                )
            }

            number = number - 1
        }
    }
}
