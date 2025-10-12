import Foundation

protocol LedControllerProtocol {
    /// Get the width of  the matrix
    var matrixWidth: Int { get }
    
    /// Get the height of  the matrix
    var matrixHeight: Int { get }
    
    /// Get list of sequence
    var sequences: [SequenceType] { get }

    /// Start up the controller
    func start()
    
    /// Begin run the sequences
    func runSequence()
}

extension LedControllerProtocol {
    func fromPostionToPoint(_ pos: Int) -> Point {
        let y = pos / matrixHeight
        let x = pos - (y * matrixHeight)

        return .init(x: x, y: y)
    }

    func sleep(forTimeInterval: TimeInterval = 0.01) {
        Thread.sleep(forTimeInterval: forTimeInterval)
    }
}
