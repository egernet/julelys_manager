import Foundation

class FireworksStar: Equatable {
    let faktor: Float
    var posion: Point
    let color: Color
    var isDone: Bool = false
    var time: Float = 0
    var value: Float
    let length: Int = 2

    init(color: Color, posion: Point) {
        self.posion = posion
        self.color = color
        self.faktor = Float(Double.random(in: 0.1...0.2))
        self.value = faktor
    }

    func getColor() -> Color {
        time = time + value

        if time >= 1 {
            value = -faktor
        }

        if time <= 0 {
            time = 0
            isDone = true
        }

        return color * easeInOutElastic(time)
    }

    func getTheTailPoint(of index: Int) -> Point {
        let f = index.isMultiple(of: 2) ? -1 : 1
        return .init(x: posion.x + f, y: posion.y)
    }

    func getTheTailColor(of index: Int) -> Color {
        return color * 0.2 * easeInOutElastic(time)
    }

    private func easeInOutElastic(_ x: Float) -> Float {
        let c5 = (2 * Float.pi) / 4.5

        return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(pow(2, 20 * x - 10) * sin((20 * x - 11.125) * c5)) / 2 : (pow(2, -20 * x + 10) * sin((20 * x - 11.125) * c5)) / 2 + 1
    }

    static func == (lhs: FireworksStar, rhs: FireworksStar) -> Bool {
        return lhs.posion == rhs.posion
    }
}

final class FireworksSequence: SequenceType {
    let numberOfmatrixs = 800
    var delegate: SequenceDelegate?
    var number: Int = 0
    let matrixHeight: Int
    let matrixWidth: Int
    var stars: [FireworksStar] = []
    var color: Color = .trueWhite
    let colors: [Color]
    var stop: Bool = false

    var canStop: Bool {
        return !(number > 0 || stars.isEmpty == false)
    }

    init(matrixWidth: Int, matrixHeight: Int, colors: [Color]) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.colors = colors
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
        var indexColor = Int.random(in: 0..<colors.count)
        for _ in 0...colors.count {
            indexColor = Int.random(in: 0..<colors.count)
        }

        self.color = colors[indexColor]
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
