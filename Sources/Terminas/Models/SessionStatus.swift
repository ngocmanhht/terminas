import Foundation

public enum SessionStatus: Equatable, Sendable {
    case connecting
    case connected
    case terminated(exitCode: Int32?)
}
