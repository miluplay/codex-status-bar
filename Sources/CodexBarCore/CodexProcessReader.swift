import Foundation

/// Reads the currently running Codex processes without depending on AppKit.
/// The command runner is injectable so parsing stays deterministic in tests.
public struct CodexProcessReader: Sendable {
    public typealias CommandRunner = @Sendable () -> String
    public typealias ProcessProvider = @Sendable () -> [CodexProcess]

    private let run: CommandRunner
    private let provider: ProcessProvider?

    public init(run: @escaping CommandRunner = CodexProcessReader.defaultCommandRunner) {
        self.run = run
        self.provider = nil
    }

    /// Allows the AppKit target to provide NSWorkspace processes when macOS
    /// denies command-line process enumeration to the app.
    public init(processes: @escaping ProcessProvider) {
        self.run = CodexProcessReader.defaultCommandRunner
        self.provider = processes
    }

    public func load() -> [CodexProcess] {
        if let provider {
            return provider().sorted { $0.pid < $1.pid }
        }
        return parse(run())
    }

    public func parse(_ output: String) -> [CodexProcess] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            // Keep the complete command as one field. `ps` emits either
            // `pid state command` or the same shape with spaces in command
            // arguments, so requiring a fourth field drops bare processes.
            let fields = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3, let pid = Int32(fields[0]) else { return nil }
            let state = String(fields[1]).first
            let command = String(fields[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard Self.isCodexCommand(command) else { return nil }
            return CodexProcess(pid: pid, command: command, status: Self.status(for: state))
        }
        .sorted { $0.pid < $1.pid }
    }

    public static func isCodexCommand(_ command: String) -> Bool {
        let value = command.lowercased()
        return value.range(of: #"(^|[ /])codex(-cli)?([ /]|$)"#, options: .regularExpression) != nil
            || value.contains("/codex.app/")
            || value.contains("codex app-server")
            || value.contains("com.openai.codex")
    }

    public static func status(for state: Character?) -> CodexProcessStatus {
        switch state {
        case "R": .running
        case "S": .sleeping
        case "T": .stopped
        case "Z": .zombie
        case "I": .idle
        default: .unknown
        }
    }

    public static func defaultCommandRunner() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,state=,command="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
