import Foundation

public struct PreviewResponse: Codable {
    public let success: Bool
    public let sequenceName: String
    public let gifPath: String?
    public let gifBase64: String?
    public let htmlContent: String?
    public let frameCount: Int
    public let error: String?

    public init(
        success: Bool,
        sequenceName: String,
        gifPath: String? = nil,
        gifBase64: String? = nil,
        htmlContent: String? = nil,
        frameCount: Int = 0,
        error: String? = nil
    ) {
        self.success = success
        self.sequenceName = sequenceName
        self.gifPath = gifPath
        self.gifBase64 = gifBase64
        self.htmlContent = htmlContent
        self.frameCount = frameCount
        self.error = error
    }

    public static func failure(sequenceName: String, error: String) -> PreviewResponse {
        PreviewResponse(
            success: false,
            sequenceName: sequenceName,
            error: error
        )
    }
}
