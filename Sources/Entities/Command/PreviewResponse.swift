import Foundation

public struct PreviewResponse: Codable {
    public let success: Bool
    public let sequenceName: String
    public let htmlPath: String?
    public let htmlContent: String?
    public let error: String?

    public init(
        success: Bool,
        sequenceName: String,
        htmlPath: String? = nil,
        htmlContent: String? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.sequenceName = sequenceName
        self.htmlPath = htmlPath
        self.htmlContent = htmlContent
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
