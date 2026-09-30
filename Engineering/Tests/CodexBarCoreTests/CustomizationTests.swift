import Foundation
import Testing
@testable import CodexBarCore

@Suite struct CustomizationTests {
    private let start = Date(timeIntervalSince1970: 100)
    private func session(label: String? = "Thinking...", active: Bool = true, completed: Date? = nil) -> CodexSession {
        CodexSession(id: "test", title: "Private prompt", rolloutPath: "", cwd: "/tmp/project", client: .cli,
                     updatedAt: start, activeStartedAt: active ? start : nil, lastEventAt: completed ?? start,
                     statusLabel: label, completedAt: completed)
    }
    private func snapshot(_ sessions: [CodexSession], error: String? = nil) -> CodexSnapshot {
        CodexSnapshot(activeAgents: [], sessions: sessions, usage: nil, generatedAt: start, lastError: error)
    }
    @Test func startupAndRepeatedWaitingAreSilent() {
        var tracker = CodexNotificationTracker()
        #expect(tracker.update(snapshot([session(label: "Waiting for input")])).isEmpty)
        #expect(tracker.update(snapshot([session(label: "Waiting for input")])).isEmpty)
        #expect(tracker.update(snapshot([session()])).isEmpty)
        let events = tracker.update(snapshot([session(label: "Waiting for input")]))
        #expect(events.count == 1)
        #expect(events.first?.kind == .input)
        #expect(events.first?.project == "project")
        #expect(tracker.update(snapshot([session(label: "Waiting for approval")])).first?.kind == .approval)
    }
    @Test func completionRequiresNewExplicitEvent() {
        var tracker = CodexNotificationTracker()
        #expect(tracker.update(snapshot([session()])).isEmpty)
        #expect(tracker.update(snapshot([session(active: false)])).isEmpty)
        let done = session(label: nil, active: false, completed: start.addingTimeInterval(10))
        #expect(tracker.update(snapshot([done])).first?.kind == .completed)
        #expect(tracker.update(snapshot([done])).isEmpty)
    }
    @Test func historicalCompletionIsSilentOnStartup() {
        var tracker = CodexNotificationTracker()
        let done = session(label: nil, active: false, completed: start.addingTimeInterval(10))
        #expect(tracker.update(snapshot([done])).isEmpty)
    }
    @Test func missingSessionsAndErrorsDoNotCompleteTasks() {
        var tracker = CodexNotificationTracker()
        _ = tracker.update(snapshot([session()]))
        #expect(tracker.update(snapshot([], error: "read failed")).isEmpty)
        #expect(tracker.update(snapshot([session(label: "Waiting for input")])).first?.kind == .input)
        #expect(tracker.update(snapshot([])).isEmpty)
    }
    @Test func onlySuccessfulLifecycleEventsMarkCompletion() {
        let parser = RolloutParser()
        let started = #"{"timestamp":"2026-09-30T00:00:00Z","type":"event_msg","payload":{"type":"task_started"}}"#
        let aborted = #"{"timestamp":"2026-09-30T00:01:00Z","type":"event_msg","payload":{"type":"turn_aborted"}}"#
        let done = #"{"timestamp":"2026-09-30T00:01:00Z","type":"event_msg","payload":{"type":"task_complete"}}"#
        #expect(parser.parse(lines: [started, aborted]).successfulCompletionAt == nil)
        #expect(parser.parse(lines: [started, done]).successfulCompletionAt != nil)
    }
    @Test func chineseStatusPreservesTimersAndUsage() {
        #expect(ChinesePresentation.text("Awaiting approval 2m 3s") == "等待授权 2分 3秒")
        #expect(ChinesePresentation.text("2 agents running 3m 1s") == "2 个代理运行中 3分 1秒")
        #expect(ChinesePresentation.text("Week reset: 2h 3m left") == "每周 重置：2小时 3分后")
        #expect(ChinesePresentation.text("Thinking 1h 2m") == "思考中 1小时 2分")
        #expect(ChinesePresentation.text("Open Codex") == "打开 Codex")
    }
}
