import Foundation

#if os(OSX)
import Cocoa
import CoreGraphics

class WindowController: NSWindowController, LedControllerProtocol {
    var matrixHeight: Int
    let matrixWidth: Int
    let ledSize: CGFloat = 10
    let margen: CGFloat = 10
    let contentView: LEDView
    
    private(set) var sequences: [SequenceType]

    var applicationDelegate: ApplicationDelegate?

    init(sequences: [SequenceType], matrixWidth: Int, matrixHeight: Int) {
        self.matrixHeight = matrixHeight
        self.matrixWidth = matrixWidth
        self.sequences = sequences

        let numberOfLedOnRow = matrixHeight
        let mask: NSWindow.StyleMask = [.titled, .closable]
        let addMargen = (margen * 2)
        let rect: NSRect = .init(x: 0, y: 0, width: CGFloat(numberOfLedOnRow) * ledSize + addMargen, height: CGFloat(matrixWidth) * ledSize + addMargen)
        let window = NSWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
        window.title = "SequenceWS281x"

        self.contentView = LEDView()

        super.init(window: window)

        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        window?.contentView = contentView
        contentView.setup(matrixWidth: matrixWidth, matrixHeight: matrixHeight, size: ledSize, margen: margen)

        for var sequence in sequences {
            sequence.delegate = self
        }
    }

    func start() {
        windowFrameAutosaveName = "position"
        window?.makeKeyAndOrderFront(self)

        let application = NSApplication.shared
        application.setActivationPolicy(NSApplication.ActivationPolicy.regular)

        let applicationDelegate = ApplicationDelegate(controller: self)
        application.delegate = applicationDelegate
        application.activate(ignoringOtherApps: true)
        application.run()

        showWindow(application)
    }
    
    func update(_ sequences: [SequenceType]) {
        self.sequences = sequences
        
        for var sequence in sequences {
            sequence.delegate = self
        }
    }

    func runSequences() {
        for sequence in sequences {
            sequence.runSequence()
        }
    }

    private func updatePixels() {
        DispatchQueue.main.async {
            self.contentView.setNeedsDisplay(self.contentView.frame)
        }
        
        sleep(forTimeInterval: 0.02)
    }

    private func setPixelColor(point: Point, color: Color) {
        DispatchQueue.main.async {
            self.contentView.setPixelColor(point: point, color: color)
        }
    }

    private func setPixelColor(pos: Int, color: Color) {
        let point = fromPostionToPoint(pos)
        setPixelColor(point: point, color: color)
    }
}

extension WindowController: SequenceDelegate {
    func sequenceUpdatePixels(_ sequence: SequenceType) {
        updatePixels()
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, point: Point, color: Color) {
        setPixelColor(point: point, color: color)
    }

    func sequenceSetPixelColor(_ sequence: SequenceType, pos: Int, color: Color) {
        setPixelColor(pos: pos, color: color)
    }
}

class LEDView: NSView {
    var leds: [Point: CAShapeLayer] = [:]
    var colors: [Color] = []

    func setup(matrixWidth: Int, matrixHeight: Int, size: CGFloat, margen: CGFloat) {
        let mainlayer = CALayer()
        mainlayer.frame = self.bounds

        for y in 0..<matrixWidth {
            for x in 0..<matrixHeight {
                let point: Point = .init(x: x, y: y)
                let frame: CGRect = .init(x: point.cgPoint.x * size + margen, y: point.cgPoint.y * size + margen, width: size, height: size)

                let layer = CAShapeLayer()
                layer.path = CGPath(ellipseIn: frame, transform: nil)
                layer.fillColor = NSColor.blue.cgColor
                mainlayer.addSublayer(layer)
                leds[point] = layer
            }
        }

        self.layer = mainlayer
    }

    func setPixelColor(point: Point, color: Color) {
        leds[point]?.fillColor = color.cgColor
    }
}

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var controller: LedControllerProtocol
    var stop = false

    init(controller: LedControllerProtocol) {
        self.controller = controller
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        DispatchQueue.global().async {
            while self.stop == false {
                self.controller.runSequences()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Color {
    var cgColor: CGColor {
        return CGColor(
            red: CGFloat(red | white) / 255,
            green: CGFloat(green | white) / 255,
            blue: CGFloat(blue | white) / 255,
            alpha: 1.0
        )
    }
}

extension Point {
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

#else

class WindowController: ConsoleController {}

#endif
