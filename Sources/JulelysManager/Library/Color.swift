import Foundation

public struct Color {
    public var red, green, blue: UInt8
    public var white: UInt8 = 0

    public init(red: UInt8 = 0, green: UInt8 = 0, blue: UInt8 = 0, white: UInt8 = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
    }

    public static var black = Color(red: 0, green: 0, blue: 0)
    public static var trueWhite = Color(red: 0, green: 0, blue: 0, white: 255)
    public static var white = Color(red: 255, green: 255, blue: 255)
    public static var red = Color(red: 255, green: 0, blue: 0)
    public static var green = Color(red: 0, green: 255, blue: 0)
    public static var blue = Color(red: 0, green: 0, blue: 255)
    public static var yallow = Color(red: 255, green: 255, blue: 0)
    public static var pink = Color(red: 255, green: 0, blue: 0, white: 128)
    public static var purple = Color(red: 128, green: 0, blue: 128)
    public static var magenta = Color(red: 255, green: 0, blue: 255)
    public static var orange = Color(red: 255, green: 165, blue: 0)
}

extension Color {
    static func * (lhs: Color, rhs: Float) -> Color {
        guard rhs > 0 else {
            return .black
        }

        guard rhs <= 1 else {
            return lhs
        }

        return .init(
            red: UInt8(Float(lhs.red) * rhs),
            green: UInt8(Float(lhs.green) * rhs),
            blue: UInt8(Float(lhs.blue) * rhs),
            white: UInt8(Float(lhs.white) * rhs)
        )
    }
}
