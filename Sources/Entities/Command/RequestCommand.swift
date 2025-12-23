import Foundation

public struct RequestCommand: Codable {
    public enum Command: String, Codable {
        case getSequences
        case getStatus
        case runSequences
        case turnOn
        case turnOff
        case createSequence
        case updateSequence
        case getSequenceCode
        case previewSequence
    }

    public let cmd: Command
    public let names: [String]?
    public let sequenceName: String?
    public let sequenceDescription: String?
    public let jsCode: String?

    public init(
        cmd: Command,
        names: [String]? = nil,
        sequenceName: String? = nil,
        sequenceDescription: String? = nil,
        jsCode: String? = nil
    ) {
        self.cmd = cmd
        self.names = names
        self.sequenceName = sequenceName
        self.sequenceDescription = sequenceDescription
        self.jsCode = jsCode
    }
}
