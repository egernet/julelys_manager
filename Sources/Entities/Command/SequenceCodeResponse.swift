import Foundation

public struct SequenceCodeResponse: Codable {
    public let name: String
    public let description: String
    public let jsCode: String?
    public let isCustom: Bool
    public let error: String?

    public init(
        name: String,
        description: String,
        jsCode: String?,
        isCustom: Bool,
        error: String? = nil
    ) {
        self.name = name
        self.description = description
        self.jsCode = jsCode
        self.isCustom = isCustom
        self.error = error
    }

    public static func notFound(_ name: String) -> SequenceCodeResponse {
        SequenceCodeResponse(
            name: name,
            description: "",
            jsCode: nil,
            isCustom: false,
            error: "Sequence '\(name)' not found"
        )
    }
}
