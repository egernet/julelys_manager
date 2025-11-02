import Foundation

public struct RequestCommand: Codable {
    public enum Command: String, Codable {
        case getSequences
        case getStatus
        case runSequences
        case turnOn
        case turnOff
    }

    public let cmd: Command
    public let names: [String]?
    
    public init(cmd: Command, names: [String]? = nil) {
        self.cmd = cmd
        self.names = names
    }
}
