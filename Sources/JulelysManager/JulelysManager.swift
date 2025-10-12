import ArgumentParser
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
        print("\u{1B}[2J")
        print("\u{1B}[\(1);\(0)HLED will start:")

        let sequences: [SequenceType] = [
//            JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsFile: "test.js"),
//            JSSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, jsFile: "rainbow.js"),
//            TestColorSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight),
            TwistSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight),
            FireworksSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.pink, .green, .blue, .red, .yallow, .trueWhite, .purple, .magenta, .orange]),
//
//            TwistSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight),
//            
//            StarSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, color: .trueWhite),
//            MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.green], numberOfmatrixs: 150),
//            MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.green, .green, .red, .green, .green, .trueWhite, .yallow], numberOfmatrixs: 200),
//            MatrixSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, colors: [.red, .red, .red, .red, .trueWhite], numberOfmatrixs: 200),
//            RainbowCycleSequence(matrixWidth: matrixWidth, matrixHeight: matrixHeight, iterations: 5)
        ]

        let executesMode: Mode = .mode(mode)

        let controller: LedControllerProtocol

        switch executesMode {
        case .real:
            controller = SPIBasedLedController(sequences: sequences, matrixWidth: matrixWidth, matrixHeight: matrixHeight)
        case .app:
            controller = WindowController(sequences: sequences, matrixWidth: matrixWidth, matrixHeight: matrixHeight)
        case .console:
            return
            //controller = ConsoleController(sequences: sequences, matrixWidth: matrixWidth, matrixHeight: matrixHeight)
        }

        controller.start()
    }
}
