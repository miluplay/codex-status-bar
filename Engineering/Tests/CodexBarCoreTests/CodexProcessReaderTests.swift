import Foundation
import Testing
@testable import CodexBarCore

struct CodexProcessReaderTests {
    @Test
    func parsesOnlyCodexProcessesAndMapsStates() {
        let output = """
          101 R      /usr/local/bin/codex --profile default
          202 S      /Applications/Codex.app/Contents/MacOS/Codex
          303 T      /usr/bin/other-tool
          404 Z      codex app-server
        """

        let processes = CodexProcessReader().parse(output)

        #expect(processes.map(\.pid) == [101, 202, 404])
        #expect(processes.map(\.status) == [.running, .sleeping, .zombie])
    }

    @Test
    func statusTitleDoesNotUseProcessSummary() {
        let now = Date(timeIntervalSince1970: 100)
        let snapshot = CodexSnapshot(
            processes: [CodexProcess(pid: 1, command: "codex", status: .running)],
            activeAgents: [],
            usage: nil,
            generatedAt: now,
            lastError: nil
        )

        let state = CodexBarPresentation.displayState(
            snapshot: snapshot,
            options: CodexBarDisplayOptions(showFiveHourUsage: false, showWeeklyUsage: false),
            now: now
        )
        #expect(state.title == "Idle")
        #expect(!state.animatesIcon)
    }
}
