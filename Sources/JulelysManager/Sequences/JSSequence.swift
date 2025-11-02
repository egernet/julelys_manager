import Foundation
import elk

var ptrJSSequence: UnsafeMutableRawPointer?

final class JSSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let colors: [Color] = [.red, .green, .blue, .trueWhite, .black]
    let jsFile: String
    var stop: Bool = false

    private var jsEngine: OpaquePointer?
    private var buffer: [Int8] = []
    private let bufferSize: Int
    private var code: String?

    init(matrixWidth: Int, matrixHeight: Int, jsFile: String, bufferSize: Int = 65536) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.bufferSize = bufferSize
        self.jsFile = jsFile
    }

    private func setPixelColor(point: Point, color: Color) {
        delegate?.sequenceSetPixelColor(self, point: point, color: color)
    }

    private func updatePixels() {
        delegate?.sequenceUpdatePixels(self)
    }

    private func setupJS() {
        let path = Bundle.module.path(forResource: "SequencesJS", ofType: nil) ?? ""
        let filePath = path + "/" + jsFile
        code = try? String(contentsOfFile: filePath, encoding: String.Encoding.utf8)

        let delayClosure: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt64>?, Int32) -> jsval_t = { _, args, _ -> jsval_t in
            let time = js_getnum(args?[0] ?? 0) / 1000
            Thread.sleep(forTimeInterval: time)
            return js_mknum(0)
        }

        let colorClosure: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt64>?, Int32) -> jsval_t = { _, args, _ -> jsval_t in
            guard let ptrJSSequence else { return js_mknum(0) }

            let red: UInt8 = UInt8(js_getnum(args?[0] ?? 0))
            let green: UInt8 = UInt8(js_getnum(args?[1] ?? 0))
            let blue: UInt8 = UInt8(js_getnum(args?[2] ?? 0))
            let white: UInt8 = UInt8(js_getnum(args?[3] ?? 0))
            let x: Int = Int(js_getnum(args?[4] ?? 0))
            let y: Int = Int(js_getnum(args?[5] ?? 0))

            let color = Color(red: red, green: green, blue: blue, white: white)
            let point = Point(x: x, y: y)

            let safeSelfObj: JSSequence = Unmanaged.fromOpaque(ptrJSSequence).takeUnretainedValue()
            safeSelfObj.setPixelColor(point: point, color: color)

            return js_mknum(0)
        }

        let updateColorClosure: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt64>?, Int32) -> jsval_t = { _, _, _ -> jsval_t in
            guard let ptrJSSequence else { return js_mknum(0) }

            let safeSelfObj: JSSequence = Unmanaged.fromOpaque(ptrJSSequence).takeUnretainedValue()
            safeSelfObj.updatePixels()

            return js_mknum(0)
        }

        self.buffer = [Int8](repeating: 0, count: bufferSize)
        let unsafeBuffer: UnsafeMutablePointer<Int8> = .init(mutating: buffer)
        jsEngine = js_create(unsafeBuffer, buffer.count)

        let global = js_glob(jsEngine)
        let matrix = js_mkobj(jsEngine)

        js_set(jsEngine, global, "delay", js_mkfun(delayClosure))
        js_set(jsEngine, global, "setPixelColor", js_mkfun(colorClosure))
        js_set(jsEngine, global, "updatePixels", js_mkfun(updateColorClosure))
        js_set(jsEngine, global, "matrix", matrix)

        let matrixHeight: Double = Double(matrixHeight)
        let matrixWidth: Double = Double(matrixWidth)
        js_set(jsEngine, matrix, "height", js_mknum(matrixHeight))
        js_set(jsEngine, matrix, "width", js_mknum(matrixWidth))
    }

    func runSequence() {
        setupJS()

        guard let code else {
            return
        }

        ptrJSSequence = Unmanaged.passUnretained(self).toOpaque()

        js_eval(self.jsEngine, code, Int.max)
    }
}
