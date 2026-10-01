import Foundation

public struct UsageMeterPresentation: Equatable, Sendable {
    public let usedFraction: Double?
    public let elapsedFraction: Double?
    public let resetText: String
    public let remainingText: String

    public init(window: UsageWindow?, numericCountdown: Bool, now: Date, dayCountdown: Bool = false) {
        if let used = window?.usedPercent, used.isFinite {
            usedFraction = min(1, max(0, used / 100))
            remainingText = "剩余 \(UsageFormatter.percent(100 - min(100, max(0, used))))"
        } else {
            usedFraction = nil
            remainingText = "剩余 --"
        }

        if let reset = window?.resetsAt,
           let minutes = window?.windowMinutes, minutes > 0 {
            let remaining = reset.timeIntervalSince(now)
            elapsedFraction = remaining.isFinite ? min(1, max(0, 1 - remaining / (Double(minutes) * 60))) : nil
        } else {
            elapsedFraction = nil
        }

        guard let reset = window?.resetsAt else {
            resetText = "重置时间 --"
            return
        }
        let remaining = reset.timeIntervalSince(now)
        guard remaining.isFinite, remaining < Double(Int.max) else {
            resetText = "重置时间 --"
            return
        }
        let seconds = Int(numericCountdown && dayCountdown ? floor(max(0, remaining)) : ceil(max(0, remaining)))
        if numericCountdown {
            if dayCountdown {
                resetText = String(format: "%ld:%02ld:%02ld", seconds / 86400, (seconds % 86400) / 3600, (seconds % 3600) / 60)
            } else {
                resetText = String(format: "%ld:%02ld:%02ld", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
            }
        } else if seconds == 0 {
            resetText = "即将重置"
        } else if seconds < 60 {
            resetText = "\(seconds)秒后重置"
        } else if seconds < 3600 {
            resetText = "\(seconds / 60)分后重置"
        } else if seconds < 86400 {
            let hours = seconds / 3600, minutes = (seconds % 3600) / 60
            resetText = "\(hours)小时" + (minutes > 0 ? "\(minutes)分" : "") + "后重置"
        } else {
            let days = seconds / 86400, hours = (seconds % 86400) / 3600
            resetText = "\(days)天" + (hours > 0 ? "\(hours)小时" : "") + "后重置"
        }
    }
}
