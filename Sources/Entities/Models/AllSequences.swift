import Foundation

public struct AllSequences: Codable {
    public let sequences: [SequenceInfo]
    
    public init(sequences: [SequenceInfo]) {
        self.sequences = sequences
    }
}
