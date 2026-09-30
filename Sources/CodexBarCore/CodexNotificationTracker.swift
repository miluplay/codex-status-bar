import Foundation

/// Tracks observed transitions only; missing sessions and failed reads are not completions.
public struct CodexNotificationTracker {
    public enum Kind: Equatable, Sendable { case completed, input, approval }
    public struct Event: Equatable, Sendable {
        public let sessionID: String
        public let project: String
        public let kind: Kind
    }
    private var previous: [String: CodexSession]?

    public init() {}

    public mutating func update(_ snapshot: CodexSnapshot) -> [Event] {
        guard snapshot.lastError == nil else { return [] }
        let current = Dictionary(snapshot.sessions.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        defer { previous = current }
        guard let previous else { return [] }
        return snapshot.sessions.compactMap { session in
            guard let old = previous[session.id] else { return nil }
            let kind: Kind
            if let completed = session.completedAt, completed > (old.completedAt ?? .distantPast), completed > (old.lastEventAt ?? .distantPast) {
                kind = .completed
            } else if session.isActive, let waiting = Self.waitingKind(session), waiting != Self.waitingKind(old) {
                kind = waiting
            } else {
                return nil
            }
            return Event(sessionID: session.id, project: URL(fileURLWithPath: session.cwd).lastPathComponent, kind: kind)
        }
    }

    private static func waitingKind(_ session: CodexSession) -> Kind? {
        guard session.isActive, let label = session.statusLabel else { return nil }
        if CodexBarPresentation.isApprovalLabel(label) { return .approval }
        if CodexBarPresentation.isUserInputLabel(label) { return .input }
        return nil
    }
}
