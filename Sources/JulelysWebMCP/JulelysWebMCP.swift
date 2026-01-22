import Entities
import Foundation
import Hummingbird
import HTTPTypes

// MARK: - MCP Types for JSON-RPC

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: JSONRPCId?
    let method: String
    let params: [String: JSONValue]?
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: JSONRPCId?
    let result: JSONValue?
    let error: JSONRPCError?

    init(id: JSONRPCId?, result: JSONValue) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    init(id: JSONRPCId?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: JSONValue?

    init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    static let internalError = JSONRPCError(code: -32603, message: "Internal error")
}

enum JSONRPCId: Codable, Equatable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(JSONRPCId.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected string or int"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        }
    }
}

enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unknown JSON type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }
}

// MARK: - Tool Definitions

enum RegisteredTools: String, CaseIterable {
    case allSequences
    case runSequences
    case createSequence
    case updateSequence
    case getStatus
    case getSequenceCode
    case previewSequence
}

// MARK: - MCP Server State

actor MCPServerState {
    private var sessions: [String: MCPSession] = [:]

    func createSession() -> String {
        let sessionId = UUID().uuidString
        sessions[sessionId] = MCPSession(id: sessionId)
        return sessionId
    }

    func getSession(_ id: String) -> MCPSession? {
        return sessions[id]
    }

    func removeSession(_ id: String) {
        sessions.removeValue(forKey: id)
    }
}

struct MCPSession {
    let id: String
    var initialized: Bool = false
}

// MARK: - Custom Header Names

extension HTTPField.Name {
    static var mcpSessionId: Self { .init("Mcp-Session-Id")! }
    static var accessControlAllowOrigin: Self { .init("Access-Control-Allow-Origin")! }
    static var accessControlAllowMethods: Self { .init("Access-Control-Allow-Methods")! }
    static var accessControlAllowHeaders: Self { .init("Access-Control-Allow-Headers")! }
}

// MARK: - Main Application

@main
struct JulelysWebMCP {
    static let serverState = MCPServerState()

    static func main() async throws {
        let router = Router()

        // Health check
        router.get("/health") { _, _ in
            return Response(status: .ok, body: .init(byteBuffer: .init(string: "OK")))
        }

        // OPTIONS for CORS preflight
        router.on("/mcp", method: .options) { _, _ in
            var headers = HTTPFields()
            headers[.accessControlAllowOrigin] = "*"
            headers[.accessControlAllowMethods] = "GET, POST, OPTIONS"
            headers[.accessControlAllowHeaders] = "Content-Type, Mcp-Session-Id"
            return Response(status: .ok, headers: headers, body: .init())
        }

        // MCP endpoint - handles POST (client->server)
        router.post("/mcp") { request, context in
            return try await handleMCPRequest(request, context: context)
        }

        // SSE endpoint for server-initiated messages
        router.get("/mcp") { request, context in
            return try await handleMCPSSE(request, context: context)
        }

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("0.0.0.0", port: 8080)
            )
        )

        print("JulelysWebMCP starting on http://0.0.0.0:8080")
        print("MCP endpoint: POST/GET http://0.0.0.0:8080/mcp")

        try await app.run()
    }

    // MARK: - MCP Request Handler

    static func handleMCPRequest(_ request: Request, context: some RequestContext) async throws -> Response {
        let body = try await request.body.collect(upTo: 1024 * 1024) // 1MB max

        guard let jsonRequest = try? JSONDecoder().decode(JSONRPCRequest.self, from: body) else {
            let error = JSONRPCResponse(id: nil, error: .parseError)
            return jsonResponse(error)
        }

        // Get or create session
        let sessionId: String
        if let existingId = request.headers[.mcpSessionId] {
            sessionId = existingId
        } else {
            sessionId = await serverState.createSession()
        }

        let response = await handleMethod(jsonRequest, sessionId: sessionId)

        var httpResponse = jsonResponse(response)
        httpResponse.headers[.mcpSessionId] = sessionId
        httpResponse.headers[.accessControlAllowOrigin] = "*"
        return httpResponse
    }

    static func handleMCPSSE(_ request: Request, context: some RequestContext) async throws -> Response {
        // For SSE, we return a streaming response
        // This is used for server-initiated messages (notifications)
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.connection] = "keep-alive"
        headers[.accessControlAllowOrigin] = "*"

        return Response(
            status: .ok,
            headers: headers,
            body: .init(byteBuffer: .init(string: "data: {\"type\": \"connected\"}\n\n"))
        )
    }

    // MARK: - Method Router

    static func handleMethod(_ request: JSONRPCRequest, sessionId: String) async -> JSONRPCResponse {
        switch request.method {
        case "initialize":
            return handleInitialize(request)
        case "initialized":
            return JSONRPCResponse(id: request.id, result: .object([:]))
        case "tools/list":
            return handleToolsList(request)
        case "tools/call":
            return await handleToolsCall(request)
        case "ping":
            return JSONRPCResponse(id: request.id, result: .object([:]))
        default:
            return JSONRPCResponse(id: request.id, error: .methodNotFound)
        }
    }

    // MARK: - MCP Method Handlers

    static func handleInitialize(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let result: JSONValue = .object([
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .object([
                "tools": .object([
                    "listChanged": .bool(true)
                ])
            ]),
            "serverInfo": .object([
                "name": .string("julelys-web"),
                "version": .string("1.0.0")
            ])
        ])
        return JSONRPCResponse(id: request.id, result: result)
    }

    static func handleToolsList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let tools: [JSONValue] = [
            toolDefinition(
                name: "allSequences",
                description: "Will return the name of all sequences that are possible to select",
                properties: [:]
            ),
            toolDefinition(
                name: "runSequences",
                description: "Run one or more LED sequences by name",
                properties: [
                    "names": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Array of sequence names to run")
                    ])
                ],
                required: ["names"]
            ),
            toolDefinition(
                name: "createSequence",
                description: """
                    Create a new LED sequence using JavaScript.

                    Available JavaScript API:
                    - setPixelColor(r, g, b, w, x, y) - Set pixel color (RGBW 0-255)
                    - updatePixels() - Send the frame to the LEDs
                    - delay(ms) - Wait for milliseconds
                    - matrix.width - Number of strings/columns (default 8)
                    - matrix.height - Number of LEDs per string/rows (default 55)
                    """,
                properties: [
                    "name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the sequence")
                    ]),
                    "description": .object([
                        "type": .string("string"),
                        "description": .string("Description of what the sequence does")
                    ]),
                    "jsCode": .object([
                        "type": .string("string"),
                        "description": .string("JavaScript code for the sequence")
                    ])
                ],
                required: ["name", "description", "jsCode"]
            ),
            toolDefinition(
                name: "updateSequence",
                description: "Update an existing custom LED sequence",
                properties: [
                    "name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the sequence to update")
                    ]),
                    "description": .object([
                        "type": .string("string"),
                        "description": .string("New description (optional)")
                    ]),
                    "jsCode": .object([
                        "type": .string("string"),
                        "description": .string("New JavaScript code")
                    ])
                ],
                required: ["name", "jsCode"]
            ),
            toolDefinition(
                name: "getStatus",
                description: "Get the current status of the Julelys Manager",
                properties: [:]
            ),
            toolDefinition(
                name: "getSequenceCode",
                description: "Get the JavaScript code for a sequence",
                properties: [
                    "name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the sequence")
                    ])
                ],
                required: ["name"]
            ),
            toolDefinition(
                name: "previewSequence",
                description: "Generate an interactive HTML preview of a JavaScript sequence",
                properties: [
                    "name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the sequence to preview")
                    ])
                ],
                required: ["name"]
            )
        ]

        return JSONRPCResponse(id: request.id, result: .object([
            "tools": .array(tools)
        ]))
    }

    static func toolDefinition(
        name: String,
        description: String,
        properties: [String: JSONValue],
        required: [String] = []
    ) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": .string("object"),
            "properties": .object(properties)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }

        return .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object(schema)
        ])
    }

    static func handleToolsCall(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let params = request.params,
              case .string(let toolName) = params["name"],
              let tool = RegisteredTools(rawValue: toolName) else {
            return JSONRPCResponse(id: request.id, error: .invalidParams)
        }

        let arguments = params["arguments"]
        let resultText: String

        switch tool {
        case .allSequences:
            resultText = allSequencesHandler()
        case .runSequences:
            if case .object(let args) = arguments,
               case .array(let namesArray) = args["names"] {
                let names = namesArray.compactMap { value -> String? in
                    if case .string(let s) = value { return s }
                    return nil
                }
                resultText = runSequencesHandler(names)
            } else {
                resultText = "No sequence names provided"
            }
        case .createSequence:
            if case .object(let args) = arguments,
               case .string(let name) = args["name"],
               case .string(let description) = args["description"],
               case .string(let jsCode) = args["jsCode"] {
                resultText = createSequenceHandler(name: name, description: description, jsCode: jsCode)
            } else {
                resultText = "Missing required parameters"
            }
        case .updateSequence:
            if case .object(let args) = arguments,
               case .string(let name) = args["name"],
               case .string(let jsCode) = args["jsCode"] {
                var description: String? = nil
                if case .string(let desc) = args["description"] {
                    description = desc
                }
                resultText = updateSequenceHandler(name: name, description: description, jsCode: jsCode)
            } else {
                resultText = "Missing required parameters"
            }
        case .getStatus:
            resultText = getStatusHandler()
        case .getSequenceCode:
            if case .object(let args) = arguments,
               case .string(let name) = args["name"] {
                resultText = getSequenceCodeHandler(name: name)
            } else {
                resultText = "Missing required parameter: name"
            }
        case .previewSequence:
            if case .object(let args) = arguments,
               case .string(let name) = args["name"] {
                resultText = previewSequenceHandler(name: name)
            } else {
                resultText = "Missing required parameter: name"
            }
        }

        let result: JSONValue = .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(resultText)
                ])
            ])
        ])

        return JSONRPCResponse(id: request.id, result: result)
    }

    // MARK: - Tool Handlers (reused from JulelysMCP)

    static func allSequencesHandler() -> String {
        do {
            let result: AllSequences = try sendCommand(
                .init(cmd: .getSequences),
                decodeTo: AllSequences.self
            )
            let list = result.sequences
                .map { "- \($0.name): \($0.description)" }
                .joined(separator: "\n")
            return "Available sequences:\n\(list)"
        } catch {
            return "Error: \(error)"
        }
    }

    static func runSequencesHandler(_ names: [String]) -> String {
        do {
            let request = RequestCommand(cmd: .runSequences, names: names)
            let response: RunSequencesResponse = try sendCommand(request, decodeTo: RunSequencesResponse.self)
            return "Daemon responded: \(response.status)"
        } catch {
            return "Error sending runSequences: \(error.localizedDescription)"
        }
    }

    static func createSequenceHandler(name: String, description: String, jsCode: String) -> String {
        do {
            let request = RequestCommand(
                cmd: .createSequence,
                sequenceName: name,
                sequenceDescription: description,
                jsCode: jsCode
            )
            let response: CreateSequenceResponse = try sendCommand(request, decodeTo: CreateSequenceResponse.self)
            if let error = response.error {
                return "Failed to create sequence: \(error)"
            }
            return "Sequence '\(response.sequenceName ?? name)' created successfully!"
        } catch {
            return "Error creating sequence: \(error.localizedDescription)"
        }
    }

    static func updateSequenceHandler(name: String, description: String?, jsCode: String) -> String {
        do {
            let request = RequestCommand(
                cmd: .updateSequence,
                sequenceName: name,
                sequenceDescription: description,
                jsCode: jsCode
            )
            let response: CreateSequenceResponse = try sendCommand(request, decodeTo: CreateSequenceResponse.self)
            if let error = response.error {
                return "Failed to update sequence: \(error)"
            }
            return "Sequence '\(response.sequenceName ?? name)' updated successfully!"
        } catch {
            return "Error updating sequence: \(error.localizedDescription)"
        }
    }

    static func getStatusHandler() -> String {
        do {
            let request = RequestCommand(cmd: .getStatus)
            let response: StatusResponse = try sendCommand(request, decodeTo: StatusResponse.self)
            let activeList = response.activeSequences.isEmpty
                ? "None"
                : response.activeSequences.joined(separator: ", ")
            return """
                Julelys Manager Status

                Running: \(response.isRunning ? "Yes" : "No")
                Mode: \(response.mode)
                Matrix: \(response.matrixWidth) x \(response.matrixHeight) (\(response.matrixWidth * response.matrixHeight) LEDs)

                Active sequences: \(activeList)
                Available sequences: \(response.availableSequencesCount)
                """
        } catch {
            return "Error getting status: \(error.localizedDescription)\n\nIs JulelysManager running?"
        }
    }

    static func getSequenceCodeHandler(name: String) -> String {
        do {
            let request = RequestCommand(cmd: .getSequenceCode, sequenceName: name)
            let response: SequenceCodeResponse = try sendCommand(request, decodeTo: SequenceCodeResponse.self)
            if let error = response.error {
                return error
            }
            guard let jsCode = response.jsCode else {
                return "No code available for '\(name)'"
            }
            return """
                Sequence: \(response.name)
                Description: \(response.description)
                Type: \(response.isCustom ? "Custom (JS)" : "Built-in")

                ```javascript
                \(jsCode)
                ```
                """
        } catch {
            return "Error getting sequence code: \(error.localizedDescription)"
        }
    }

    static func previewSequenceHandler(name: String) -> String {
        do {
            let request = RequestCommand(cmd: .previewSequence, sequenceName: name)
            let response: PreviewResponse = try sendCommand(request, decodeTo: PreviewResponse.self)
            if let error = response.error {
                return error
            }
            if response.success {
                var result = "Preview Generated for '\(response.sequenceName)'"
                if let path = response.htmlPath {
                    result += "\nHTML saved to: \(path)"
                }
                return result
            } else {
                return "Preview failed: \(response.error ?? "Unknown error")"
            }
        } catch {
            return "Error generating preview: \(error.localizedDescription)"
        }
    }

    // MARK: - Socket Communication

    enum SocketError: Error {
        case operationFailed(String)
        case decodeFailed(String)
    }

    static func sendCommand<T: Codable>(
        _ request: RequestCommand,
        decodeTo type: T.Type
    ) throws -> T {
        #if os(Linux)
        let sock = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        #endif
        guard sock >= 0 else {
            throw SocketError.operationFailed("socket() failed: \(errno)")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let socketPath = "/tmp/julelys.sock"
        _ = socketPath.withCString { strcpy(&addr.sun_path.0, $0) }

        let addrLen = socklen_t(
            MemoryLayout.size(ofValue: addr.sun_family) + socketPath.utf8.count + 1
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

        let data = try JSONEncoder().encode(request)
        data.withUnsafeBytes { ptr in
            _ = write(sock, ptr.baseAddress, ptr.count)
        }

        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)

        while true {
            let bytesRead = read(sock, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            responseData.append(contentsOf: buffer[0..<bytesRead])
        }
        close(sock)

        guard !responseData.isEmpty else {
            throw SocketError.operationFailed("no data received")
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: responseData)
            return decoded
        } catch {
            let raw = String(decoding: responseData.prefix(500), as: UTF8.self)
            throw SocketError.decodeFailed(
                "decode error: \(error.localizedDescription)\nResponse: \(raw)"
            )
        }
    }

    // MARK: - Helpers

    static func jsonResponse(_ response: JSONRPCResponse) -> Response {
        let data = try! JSONEncoder().encode(response)
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return Response(
            status: .ok,
            headers: headers,
            body: .init(byteBuffer: .init(data: data))
        )
    }
}
