import Foundation
import SwiftJS

final class JSSequence: SequenceType {
    var delegate: SequenceDelegate?
    let matrixHeight: Int
    let matrixWidth: Int
    let jsFile: String?
    var stop = false
    var previewMode = false  // Skip delays when true

    private var ctx: JSContext?
    private var code: String?
    private var directCode: String?

    init(matrixWidth: Int, matrixHeight: Int, jsFile: String) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.jsFile = jsFile
        self.directCode = nil
    }

    init(matrixWidth: Int, matrixHeight: Int, jsCode: String, previewMode: Bool = false) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.jsFile = nil
        self.directCode = jsCode
        self.previewMode = previewMode
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
        let delayFn = JSObject(newFunctionIn: context) { [weak self] context, this, arguments in
            // Skip delays in preview mode for faster GIF generation
            guard self?.previewMode != true else {
                return .init(undefinedIn: context)
            }
            if let ms = arguments.first?.doubleValue {
                Thread.sleep(forTimeInterval: ms / 1000)
            }
            return .init(undefinedIn: context)
        }
        
        context.global["delay"] = delayFn

        // --- setPixelColor(r,g,b,w,x,y)
        let setPixelFn = JSObject(newFunctionIn: context) { [weak self] context, this, args in
            guard let self else { return .init(undefinedIn: context) }
            guard args.count >= 6 else { return .init(undefinedIn: context) }

            let r = UInt8(args[0].doubleValue ?? 0)
            let g = UInt8(args[1].doubleValue ?? 0)
            let b = UInt8(args[2].doubleValue ?? 0)
            let w = UInt8(args[3].doubleValue ?? 0)
            let x = Int(args[4].doubleValue ?? 0)
            let y = Int(args[5].doubleValue ?? 0)

            let color = Color(red: r, green: g, blue: b, white: w)
            let point = Point(x: x, y: y)
            self.setPixelColor(point: point, color: color)
            return .init(undefinedIn: context)
        }
        
        context.global["setPixelColor"] = setPixelFn

        // --- updatePixels()
        let updateFn = JSObject(newFunctionIn: context) { [weak self] context, this, _ in
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

    func runSequence() {
        setupJS()
        
        guard let ctx, let code else { return }

        _ = ctx.evaluateScript(code)
    }
}
