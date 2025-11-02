import Entities
import Foundation
import MCP
import SwiftyJsonSchema

enum RegisteredTools: String {
    case allSequences
    case runSequences
}

@main
struct JulelysMCP {
    static func main() async throws {
        let server = Server(
            name: "julelys",
            version: "1.0.0",
            capabilities: .init(
                prompts: .init(listChanged: true),
                resources: .init(subscribe: true, listChanged: true),
                tools: .init(listChanged: true)
            )
        )

        await registerTools(on: server)
        await server.withMethodHandler(CallTool.self, handler: toolsHandler)

        let transport = StdioTransport()
        try await server.start(transport: transport)

        await server.waitUntilCompleted()
    }
}

extension JulelysMCP {
    private static func registerTools(on server: Server) async {
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                Tool(
                    name: RegisteredTools.allSequences.rawValue,
                    description:
                        "Will return the name of all sequences that are possible to select 🎄",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([:]),
                    ])
                ),
                Tool(
                    name: RegisteredTools.runSequences.rawValue,
                    description: "Run one or more LED sequences by name 🎄",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "names": .object([
                                "type": .string("array"),
                                "items": .object([
                                    "type": .string("string"),
                                    "description": .string(
                                        "Name of a sequence to start"
                                    ),
                                ]),
                                "description": .string(
                                    "Array of sequence names to run"
                                ),
                            ])
                        ]),
                        "required": .array([.string("names")]),
                    ])
                ),
            ]
            return .init(tools: tools)
        }
    }

    private static func toolsHandler(params: CallTool.Parameters) async throws
        -> CallTool.Result
    {
        let unknownToolError = CallTool.Result(
            content: [.text("Unknown tool")],
            isError: true
        )

        // Convert tool name to our enum
        guard let tool = RegisteredTools(rawValue: params.name) else {
            return unknownToolError
        }

        switch tool {
        case RegisteredTools.allSequences:
            return .init(
                content: [.text(allSequencesHandler())],
                isError: false
            )
        case .runSequences:
            guard let namesValue = params.arguments?["names"],
                case .array(let nameArray) = namesValue
            else {
                return .init(
                    content: [
                        .text(
                            "⚠️ No sequence names provided, continuing with previous list"
                        )
                    ],
                    isError: false
                )
            }

            let names = nameArray.compactMap { value -> String? in
                if case .string(let name) = value { return name }
                return nil
            }
            
            return .init(
                content: [.text(runSequencesHandler(names))],
                isError: false
            )
        }
    }
    
    private static func runSequencesHandler(_ names: [String]) -> String {
        do {
            let request = RequestCommand(cmd: .runSequences, names: names)
            let response: RunSequencesResponse = try sendCommand(request, decodeTo: RunSequencesResponse.self)

            return "🎬 Daemon responded: \(response.status)"
        } catch {
            return "❌ Error sending runSequences: \(error.localizedDescription)"
        }
    }

    private static func allSequencesHandler() -> String {
        do {
            let result: AllSequences = try sendCommand(
                .init(cmd: .getSequences),
                decodeTo: AllSequences.self
            )

            let list = result.sequences
                .map { "• \($0.name) — \($0.description)" }
                .joined(separator: "\n")

            return "🎄 Available sequences:\n\(list)"
        } catch {
            return "❌ \(error)"
        }
    }
}

extension JulelysMCP {
    enum SocketError: Error {
        case operationFailed(String)
        case decodeFailed(String)
    }

    private static func sendCommand<T: Codable>(
        _ request: RequestCommand,
        decodeTo type: T.Type
    ) throws -> T {
        // 1️⃣ Opret UNIX-socket
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw SocketError.operationFailed("socket() failed: \(errno)")
        }

        // 2️⃣ Sæt op forbindelse
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let socketPath = "/tmp/julelys.sock"
        _ = socketPath.withCString { strcpy(&addr.sun_path.0, $0) }

        let addrLen = socklen_t(
            MemoryLayout.size(ofValue: addr.sun_family) + socketPath.utf8.count
                + 1
        )

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, addrLen)
            }
        }

        guard connectResult == 0 else {
            let err = errno
            close(sock)
            throw SocketError.operationFailed(
                "connect() failed: \(String(cString: strerror(err)))"
            )
        }

        // 3️⃣ JSON-encode request
        let data = try JSONEncoder().encode(request)
        data.withUnsafeBytes { ptr in
            _ = write(sock, ptr.baseAddress, ptr.count)
        }

        // 4️⃣ Læs svar
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = read(sock, &buffer, buffer.count)
        close(sock)

        guard bytesRead > 0 else {
            throw SocketError.operationFailed("no data received")
        }

        // 5️⃣ Decode svar til model
        do {
            let responseData = Data(buffer[0..<bytesRead])
            let decoded = try JSONDecoder().decode(T.self, from: responseData)
            return decoded
        } catch {
            let raw = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
            throw SocketError.decodeFailed(
                "decode error: \(error.localizedDescription)\nResponse: \(raw)"
            )
        }
    }
}
