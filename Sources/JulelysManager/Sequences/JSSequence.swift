import Foundation
import SwiftJS

final class JSSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let jsFile: String?
    var stop = false

    private var ctx: JSContext?
    private var code: String?
    private var directCode: String?

    init(matrixWidth: Int, matrixHeight: Int, jsFile: String) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.jsFile = jsFile
        self.directCode = nil
    }

    init(matrixWidth: Int, matrixHeight: Int, jsCode: String) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.jsFile = nil
        self.directCode = jsCode
    }

    private func setPixelColor(point: Point, color: Color) {
        delegate?.sequenceSetPixelColor(self, point: point, color: color)
    }

    private func updatePixels() {
        delegate?.sequenceUpdatePixels(self)
    }

    private func setupJS() {
        if let directCode = directCode {
            code = directCode
        } else if let jsFile = jsFile,
                  let path = Bundle.module.path(forResource: "SequencesJS", ofType: nil) {
            let filePath = path + "/" + jsFile
            code = try? String(contentsOfFile: filePath, encoding: .utf8)
        }

        let context = JSContext()
        self.ctx = context

        // --- delay(ms)
        // delay() and updatePixels() throw once the sequence is stopped, so a script
        // with an endless loop still ends when another sequence is selected.
        let delayFn = JSObject(newFunctionIn: context) { [weak self] context, this, arguments in
            try self?.abortIfStopped(context)
            if let ms = arguments.first?.doubleValue {
                Thread.sleep(forTimeInterval: ms / 1000)
            }
            try self?.abortIfStopped(context)
            return .init(undefinedIn: context)
        }

        context.global["delay"] = delayFn

        // --- setPixelColor(r,g,b,w,x,y)
        let setPixelFn = JSObject(newFunctionIn: context) { [weak self] context, this, args in
            guard let self else { return .init(undefinedIn: context) }
            guard args.count >= 6 else { return .init(undefinedIn: context) }

            // Scripts can pass anything; UInt8(_:) and Int(_:) trap on values out
            // of range or NaN, which would take the whole manager down.
            let r = Self.colorByte(args[0].doubleValue)
            let g = Self.colorByte(args[1].doubleValue)
            let b = Self.colorByte(args[2].doubleValue)
            let w = Self.colorByte(args[3].doubleValue)
            guard let x = Self.index(args[4].doubleValue),
                  let y = Self.index(args[5].doubleValue) else {
                return .init(undefinedIn: context)
            }

            let color = Color(red: r, green: g, blue: b, white: w)
            let point = Point(x: x, y: y)
            self.setPixelColor(point: point, color: color)
            return .init(undefinedIn: context)
        }

        context.global["setPixelColor"] = setPixelFn

        // --- updatePixels()
        let updateFn = JSObject(newFunctionIn: context) { [weak self] context, this, _ in
            try self?.abortIfStopped(context)
            self?.updatePixels()
            return .init(undefinedIn: context)
        }

        context.global["updatePixels"] = updateFn

        // --- matrix objekt
        context.global["matrix"] = JSObject(newObjectIn: context)

        let width = JSPropertyDescriptor(
            getter: { this in JSObject(double: Double(self.matrixWidth), in: this.context) }
        )

        let height = JSPropertyDescriptor(
            getter: { this in JSObject(double: Double(self.matrixHeight), in: this.context) }
        )

        context.global["matrix"].defineProperty("width", width)
        context.global["matrix"].defineProperty("height", height)
    }

    /// Clamps a script value to 0...255, rounding down like `Math.floor`.
    private static func colorByte(_ value: Double?) -> UInt8 {
        guard let value, value.isFinite else { return 0 }
        return UInt8(min(255, max(0, value.rounded(.down))))
    }

    /// Converts a script coordinate, or nil when it cannot be a valid index.
    private static func index(_ value: Double?) -> Int? {
        guard let value, value.isFinite, abs(value) < 1_000_000 else { return nil }
        return Int(value.rounded(.down))
    }

    private func abortIfStopped(_ context: JSContext) throws {
        if stop {
            throw JSObject(newErrorFromMessage: "Sequence stopped", in: context)
        }
    }

    func runSequence() {
        stop = false
        setupJS()

        guard let ctx, let code else { return }

        _ = ctx.evaluateScript(code)
    }
}
