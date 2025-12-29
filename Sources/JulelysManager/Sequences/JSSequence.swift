import Foundation
import JavaScriptCore

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

        guard let context = JSContext() else { return }
        self.ctx = context

        // --- delay(ms)
        let delayFn: @convention(block) (Double) -> Void = { ms in
            Thread.sleep(forTimeInterval: ms / 1000)
        }
        context.setObject(delayFn, forKeyedSubscript: "delay" as NSString)

        // --- setPixelColor(r,g,b,w,x,y)
        let setPixelFn: @convention(block) (Double, Double, Double, Double, Double, Double) -> Void = { [weak self] r, g, b, w, x, y in
            guard let self else { return }
            let color = Color(red: UInt8(r), green: UInt8(g), blue: UInt8(b), white: UInt8(w))
            let point = Point(x: Int(x), y: Int(y))
            self.setPixelColor(point: point, color: color)
        }
        context.setObject(setPixelFn, forKeyedSubscript: "setPixelColor" as NSString)

        // --- updatePixels()
        let updateFn: @convention(block) () -> Void = { [weak self] in
            self?.updatePixels()
        }
        context.setObject(updateFn, forKeyedSubscript: "updatePixels" as NSString)

        // --- matrix objekt
        let matrixObj: [String: Any] = [
            "width": matrixWidth,
            "height": matrixHeight
        ]
        context.setObject(matrixObj, forKeyedSubscript: "matrix" as NSString)
    }

    func runSequence() {
        setupJS()

        guard let ctx, let code else { return }

        ctx.evaluateScript(code)
    }
}
