import Foundation

public struct RunSequencesResponse: Codable {
    public let status: String
    
    public init(status: String) {
        self.status = status
    }
}

