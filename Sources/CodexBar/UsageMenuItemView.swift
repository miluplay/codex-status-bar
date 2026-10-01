import AppKit
import CodexBarCore

final class UsageMenuItemView: NSView {
    private let primaryRow: UsageMeterRowView
    private let weeklyRow: UsageMeterRowView

    override var isFlipped: Bool { true }

    init(width: CGFloat, usage: UsageSnapshot?, numericCountdown: Bool, now: Date, showPrimary: Bool = true, showWeekly: Bool = true) {
        primaryRow = UsageMeterRowView(label: "5H", width: width)
        weeklyRow = UsageMeterRowView(label: "7D", width: width)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: CGFloat((showPrimary ? 55 : 0) + (showWeekly ? 55 : 0) + 4)))
        primaryRow.frame.origin.y = 4
        weeklyRow.frame.origin.y = showPrimary ? 59 : 4
        if showPrimary { addSubview(primaryRow) }
        if showWeekly { addSubview(weeklyRow) }
        update(usage: usage, numericCountdown: numericCountdown, now: now)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(usage: UsageSnapshot?, numericCountdown: Bool, now: Date) {
        let projected = usage?.projected(at: now)
        primaryRow.update(window: projected?.primary, numericCountdown: numericCountdown, now: now)
        weeklyRow.update(window: projected?.secondary, numericCountdown: numericCountdown, now: now)
    }
}

private final class UsageMeterRowView: NSView {
    private let period: String
    private let periodLabel = NSTextField(labelWithString: "")
    private let resetLabel = NSTextField(labelWithString: "")
    private let remainingLabel = NSTextField(labelWithString: "")
    private var presentation: UsageMeterPresentation?
    private var trackRect: NSRect { NSRect(x: 52, y: 19, width: bounds.width - 66, height: 4) }

    override var isFlipped: Bool { true }

    init(label: String, width: CGFloat) {
        period = label
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 55))
        periodLabel.stringValue = label
        periodLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        periodLabel.textColor = .secondaryLabelColor
        periodLabel.frame = NSRect(x: 14, y: 12, width: 26, height: 17)
        resetLabel.textColor = .secondaryLabelColor
        resetLabel.frame = NSRect(x: 52, y: 32, width: width - 162, height: 17)
        resetLabel.lineBreakMode = .byTruncatingTail
        remainingLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        remainingLabel.textColor = .labelColor
        remainingLabel.alignment = .right
        remainingLabel.frame = NSRect(x: width - 106, y: 32, width: 92, height: 17)
        [periodLabel, resetLabel, remainingLabel].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(window: UsageWindow?, numericCountdown: Bool, now: Date) {
        let next = UsageMeterPresentation(window: window, numericCountdown: numericCountdown, now: now, dayCountdown: period == "7D")
        guard next != presentation else { return }
        presentation = next
        resetLabel.font = numericCountdown ? .monospacedDigitSystemFont(ofSize: 11, weight: .regular) : .systemFont(ofSize: 11)
        resetLabel.stringValue = next.resetText
        remainingLabel.stringValue = next.remainingText
        let progress = next.elapsedFraction.map { "周期已过 \(UsageFormatter.percent($0 * 100))" } ?? "时间进度暂无数据"
        let accessibilitySummary = "\(period)：\(next.resetText)，\(next.remainingText)。灰色为已用额度，蓝色游标为时间进度。\(progress)"
        setAccessibilityLabel(accessibilitySummary)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let track = trackRect
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()
        if let used = presentation?.usedFraction, used > 0 {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).addClip()
            NSColor.secondaryLabelColor.setFill()
            NSBezierPath(rect: NSRect(x: track.minX, y: track.minY, width: track.width * used, height: track.height)).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        if let elapsed = presentation?.elapsedFraction {
            let x = min(track.maxX - 1, max(track.minX + 1, track.minX + track.width * elapsed))
            NSColor.systemBlue.setFill()
            NSBezierPath(roundedRect: NSRect(x: x - 1, y: track.minY - 4, width: 2, height: 12), xRadius: 1, yRadius: 1).fill()
        }
    }
}
