import Foundation

public struct StatusResponse: Codable {
    public let isRunning: Bool
    public let activeSequences: [String]
    public let availableSequencesCount: Int
    public let matrixWidth: Int
    public let matrixHeight: Int
    public let mode: String

    public init(
        isRunning: Bool,
        activeSequences: [String],
        availableSequencesCount: Int,
        matrixWidth: Int,
        matrixHeight: Int,
        mode: String
    ) {
        self.isRunning = isRunning
        self.activeSequences = activeSequences
        self.availableSequencesCount = availableSequencesCount
        self.matrixWidth = matrixWidth
        self.matrixHeight = matrixHeight
        self.mode = mode
    }
}
