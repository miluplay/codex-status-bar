import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct CodexBarPresentationTests {
    @Test func pinnedUsageStaysVisibleDuringWorkAndWithoutStatusText() {
        let now = date("2026-06-24T20:01:05.000Z")
        for label in ["Thinking...", "Waiting for approval", "Waiting for input"] {
            let snapshot = CodexSnapshot(activeAgents: [activeAgent(label: label, startedAt: now, lastEventAt: now)], usage: usage(primaryUsed: 36, secondaryUsed: 76), generatedAt: now, lastError: nil)
            let compact = CodexBarPresentation.displayState(snapshot: snapshot, options: CodexBarDisplayOptions(showStatusText: false, fiveHourUsageVisibility: .always, weeklyUsageVisibility: .idle), now: now)
            #expect(compact.title == "5H 64%")
            let expanded = CodexBarPresentation.displayState(snapshot: snapshot, options: CodexBarDisplayOptions(fiveHourUsageVisibility: .hidden, weeklyUsageVisibility: .always), now: now)
            #expect(expanded.title.hasPrefix("7D 24% · "))
            #expect(compact.animatesIcon == expanded.animatesIcon)
            #expect(compact.statusDot == expanded.statusDot)
        }
    }

    @Test func bothPinnedWindowsAndHiddenWindowsWorkWithoutStatusText() {
        let snapshot = CodexSnapshot(activeAgents: [], usage: usage(primaryUsed: 36, secondaryUsed: 76), generatedAt: Date(), lastError: nil)
        let both = CodexBarPresentation.displayState(snapshot: snapshot, options: CodexBarDisplayOptions(showStatusText: false, fiveHourUsageVisibility: .always, weeklyUsageVisibility: .always), now: snapshot.generatedAt)
        #expect(both.title == "5H 64% 7D 24%")
        let hidden = CodexBarPresentation.displayState(snapshot: snapshot, options: CodexBarDisplayOptions(showStatusText: false, fiveHourUsageVisibility: .hidden, weeklyUsageVisibility: .idle), now: snapshot.generatedAt)
        #expect(hidden.title.isEmpty)
    }

    @Test
    func idleDisplayShowsConfiguredUsageWindows() {
        let snapshot = CodexSnapshot(
            activeAgents: [],
            usage: usage(primaryUsed: 12, secondaryUsed: 46),
            generatedAt: date("2026-06-24T20:00:00.000Z"),
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: CodexBarDisplayOptions(showTimer: true, showFiveHourUsage: true, showWeeklyUsage: true),
            now: snapshot.generatedAt
        )

        #expect(state.title == "5H 88% 7D 54%")
        #expect(state.animatesIcon == false)
    }

    @Test
    func idleDisplayFallsBackToIdleWhenUsageWindowsAreHidden() {
        let snapshot = CodexSnapshot.empty(now: date("2026-06-24T20:00:00.000Z"))

        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: CodexBarDisplayOptions(showTimer: true, showFiveHourUsage: false, showWeeklyUsage: false),
            now: snapshot.generatedAt
        )

        #expect(state.title == "Idle")
        #expect(state.animatesIcon == false)
    }

    @Test
    func idleDisplayShowsUnavailableUsagePlaceholders() {
        let snapshot = CodexSnapshot.empty(now: date("2026-06-24T20:00:00.000Z"))

        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: CodexBarDisplayOptions(showTimer: true, showFiveHourUsage: true, showWeeklyUsage: true),
            now: snapshot.generatedAt
        )

        #expect(state.title == "5H -- 7D --")
        #expect(state.animatesIcon == false)
    }

    @Test
    func singleActiveAgentShowsShortStatusTimerAndAnimation() {
        let now = date("2026-06-24T20:01:05.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(label: "Running command", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "Running command 1m 5s")
        #expect(state.animatesIcon == true)
    }

    @Test
    func approvalAgentShowsDotAndDoesNotAnimate() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(label: "Waiting for approval", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "Awaiting approval 2m 0s")
        #expect(state.animatesIcon == false)
        #expect(state.statusDot == .approval)
    }

    @Test
    func waitingForInputDoesNotShowAsApproval() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(label: "Waiting for input", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "Waiting for input 2m 0s")
        #expect(state.animatesIcon == false)
        #expect(state.statusDot == nil)
    }

    @Test
    func needsInputAliasShowsAsWaitingForInput() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(label: "Needs input", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "Waiting for input 2m 0s")
        #expect(state.animatesIcon == false)
        #expect(state.statusDot == nil)
    }

    @Test
    func approvalStatusTakesPriorityOverMultipleAgentCount() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(id: "one", label: "Waiting for approval", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
                activeAgent(id: "two", label: "Running command", startedAt: date("2026-06-24T20:01:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "Awaiting approval 2m 0s")
        #expect(state.animatesIcon == true)
        #expect(state.statusDot == .approval)
    }

    @Test
    func multipleWaitingInputAgentsDoNotAnimateAsRunning() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(id: "one", label: "Waiting for input", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
                activeAgent(id: "two", label: "Waiting for input", startedAt: date("2026-06-24T20:01:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "2 waiting 1m 0s")
        #expect(state.animatesIcon == false)
        #expect(state.statusDot == nil)
    }

    @Test
    func multipleActiveAgentsShowCountAndNewestTimer() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(id: "one", label: "Editing", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
                activeAgent(id: "two", label: "Running command", startedAt: date("2026-06-24T20:01:00.000Z"), lastEventAt: now),
                activeAgent(id: "three", label: "Searching web", startedAt: date("2026-06-24T20:01:30.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "3 agents running 30s")
        #expect(state.animatesIcon == true)
        #expect(state.statusDot == nil)
    }

    @Test
    func activeTimerCanBeHidden() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [
                activeAgent(id: "one", label: "Editing", startedAt: date("2026-06-24T20:00:00.000Z"), lastEventAt: now),
                activeAgent(id: "two", label: "Running command", startedAt: date("2026-06-24T20:01:00.000Z"), lastEventAt: now),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: CodexBarDisplayOptions(showTimer: false),
            now: now
        )

        #expect(state.title == "2 agents running")
        #expect(state.animatesIcon == true)
    }

    @Test
    func idleDisplayKeepsUsageBeforeUnreadCount() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(id: "unread-1", title: "unread", client: .app, activeStartedAt: nil, isUnread: true),
                session(id: "read-idle", title: "read", client: .app, activeStartedAt: nil, isUnread: false),
            ],
            usage: usage(primaryUsed: 12, secondaryUsed: 46),
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(snapshot: snapshot, now: now)

        #expect(state.title == "5H 88% 7D 54% · 1 unread")
        #expect(state.animatesIcon == false)
        #expect(state.statusDot == .unread)
    }

    @Test
    func idleUnreadDisplayCanHideUsage() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(id: "unread-1", title: "unread", client: .app, activeStartedAt: nil, isUnread: true),
                session(id: "unread-2", title: "unread 2", client: .cli, activeStartedAt: nil, isUnread: true),
            ],
            usage: usage(primaryUsed: 12, secondaryUsed: 46),
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: CodexBarDisplayOptions(showFiveHourUsage: false, showWeeklyUsage: false),
            now: now
        )

        #expect(state.title == "2 unread")
        #expect(state.animatesIcon == false)
        #expect(state.statusDot == .unread)
    }

    @Test
    func sessionRowsIncludeOnlyActiveOrUnreadSessionsUpToLimit() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(id: "active-1", title: "active", client: .app, activeStartedAt: date("2026-06-24T20:00:00.000Z"), isUnread: false),
                session(id: "read-idle", title: "read", client: .app, activeStartedAt: nil, isUnread: false),
                session(id: "unread-1", title: "unread", client: .ide, activeStartedAt: nil, isUnread: true),
                session(id: "active-2", title: "active 2", client: .cli, activeStartedAt: date("2026-06-24T20:01:00.000Z"), isUnread: false),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let rows = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 2)

        #expect(rows.map(\.id) == ["active-1", "unread-1"])
        #expect(rows.map(\.clientBadge) == ["APP", "IDE"] as [String?])
    }

    @Test
    func sessionRowsFallBackToRecentSessionsWhenUnreadStateIsUnavailable() {
        let now = date("2026-06-24T20:02:00.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(id: "recent-1", title: "recent 1", client: .app, activeStartedAt: nil, isUnread: false),
                session(id: "recent-2", title: "recent 2", client: .app, activeStartedAt: nil, isUnread: false),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let rows = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 6)

        #expect(rows.map(\.id) == ["recent-1", "recent-2"])
    }

    @Test
    func sessionRowsExposeElapsedTimeTooltipAndAppDeepLink() {
        let now = date("2026-06-24T21:02:05.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(
                    id: "019f08b4-91be-7091-bdb3-c92e769787e4",
                    title: "codex-bar",
                    client: .app,
                    activeStartedAt: date("2026-06-24T20:00:00.000Z"),
                    statusLabel: "Running command",
                    isUnread: false
                ),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let row = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 6).first

        #expect(row?.title == "codex-bar")
        #expect(row?.clientBadge == "APP")
        #expect(row?.timeText == "1h 2m")
        #expect(row?.statusTooltip == "Running command")
        #expect(row?.isActive == true)
        #expect(row?.isUnread == false)
        #expect(row?.threadURL?.absoluteString == "codex://threads/019f08b4-91be-7091-bdb3-c92e769787e4")
    }

    @Test
    func subagentRowsAreHiddenFromTheMenu() {
        let now = date("2026-06-24T21:02:05.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                CodexSession(
                    id: "child-thread",
                    title: "Explore implementation",
                    rolloutPath: "/tmp/child-thread.jsonl",
                    cwd: "/tmp/project",
                    client: .cli,
                    isSubagent: true,
                    agentRole: "explorer",
                    updatedAt: now,
                    activeStartedAt: nil,
                    lastEventAt: now,
                    statusLabel: nil,
                    isUnread: true
                )
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let rows = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 6)

        #expect(rows.isEmpty)
    }

    @Test
    func subagentsAreHiddenAndCountedOnTheirParent() {
        let now = date("2026-06-24T21:02:05.000Z")
        let parent = session(
            id: "parent-thread",
            title: "主会话",
            client: .app,
            activeStartedAt: nil,
            isUnread: false
        )
        let child = CodexSession(
            id: "child-thread",
            title: "子任务",
            rolloutPath: "/tmp/child-thread.jsonl",
            cwd: "/tmp/project",
            client: .cli,
            isSubagent: true,
            parentThreadID: "parent-thread",
            agentRole: "explorer",
            updatedAt: now,
            activeStartedAt: now,
            lastEventAt: now,
            statusLabel: "Thinking",
            isUnread: false
        )
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [child, parent],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let rows = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 6)

        #expect(rows.map(\.id) == ["parent-thread"])
        #expect(rows.map(\.clientBadge) == ["APP"] as [String?])
        #expect(CodexBarPresentation.visibleMenuSessions(snapshot: snapshot, limit: 6).map(\.id) == ["parent-thread"])
        #expect(CodexBarPresentation.runningSubagentCount(snapshot: snapshot, parentID: "parent-thread") == 1)
    }

    @Test
    func sessionRowsDoNotExposeDeepLinksForCliOrIdeSessions() {
        let now = date("2026-06-24T21:02:05.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(
                    id: "cli-thread",
                    title: "cli",
                    client: .cli,
                    activeStartedAt: date("2026-06-24T20:00:00.000Z"),
                    isUnread: false
                ),
                session(
                    id: "ide-thread",
                    title: "ide",
                    client: .ide,
                    activeStartedAt: nil,
                    isUnread: true
                ),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let rows = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 6)

        #expect(rows.map(\.clientBadge) == ["CLI", "IDE"] as [String?])
        #expect(rows.map(\.threadURL) == [nil, nil])
    }

    @Test
    func sessionRowsOmitUnknownClientBadges() {
        let now = date("2026-06-24T21:02:05.000Z")
        let snapshot = CodexSnapshot(
            activeAgents: [],
            sessions: [
                session(
                    id: "unknown-thread",
                    title: "unknown",
                    client: nil,
                    activeStartedAt: date("2026-06-24T20:00:00.000Z"),
                    isUnread: false
                ),
            ],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let row = CodexBarPresentation.sessionRows(snapshot: snapshot, limit: 6).first

        #expect(row?.clientBadge == nil)
        #expect(row?.threadURL == nil)
    }

    @Test
    func shortStatusLabelsMatchMenuBarCopy() {
        #expect(CodexBarPresentation.shortStatusLabel("Thinking...") == "Thinking")
        #expect(CodexBarPresentation.shortStatusLabel("Reasoning") == "Thinking")
        #expect(CodexBarPresentation.shortStatusLabel("Writing update") == "Working")
        #expect(CodexBarPresentation.shortStatusLabel("Searching web") == "Web search")
        #expect(CodexBarPresentation.shortStatusLabel("Searching tools") == "Tool search")
        #expect(CodexBarPresentation.shortStatusLabel("Viewing image") == "Viewing")
        #expect(CodexBarPresentation.shortStatusLabel("Creating image") == "Image")
        #expect(CodexBarPresentation.shortStatusLabel("Applying settings") == "Settings")
        #expect(CodexBarPresentation.shortStatusLabel("Rolling back") == "Rolling back")
        #expect(CodexBarPresentation.shortStatusLabel("Waiting for input") == "Waiting for input")
        #expect(CodexBarPresentation.shortStatusLabel("Needs input") == "Waiting for input")
        #expect(CodexBarPresentation.shortStatusLabel("  Custom\nstatus  ") == "Custom status")
    }

    @Test
    func elapsedTimeClampsFutureStartsToZero() {
        #expect(
            CodexBarPresentation.elapsedText(
                since: date("2026-06-24T20:00:05.000Z"),
                now: date("2026-06-24T20:00:00.000Z")
            ) == "0s"
        )
    }

    @Test
    func truncateCompactsWhitespaceBeforeCutting() {
        #expect(CodexBarPresentation.truncate("Data:\nreally   long   failure message", limit: 18) == "Data: really lo...")
    }

    private func usage(primaryUsed: Double, secondaryUsed: Double) -> UsageSnapshot {
        UsageSnapshot(
            primary: UsageWindow(label: "5h", usedPercent: primaryUsed, windowMinutes: 300, resetsAt: nil),
            secondary: UsageWindow(label: "week", usedPercent: secondaryUsed, windowMinutes: 10080, resetsAt: nil),
            planType: "pro",
            capturedAt: date("2026-06-24T20:00:00.000Z")
        )
    }

    private func activeAgent(
        id: String = "thread-1",
        label: String,
        startedAt: Date,
        lastEventAt: Date
    ) -> ActiveAgent {
        ActiveAgent(
            id: id,
            title: "codex-bar",
            cwd: "/tmp/codex-bar",
            label: label,
            startedAt: startedAt,
            lastEventAt: lastEventAt
        )
    }

    private func session(
        id: String,
        title: String,
        client: CodexSessionClient?,
        activeStartedAt: Date?,
        statusLabel: String? = nil,
        isUnread: Bool
    ) -> CodexSession {
        CodexSession(
            id: id,
            title: title,
            rolloutPath: "/tmp/\(id).jsonl",
            cwd: "/tmp/\(title)",
            client: client,
            updatedAt: date("2026-06-24T20:00:00.000Z"),
            activeStartedAt: activeStartedAt,
            lastEventAt: date("2026-06-24T20:01:00.000Z"),
            statusLabel: statusLabel,
            isUnread: isUnread
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }
}
