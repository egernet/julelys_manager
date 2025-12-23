import Foundation

/// Controller that generates HTML previews for LED sequences
class PreviewController {
    let matrixHeight: Int
    let matrixWidth: Int

    init(matrixWidth: Int, matrixHeight: Int) {
        self.matrixWidth = matrixWidth
        self.matrixHeight = matrixHeight
    }

    /// Generate HTML with embedded JS code that runs in the browser
    func generateHTMLWithCode(sequenceName: String, jsCode: String) -> String {
        // Transform delay(ms) to await delay(ms) for browser async compatibility
        let transformedCode = jsCode
            .replacingOccurrences(of: "delay(", with: "await delay(")

        // Load template from bundle
        guard let templatePath = Bundle.module.path(forResource: "Resources/preview_template", ofType: "html"),
              let template = try? String(contentsOfFile: templatePath, encoding: .utf8) else {
            return "Error: Could not load preview template"
        }

        // Replace placeholders
        return template
            .replacingOccurrences(of: "{{SEQUENCE_NAME}}", with: sequenceName)
            .replacingOccurrences(of: "{{MATRIX_WIDTH}}", with: String(matrixWidth))
            .replacingOccurrences(of: "{{MATRIX_HEIGHT}}", with: String(matrixHeight))
            .replacingOccurrences(of: "{{JS_CODE}}", with: transformedCode)
    }
}
