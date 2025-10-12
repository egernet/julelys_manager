import Foundation

struct Point {
    let x: Int
    let y: Int

    ///
    /// a + b
    ///
    static func + (left: Point, right: Point) -> Point {
        return .init(x: left.x + right.x, y: left.y + right.y)
    }

    ///
    /// a += b
    ///
    static func += (left: inout Point, right: Point) {
        left = left + right
    }
}

extension Point: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
