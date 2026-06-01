import Foundation

enum RecordingState: Equatable {
    case idle
    case starting(UUID)
    case recording(UUID)
    case processing(UUID)
    case cancelled(UUID)
    case error(UUID, String)

    var sessionID: UUID? {
        switch self {
        case .idle: nil
        case .starting(let id), .recording(let id), .processing(let id),
             .cancelled(let id), .error(let id, _): id
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .cancelled, .error: false
        default: true
        }
    }
}

enum RecordingEvent {
    case startRequested
    case micReady
    case stopRequested
    case refinementDone
    case cancel
    case failed(String)
    case reset
}

@MainActor
final class RecordingStateMachine {
    private(set) var state: RecordingState = .idle

    func forceReset() {
        state = .idle
    }

    @discardableResult
    func transition(_ event: RecordingEvent) -> RecordingState {
        let next: RecordingState
        switch (state, event) {
        case (.idle, .startRequested):
            next = .starting(UUID())

        case (.starting(let id), .micReady):
            next = .recording(id)

        case (.starting(let id), .stopRequested),
             (.starting(let id), .cancel),
             (.recording(let id), .cancel),
             (.processing(let id), .cancel):
            next = .cancelled(id)

        case (.starting(let id), .failed(let msg)),
             (.recording(let id), .failed(let msg)),
             (.processing(let id), .failed(let msg)):
            next = .error(id, msg)

        case (.recording(let id), .stopRequested):
            next = .processing(id)

        case (.processing, .refinementDone),
             (.cancelled, .refinementDone),
             (.cancelled, .reset),
             (.error, .reset):
            next = .idle

        default:
            return state
        }
        state = next
        return next
    }
}
