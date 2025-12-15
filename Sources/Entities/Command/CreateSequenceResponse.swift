import Foundation

public struct CreateSequenceResponse: Codable {
    public let status: String
    public let sequenceName: String?
    public let error: String?

    public init(status: String, sequenceName: String? = nil, error: String? = nil) {
        self.status = status
        self.sequenceName = sequenceName
        self.error = error
    }
}
