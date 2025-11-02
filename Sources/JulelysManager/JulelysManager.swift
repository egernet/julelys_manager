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
        
        let sequences = loadAllSequence()
        var activeSequences = [SequenceData]()

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
                sequences: [JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsFile: "test.js")],
                matrixWidth: matrixWidth,
                matrixHeight: matrixHeight
            )
        case .console:
            return
        //controller = ConsoleController(sequences: sequences, matrixWidth: matrixWidth, matrixHeight: matrixHeight)
        }
        
        Task {
            await startDaemon(allSequences: {
                sequences.map({ $0.info })
            }, runSequences: { names in
                activeSequences = sequences.filter { names.contains($0.info.name) }
                controller.update(activeSequences.map { $0.sequence })
            })
        }
        
        controller.start()
    }
    
    func startDaemon(allSequences: @escaping () -> [SequenceInfo], runSequences: @escaping ([String]) -> Void = { _ in }) async {
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
                    let resp = ["power": "true", "activeSequence": "Rainbow"]
                    return resp

                case .runSequences:
                    guard let names = inquiry.names else {
                        return RunSequencesResponse(status: "not running")
                    }
                    
                    runSequences(names)
                    
                    return RunSequencesResponse(status: "running")
                }
            }
        } catch {
            print(error)
        }
    }
    
    func loadAllSequence() -> [SequenceData] {
        let sequences: [SequenceData] = [
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
                sequence: MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.green, .green, .red, .green, .green, .trueWhite, .yallow], numberOfmatrixs: 200),
            ),
            .init(
                id: "Dannebrog",
                name: "Dannebrog",
                description: "The Matrix with Dannebrog colors",
                sequence: MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.red, .red, .red, .red, .trueWhite], numberOfmatrixs: 200),
            )
        ]
        
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
