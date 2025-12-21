import Entities
import Foundation
import MCP

enum RegisteredTools: String {
    case allSequences
    case runSequences
    case createSequence
    case updateSequence
    case getStatus
    case getSequenceCode
    case previewSequence
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
                Tool(
                    name: RegisteredTools.createSequence.rawValue,
                    description: """
                        Create a new LED sequence using JavaScript 🎄

                        Available JavaScript API:
                        - setPixelColor(r, g, b, w, x, y) - Set pixel color (RGBW 0-255)
                        - updatePixels() - Send the frame to the LEDs (call after setting pixels)
                        - delay(ms) - Wait for milliseconds
                        - matrix.width - Number of strings/columns (default 8)
                        - matrix.height - Number of LEDs per string/rows (default 55)

                        Coordinate system:
                        - x = row position (0 to matrix.height-1, vertical along string)
                        - y = column/string number (0 to matrix.width-1, horizontal)

                        Example template:
                        ```javascript
                        // Loop forever or for a number of iterations
                        for (let frame = 0; frame < 100; frame++) {
                            // Set each pixel
                            for (let y = 0; y < matrix.width; y++) {       // Each string (column)
                                for (let x = 0; x < matrix.height; x++) {  // Each LED in string (row)
                                    let r = 255;  // Red 0-255
                                    let g = 0;    // Green 0-255
                                    let b = 0;    // Blue 0-255
                                    let w = 0;    // White 0-255
                                    setPixelColor(r, g, b, w, x, y);
                                }
                            }
                            updatePixels();  // Send frame to LEDs
                            delay(33);       // ~30 FPS
                        }
                        ```
                        """,
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Name of the sequence (used to run it later)"),
                            ]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("Description of what the sequence does"),
                            ]),
                            "jsCode": .object([
                                "type": .string("string"),
                                "description": .string("JavaScript code for the sequence"),
                            ])
                        ]),
                        "required": .array([.string("name"), .string("description"), .string("jsCode")]),
                    ])
                ),
                Tool(
                    name: RegisteredTools.updateSequence.rawValue,
                    description: """
                        Update an existing custom LED sequence 🎄

                        Only custom sequences (created via createSequence) can be updated.
                        Built-in sequences cannot be modified.

                        The same JavaScript API is available as in createSequence.
                        """,
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Name of the sequence to update"),
                            ]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("New description (optional, leave empty to keep existing)"),
                            ]),
                            "jsCode": .object([
                                "type": .string("string"),
                                "description": .string("New JavaScript code for the sequence"),
                            ])
                        ]),
                        "required": .array([.string("name"), .string("jsCode")]),
                    ])
                ),
                Tool(
                    name: RegisteredTools.getStatus.rawValue,
                    description: """
                        Get the current status of the Julelys Manager 🎄

                        Returns information about:
                        - Whether the manager is running
                        - Currently active sequences
                        - Number of available sequences
                        - Matrix dimensions (width x height)
                        - Current mode (real/app/console)
                        """,
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([:]),
                    ])
                ),
                Tool(
                    name: RegisteredTools.getSequenceCode.rawValue,
                    description: """
                        Get the JavaScript code for a custom sequence 🎄

                        Returns the JS code and description for a custom sequence.
                        Only works for sequences created via createSequence.
                        Built-in sequences (Swift-based) don't have viewable code.
                        """,
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Name of the sequence to get code for"),
                            ])
                        ]),
                        "required": .array([.string("name")]),
                    ])
                ),
                Tool(
                    name: RegisteredTools.previewSequence.rawValue,
                    description: """
                        Generate a GIF preview of a JavaScript sequence 🎬

                        Creates an animated GIF showing how the sequence looks on the LED matrix.
                        This allows you to test and preview sequences before activating them on real LEDs.

                        Requirements:
                        - Only JavaScript sequences can be previewed (custom or built-in JS)
                        - ImageMagick or ffmpeg must be installed on the system
                        - Install with: brew install imagemagick (macOS) or apt install imagemagick (Linux)

                        Returns:
                        - gifPath: Path to the generated GIF file
                        - gifBase64: Base64 encoded GIF data (for direct display)
                        - frameCount: Number of frames captured
                        """,
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object([
                                "type": .string("string"),
                                "description": .string("Name of the sequence to preview"),
                            ]),
                            "maxFrames": .object([
                                "type": .string("integer"),
                                "description": .string("Maximum number of frames to capture (default: 60)"),
                            ]),
                            "frameDelay": .object([
                                "type": .string("integer"),
                                "description": .string("Delay between frames in milliseconds (default: 33 = ~30fps)"),
                            ])
                        ]),
                        "required": .array([.string("name")]),
                    ])
                ),
            ]
            return .init(tools: tools)
        }
    }

    @Sendable
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

        case .createSequence:
            guard let nameValue = params.arguments?["name"],
                  case .string(let name) = nameValue,
                  let descValue = params.arguments?["description"],
                  case .string(let description) = descValue,
                  let codeValue = params.arguments?["jsCode"],
                  case .string(let jsCode) = codeValue
            else {
                return .init(
                    content: [.text("❌ Missing required parameters: name, description, or jsCode")],
                    isError: true
                )
            }

            return .init(
                content: [.text(createSequenceHandler(name: name, description: description, jsCode: jsCode))],
                isError: false
            )

        case .updateSequence:
            guard let nameValue = params.arguments?["name"],
                  case .string(let name) = nameValue,
                  let codeValue = params.arguments?["jsCode"],
                  case .string(let jsCode) = codeValue
            else {
                return .init(
                    content: [.text("❌ Missing required parameters: name or jsCode")],
                    isError: true
                )
            }

            // Description is optional for updates
            var description: String? = nil
            if let descValue = params.arguments?["description"],
               case .string(let desc) = descValue,
               !desc.isEmpty {
                description = desc
            }

            return .init(
                content: [.text(updateSequenceHandler(name: name, description: description, jsCode: jsCode))],
                isError: false
            )

        case .getStatus:
            return .init(
                content: [.text(getStatusHandler())],
                isError: false
            )

        case .getSequenceCode:
            guard let nameValue = params.arguments?["name"],
                  case .string(let name) = nameValue
            else {
                return .init(
                    content: [.text("❌ Missing required parameter: name")],
                    isError: true
                )
            }

            return .init(
                content: [.text(getSequenceCodeHandler(name: name))],
                isError: false
            )

        case .previewSequence:
            guard let nameValue = params.arguments?["name"],
                  case .string(let name) = nameValue
            else {
                return .init(
                    content: [.text("❌ Missing required parameter: name")],
                    isError: true
                )
            }

            var maxFrames = 60
            if let maxFramesValue = params.arguments?["maxFrames"],
               case .int(let frames) = maxFramesValue {
                maxFrames = frames
            }

            var frameDelay = 33  // ~30 fps
            if let frameDelayValue = params.arguments?["frameDelay"],
               case .int(let delay) = frameDelayValue {
                frameDelay = delay
            }

            return .init(
                content: [.text(previewSequenceHandler(name: name, maxFrames: maxFrames, frameDelay: frameDelay))],
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

    private static func createSequenceHandler(name: String, description: String, jsCode: String) -> String {
        do {
            let request = RequestCommand(
                cmd: .createSequence,
                sequenceName: name,
                sequenceDescription: description,
                jsCode: jsCode
            )
            let response: CreateSequenceResponse = try sendCommand(request, decodeTo: CreateSequenceResponse.self)

            if let error = response.error {
                return "❌ Failed to create sequence: \(error)"
            }

            return "✅ Sequence '\(response.sequenceName ?? name)' created successfully! Use runSequences to start it."
        } catch {
            return "❌ Error creating sequence: \(error.localizedDescription)"
        }
    }

    private static func updateSequenceHandler(name: String, description: String?, jsCode: String) -> String {
        do {
            let request = RequestCommand(
                cmd: .updateSequence,
                sequenceName: name,
                sequenceDescription: description,
                jsCode: jsCode
            )
            let response: CreateSequenceResponse = try sendCommand(request, decodeTo: CreateSequenceResponse.self)

            if let error = response.error {
                return "❌ Failed to update sequence: \(error)"
            }

            return "✅ Sequence '\(response.sequenceName ?? name)' updated successfully!"
        } catch {
            return "❌ Error updating sequence: \(error.localizedDescription)"
        }
    }

    private static func getStatusHandler() -> String {
        do {
            let request = RequestCommand(cmd: .getStatus)
            let response: StatusResponse = try sendCommand(request, decodeTo: StatusResponse.self)

            let activeList = response.activeSequences.isEmpty
                ? "None"
                : response.activeSequences.joined(separator: ", ")

            return """
                🎄 Julelys Manager Status

                Running: \(response.isRunning ? "Yes" : "No")
                Mode: \(response.mode)
                Matrix: \(response.matrixWidth) x \(response.matrixHeight) (\(response.matrixWidth * response.matrixHeight) LEDs)

                Active sequences: \(activeList)
                Available sequences: \(response.availableSequencesCount)
                """
        } catch {
            return "❌ Error getting status: \(error.localizedDescription)\n\nIs JulelysManager running?"
        }
    }

    private static func getSequenceCodeHandler(name: String) -> String {
        do {
            let request = RequestCommand(cmd: .getSequenceCode, sequenceName: name)
            let response: SequenceCodeResponse = try sendCommand(request, decodeTo: SequenceCodeResponse.self)

            if let error = response.error {
                return "❌ \(error)"
            }

            guard let jsCode = response.jsCode else {
                return "❌ No code available for '\(name)'"
            }

            return """
                📄 Sequence: \(response.name)
                📝 Description: \(response.description)
                🏷️ Type: \(response.isCustom ? "Custom (JS)" : "Built-in")

                ```javascript
                \(jsCode)
                ```
                """
        } catch {
            return "❌ Error getting sequence code: \(error.localizedDescription)"
        }
    }

    private static func previewSequenceHandler(name: String, maxFrames: Int, frameDelay: Int) -> String {
        do {
            let request = RequestCommand(
                cmd: .previewSequence,
                sequenceName: name,
                maxFrames: maxFrames,
                frameDelay: frameDelay
            )
            let response: PreviewResponse = try sendCommand(request, decodeTo: PreviewResponse.self)

            if let error = response.error {
                return "❌ \(error)"
            }

            if response.success {
                var result = """
                    🎬 Preview Generated for '\(response.sequenceName)'

                    📊 Frames captured: \(response.frameCount)
                    """

                if let gifPath = response.gifPath {
                    result += "\n📁 GIF saved to: \(gifPath)"
                }

                if let base64 = response.gifBase64 {
                    // Return the base64 data for clients that can display it
                    result += "\n\n📎 GIF Data (base64): data:image/gif;base64,\(base64.prefix(100))..."
                    result += "\n\n💡 Tip: Copy the full gifBase64 value and paste into a browser or use a base64 decoder to view the animation."
                }

                return result
            } else {
                return "❌ Preview failed: \(response.error ?? "Unknown error")"
            }
        } catch {
            return "❌ Error generating preview: \(error.localizedDescription)"
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
        #if os(Linux)
        let sock = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        #endif
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

        // 4️⃣ Læs svar - læs alt data indtil socket lukkes
        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 65536) // 64KB buffer

        while true {
            let bytesRead = read(sock, &buffer, buffer.count)
            if bytesRead <= 0 {
                break
            }
            responseData.append(contentsOf: buffer[0..<bytesRead])
        }
        close(sock)

        guard !responseData.isEmpty else {
            throw SocketError.operationFailed("no data received")
        }

        // 5️⃣ Decode svar til model
        do {
            let decoded = try JSONDecoder().decode(T.self, from: responseData)
            return decoded
        } catch {
            let raw = String(decoding: responseData.prefix(500), as: UTF8.self)
            throw SocketError.decodeFailed(
                "decode error: \(error.localizedDescription)\nResponse (first 500 chars): \(raw)"
            )
        }
    }
}
