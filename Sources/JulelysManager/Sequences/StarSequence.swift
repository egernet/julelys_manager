import Foundation

class Star: Equatable {
    var posion: Point
    let color: Color
    var isDone: Bool = false
    var time: Float = 0
    var value: Float = 0.1

    init(color: Color, posion: Point) {
        self.posion = posion
        self.color = color
    }

    func getColor() -> Color {
        time = time + value

        if time >= 1 {
            value = -0.1
        }

        if time <= 0 {
            time = 0
            isDone = true
        }

        return color * easeInOutElastic(time)
    }

    private func easeInOutElastic(_ x: Float) -> Float {
        let c5 = (2 * Float.pi) / 4.5

        return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(pow(2, 20 * x - 10) * sin((20 * x - 11.125) * c5)) / 2 : (pow(2, -20 * x + 10) * sin((20 * x - 11.125) * c5)) / 2 + 1
    }

    static func == (lhs: Star, rhs: Star) -> Bool {
        return lhs.posion == rhs.posion
    }
}

final class StarSequence: SequenceType {
    let numberOfmatrixs = 600
    var delegate: SequenceDelegate?
    var number: Int = 0
    let matrixHeight: Int
    let matrixWidth: Int
    var stars: [Star] = []
    let color: Color
    var stop: Bool = false

    var canStop: Bool {
        return !(number > 0 || stars.isEmpty == false)
    }

    init(matrixWidth: Int, matrixHeight: Int, color: Color) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.color = color
    }

    func runSequence() {
        reset()
        addStars()

        while canStop == false, stop == false {
            showStars()
        }
    }

    func reset() {
        stop = false
        number = numberOfmatrixs
        stars = []
    }

    private func showStars() {
        for x in 0..<matrixHeight {
            for y in 0..<matrixWidth {
                delegate?.sequenceSetPixelColor(self, point: .init(x: x, y: y), color: .black)
            }
        }

        let stars = self.stars

        stars.forEach { star in
            delegate?.sequenceSetPixelColor(self, point: star.posion, color: star.getColor())

            if star.isDone {
                self.stars.removeAll(where: { $0 == star })
            }
        }

        for _ in 0...4 {
            addStars()
        }

        delegate?.sequenceUpdatePixels(self)
    }

    private func addStars() {
        if number > 0 {
            let startRow = Int.random(in: 0...matrixWidth)

            if startRow < matrixWidth {
                let startX = Int.random(in: 0..<matrixHeight)
                let point: Point = .init(x: startX, y: startRow)

                guard stars.contains(where: { $0.posion == point }) == false else {
                    return
                }

                self.stars.append(
                    .init(
                        color: color,
                        posion: point
                    )
                )
            }

            number = number - 1
        }
    }
}
