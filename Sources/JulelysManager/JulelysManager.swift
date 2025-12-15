import ArgumentParser
import Entities
import Foundation

@main
struct JulelysManager: ParsableCommand {
    enum Mode: String {
        case real
        case app
        case console

        static func mode(_ string: String?) -> Mode {
            switch string {
            case Mode.real.rawValue:
                return .real
            case Mode.app.rawValue:
                return .app
            case Mode.console.rawValue:
                return .console
            default:
                return .real
            }
        }
    }

    static var configuration = CommandConfiguration(
        commandName: "julelysmanager",
        abstract: "Run sequence for Julelys",
        version: "0.1.0",
        subcommands: []
    )

    @Option(help: "Executes mode: [real, app, console]")
    var mode: String = "real"

    @Option(help: "Matrix width")
    var matrixWidth: Int = 8

    @Option(help: "Matrix height")
    var matrixHeight: Int = 55
    
    func run() {

        var sequences = loadAllSequence()

        // Load saved active sequences from last session
        let savedActiveNames = CustomSequenceStorage.loadActiveSequences()
        var activeSequences = sequences.filter { savedActiveNames.contains($0.info.name) }

        if !activeSequences.isEmpty {
            fputs("▶️ Resuming with \(activeSequences.count) sequence(s): \(savedActiveNames.joined(separator: ", "))\n", stderr)
        }

        print("\u{1B}[2J")
        print("\u{1B}[\(1);\(0)HLED will start:")

        let executesMode: Mode = .mode(mode)

        let controller: LedControllerProtocol

        switch executesMode {
        case .real:
            controller = SPIBasedLedController(
                sequences: activeSequences.map { $0.sequence },
                matrixWidth: matrixWidth,
                matrixHeight: matrixHeight
            )
        case .app:
            controller = WindowController(
                sequences: activeSequences.map { $0.sequence },
                matrixWidth: matrixWidth,
                matrixHeight: matrixHeight
            )
        case .console:
            controller = ConsoleController(
                sequences: activeSequences.map { $0.sequence },
                matrixWidth: matrixWidth,
                matrixHeight: matrixHeight
            )
        }

        let width = matrixWidth
        let height = matrixHeight

        Task {
            await startDaemon(
                allSequences: {
                    sequences.map({ $0.info })
                },
                runSequences: { names in
                    activeSequences = sequences.filter { names.contains($0.info.name) }
                    controller.update(activeSequences.map { $0.sequence })

                    // Save active sequences to disk
                    CustomSequenceStorage.saveActiveSequences(names)
                },
                createSequence: { name, description, jsCode in
                    // Check if sequence already exists
                    if sequences.contains(where: { $0.info.name == name }) {
                        return (false, "Sequence with name '\(name)' already exists")
                    }

                    // Save to disk
                    do {
                        let id = try CustomSequenceStorage.save(name: name, description: description, jsCode: jsCode)

                        let newSequence = SequenceData(
                            id: id,
                            name: name,
                            description: description,
                            sequence: JSSequence(matrixWidth: width, matrixHeight: height, jsCode: jsCode)
                        )
                        sequences.append(newSequence)

                        fputs("💾 Saved new sequence '\(name)' to disk\n", stderr)
                        return (true, nil)
                    } catch {
                        return (false, "Failed to save sequence: \(error.localizedDescription)")
                    }
                },
                updateSequence: { name, description, jsCode in
                    // Update on disk
                    do {
                        try CustomSequenceStorage.update(name: name, description: description, jsCode: jsCode)

                        // Update in-memory sequence list
                        if let index = sequences.firstIndex(where: { $0.info.name == name }) {
                            let oldInfo = sequences[index].info
                            let newSequence = SequenceData(
                                id: oldInfo.id,
                                name: oldInfo.name,
                                description: description ?? oldInfo.description,
                                sequence: JSSequence(matrixWidth: width, matrixHeight: height, jsCode: jsCode)
                            )
                            sequences[index] = newSequence

                            // Update active sequences if this sequence is active
                            if let activeIndex = activeSequences.firstIndex(where: { $0.info.name == name }) {
                                activeSequences[activeIndex] = newSequence
                                // Refresh the controller with updated sequences
                                controller.update(activeSequences.map { $0.sequence })
                                fputs("🔄 Refreshed active sequence '\(name)'\n", stderr)
                            }
                        }

                        fputs("✏️ Updated sequence '\(name)'\n", stderr)
                        return (true, nil)
                    } catch {
                        return (false, error.localizedDescription)
                    }
                },
                getStatus: {
                    StatusResponse(
                        isRunning: true,
                        activeSequences: activeSequences.map { $0.info.name },
                        availableSequencesCount: sequences.count,
                        matrixWidth: width,
                        matrixHeight: height,
                        mode: executesMode.rawValue
                    )
                }
            )
        }

        controller.start()
    }
    
    func startDaemon(
        allSequences: @escaping () -> [SequenceInfo],
        runSequences: @escaping ([String]) -> Void = { _ in },
        createSequence: @escaping (String, String, String) -> (success: Bool, error: String?) = { _, _, _ in (false, "Not supported") },
        updateSequence: @escaping (String, String?, String) -> (success: Bool, error: String?) = { _, _, _ in (false, "Not supported") },
        getStatus: @escaping () -> StatusResponse
    ) async {
        do {
            try await JulelysDaemon.start { inquiry in
                switch inquiry.cmd {
                case .getSequences:
                    let sequences = allSequences()
                    let all = AllSequences(sequences: sequences)
                    return all
                case .turnOn:
                    let resp = ["status": "on"]
                    return resp

                case .turnOff:
                    let resp = ["status": "off"]
                    return resp

                case .getStatus:
                    return getStatus()

                case .runSequences:
                    guard let names = inquiry.names else {
                        return RunSequencesResponse(status: "not running")
                    }

                    runSequences(names)

                    return RunSequencesResponse(status: "running")

                case .createSequence:
                    guard let name = inquiry.sequenceName,
                          let description = inquiry.sequenceDescription,
                          let jsCode = inquiry.jsCode else {
                        return CreateSequenceResponse(
                            status: "error",
                            error: "Missing required fields: sequenceName, sequenceDescription, or jsCode"
                        )
                    }

                    let result = createSequence(name, description, jsCode)

                    if result.success {
                        return CreateSequenceResponse(status: "created", sequenceName: name)
                    } else {
                        return CreateSequenceResponse(status: "error", error: result.error)
                    }

                case .updateSequence:
                    guard let name = inquiry.sequenceName,
                          let jsCode = inquiry.jsCode else {
                        return CreateSequenceResponse(
                            status: "error",
                            error: "Missing required fields: sequenceName or jsCode"
                        )
                    }

                    let result = updateSequence(name, inquiry.sequenceDescription, jsCode)

                    if result.success {
                        return CreateSequenceResponse(status: "updated", sequenceName: name)
                    } else {
                        return CreateSequenceResponse(status: "error", error: result.error)
                    }
                }
            }
        } catch {
            print(error)
        }
    }
    
    func loadAllSequence() -> [SequenceData] {
        // Built-in sequences
        var sequences: [SequenceData] = [
            .init(
                id: "Twist",
                name: "Twist",
                description: "The sequence creates an insp spiral up the flagpole, the color white.",
                sequence: TwistSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight)
            ),
            .init(
                id: "TestRed",
                name: "Test red",
                description: "This tests one link at a time on each string with red color, use elk javascript engine.",
                sequence: JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsFile: "test.js")
            ),
            .init(
                id: "TestAll",
                name: "Test Color",
                description: "This tests all four colors red green blue and white",
                sequence: TestColorSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight)
            ),
            .init(
                id: "rainbowJava",
                name: "Rainbow Javascript",
                description: "Rainbow effect, use elk javascript engine.",
                sequence: JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsFile: "rainbow.js")
            ),
            .init(
                id: "rainbowJava",
                name: "Rainbow Javascript",
                description: "Rainbow effect, use elk javascript engine.",
                sequence: JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsFile: "rainbow.js")
            ),
            .init(
                id: "rainbow",
                name: "Rainbow",
                description: "Rainbow effect",
                sequence: RainbowCycleSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, iterations: 5)
            ),
            .init(
                id: "Stars",
                name: "Stars",
                description: "Star effect, white color only",
                sequence: StarSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, color: .trueWhite)
            ),
            .init(
                id: "Fireworks",
                name: "Fireworks",
                description: "Fireworks bursting in different colors",
                sequence: FireworksSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.pink, .green, .blue, .red, .yallow, .trueWhite, .purple, .magenta, .orange])
            ),
            .init(
                id: "TheMatrix",
                name: "The Matrix",
                description: "The Matrix with true color",
                sequence: MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.green], numberOfmatrixs: 150)
            ),
            .init(
                id: "TheMatrixColors",
                name: "The Matrix with 4 colors",
                description: "The Matrix with green, red, white and yellow colors",
                sequence: MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.green, .green, .red, .green, .green, .trueWhite, .yallow], numberOfmatrixs: 200)
            ),
            .init(
                id: "Dannebrog",
                name: "Dannebrog",
                description: "The Matrix with Dannebrog colors",
                sequence: MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.red, .red, .red, .red, .trueWhite], numberOfmatrixs: 200)
            )
        ]

        // Load custom sequences from disk
        let customSequences = CustomSequenceStorage.loadAll(matrixWidth: matrixWidth, matrixHeight: matrixHeight)
        sequences.append(contentsOf: customSequences)

        fputs("🎄 Loaded \(sequences.count) sequences (\(customSequences.count) custom)\n", stderr)

        return sequences
    }
}

struct SequenceData {
    let info: SequenceInfo
    let sequence: SequenceType

    init(id: String, name: String, description: String, sequence: SequenceType) {
        self.info = .init(id: id, name: name, description: description)
        self.sequence = sequence
    }
}

struct CustomSequenceMetadata: Codable {
    let id: String
    let name: String
    let description: String
    let jsFileName: String
}

enum CustomSequenceStorage {
    static var directoryURL: URL {
        let baseURL: URL
        #if os(Linux)
        baseURL = URL(fileURLWithPath: NSHomeDirectory())
        #else
        baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        #endif
        return baseURL.appendingPathComponent("Julelys/CustomSequences")
    }

    static func ensureDirectoryExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    static func save(name: String, description: String, jsCode: String) throws -> String {
        try ensureDirectoryExists()

        let id = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let jsFileName = "\(id).js"

        let jsFileURL = directoryURL.appendingPathComponent(jsFileName)
        let metadataURL = directoryURL.appendingPathComponent("\(id).json")

        try jsCode.write(to: jsFileURL, atomically: true, encoding: .utf8)

        let metadata = CustomSequenceMetadata(
            id: id,
            name: name,
            description: description,
            jsFileName: jsFileName
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL)

        return id
    }

    static func loadAll(matrixWidth: Int, matrixHeight: Int) -> [SequenceData] {
        let fm = FileManager.default

        guard fm.fileExists(atPath: directoryURL.path) else {
            return []
        }

        var sequences: [SequenceData] = []

        do {
            let files = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let metadataFiles = files.filter { $0.pathExtension == "json" }

            for metadataURL in metadataFiles {
                do {
                    let data = try Data(contentsOf: metadataURL)
                    let metadata = try JSONDecoder().decode(CustomSequenceMetadata.self, from: data)

                    let jsFileURL = directoryURL.appendingPathComponent(metadata.jsFileName)
                    let jsCode = try String(contentsOf: jsFileURL, encoding: .utf8)

                    let sequence = SequenceData(
                        id: metadata.id,
                        name: metadata.name,
                        description: metadata.description,
                        sequence: JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsCode: jsCode)
                    )
                    sequences.append(sequence)

                    fputs("📂 Loaded custom sequence: \(metadata.name)\n", stderr)
                } catch {
                    fputs("⚠️ Failed to load sequence from \(metadataURL.lastPathComponent): \(error)\n", stderr)
                }
            }
        } catch {
            fputs("⚠️ Failed to read custom sequences directory: \(error)\n", stderr)
        }

        return sequences
    }

    static func update(name: String, description: String?, jsCode: String) throws {
        let fm = FileManager.default

        guard fm.fileExists(atPath: directoryURL.path) else {
            throw StorageError.sequenceNotFound(name)
        }

        // Find the metadata file by name
        let files = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        let metadataFiles = files.filter { $0.pathExtension == "json" }

        for metadataURL in metadataFiles {
            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(CustomSequenceMetadata.self, from: data)

            if metadata.name == name {
                // Update JS file
                let jsFileURL = directoryURL.appendingPathComponent(metadata.jsFileName)
                try jsCode.write(to: jsFileURL, atomically: true, encoding: .utf8)

                // Update metadata if description changed
                if let newDescription = description {
                    let updatedMetadata = CustomSequenceMetadata(
                        id: metadata.id,
                        name: metadata.name,
                        description: newDescription,
                        jsFileName: metadata.jsFileName
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let metadataData = try encoder.encode(updatedMetadata)
                    try metadataData.write(to: metadataURL)
                }

                return
            }
        }

        throw StorageError.sequenceNotFound(name)
    }

    enum StorageError: Error, LocalizedError {
        case sequenceNotFound(String)

        var errorDescription: String? {
            switch self {
            case .sequenceNotFound(let name):
                return "Sequence '\(name)' not found. Only custom sequences can be updated."
            }
        }
    }

    // MARK: - Active Sequences Persistence

    private static var activeSequencesFileURL: URL {
        let baseURL: URL
        #if os(Linux)
        baseURL = URL(fileURLWithPath: NSHomeDirectory())
        #else
        baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        #endif
        return baseURL.appendingPathComponent("Julelys/active_sequences.json")
    }

    static func saveActiveSequences(_ names: [String]) {
        do {
            try ensureDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(names)
            try data.write(to: activeSequencesFileURL)
            fputs("💾 Saved active sequences: \(names.joined(separator: ", "))\n", stderr)
        } catch {
            fputs("⚠️ Failed to save active sequences: \(error)\n", stderr)
        }
    }

    static func loadActiveSequences() -> [String] {
        let fm = FileManager.default

        guard fm.fileExists(atPath: activeSequencesFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: activeSequencesFileURL)
            let names = try JSONDecoder().decode([String].self, from: data)
            fputs("📂 Loaded active sequences: \(names.joined(separator: ", "))\n", stderr)
            return names
        } catch {
            fputs("⚠️ Failed to load active sequences: \(error)\n", stderr)
            return []
        }
    }
}
