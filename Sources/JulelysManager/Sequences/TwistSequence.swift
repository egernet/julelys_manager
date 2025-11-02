import Foundation

final class TwistSequence: SequenceType {
    class Ball: Equatable {
        let length: Int = 4
        var posion: Point
        let color: Color

        init(color: Color, posion: Point) {
            self.posion = posion
            self.color = color
        }

        func getNextPoint() -> Point {
            let posion: Point = .init(x: posion.x + 1, y: posion.y)
            self.posion = posion

            return posion
        }

        func getTheTailPoint(of index: Int) -> Point {
            return .init(x: posion.x - index, y: posion.y)
        }

        func getTheTailColor(of index: Int) -> Color {
            let factor = 0.5 * (1 - Float(index) / Float(length)) + 0.2

            return color * factor
        }

        static func == (lhs: Ball, rhs: Ball) -> Bool {
            return lhs.length == rhs.length && lhs.posion == rhs.posion
        }
    }

    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let color: Color
    var matrixs: [Ball] = []
    var number: Int = 0
    var stop: Bool = false

    var canStop: Bool {
        return matrixs.isEmpty == true
    }

    init(matrixWidth: Int, matrixHeight: Int, color: Color = .trueWhite) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.color = color
    }

    func runSequence() {
        reset()
        
        while canStop == false, stop == false {
            moveColors()
        }
    }

    func reset() {
        stop = false
        matrixs = []

        for i in 0..<matrixWidth {
            matrixs.append(.init(color: color, posion: .init(x: -i, y: i)))
        }
    }

    private func moveColors() {
        for x in 0..<matrixHeight {
            for y in 0..<matrixWidth {
                delegate?.sequenceSetPixelColor(self, point: .init(x: x, y: y), color: .black)
            }
        }

        let matrixs = self.matrixs

        matrixs.forEach { theMatrix in
            delegate?.sequenceSetPixelColor(self, point: theMatrix.getNextPoint(), color: theMatrix.color)

            for i in 1...theMatrix.length {
                delegate?.sequenceSetPixelColor(
                    self,
                    point: theMatrix.getTheTailPoint(of: i),
                    color: theMatrix.getTheTailColor(of: i)
                )
            }

            if theMatrix.posion.x > matrixHeight {
                self.matrixs.removeAll(where: { $0 == theMatrix })
            }
        }

        delegate?.sequenceUpdatePixels(self)
    }
}
