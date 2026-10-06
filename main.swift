import Cocoa

// MARK: - Log store

struct DayRecord: Codable {
    var pomodoros: Int
    var focusSeconds: Int
    var emojis: [String]

    init(pomodoros: Int, focusSeconds: Int, emojis: [String] = []) {
        self.pomodoros = pomodoros
        self.focusSeconds = focusSeconds
        self.emojis = emojis
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pomodoros = try c.decode(Int.self, forKey: .pomodoros)
        focusSeconds = try c.decode(Int.self, forKey: .focusSeconds)
        emojis = try c.decodeIfPresent([String].self, forKey: .emojis)
            ?? Array(repeating: "🍅", count: pomodoros)
    }
}

final class LogStore {
    static let emojiPool = [
        "🍅", "🍋", "🍉", "🍇", "🍓", "🥑", "🌶", "🥦", "🍩", "🧁",
        "⭐", "🔥", "💎", "🎯", "🚀", "🌈", "🦄", "🐝", "🦉", "🍀",
        "🌸", "🌵", "🐙", "🦊", "🐳", "🎈", "🎨", "🏆", "⚡️", "🍄",
    ]
    let jsonURL: URL
    let mdURL: URL
    private(set) var days: [String: DayRecord] = [:]

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(directory: URL) {
        jsonURL = directory.appendingPathComponent("tomoporo-log.json")
        mdURL = directory.appendingPathComponent("tomoporo-log.md")
        if let data = try? Data(contentsOf: jsonURL),
           let decoded = try? JSONDecoder().decode([String: DayRecord].self, from: data) {
            days = decoded
        }
    }

    static func key(for date: Date = Date()) -> String { dateFmt.string(from: date) }

    func recordPomodoro(focusSeconds: Int) {
        let key = LogStore.key()
        var day = days[key] ?? DayRecord(pomodoros: 0, focusSeconds: 0)
        day.pomodoros += 1
        day.focusSeconds += focusSeconds
        day.emojis.append(LogStore.emojiPool.randomElement() ?? "🍅")
        days[key] = day
        save()
    }

    func today() -> DayRecord { days[LogStore.key()] ?? DayRecord(pomodoros: 0, focusSeconds: 0) }

    var totalPomodoros: Int { days.values.reduce(0) { $0 + $1.pomodoros } }
    var totalFocusSeconds: Int { days.values.reduce(0) { $0 + $1.focusSeconds } }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            try? data.write(to: jsonURL, options: .atomic)
        }
        try? renderMarkdown().write(to: mdURL, atomically: true, encoding: .utf8)
    }

    private func renderMarkdown() -> String {
        var out = "# 🍅 Tomoporo Log\n"
        for key in days.keys.sorted(by: >) {
            let d = days[key]!
            out += "\n## \(key)\n\(d.emojis.joined()) — \(d.pomodoros) pomodoro\(d.pomodoros == 1 ? "" : "s"), \(LogStore.fmt(duration: d.focusSeconds)) focus\n"
        }
        out += "\n---\n**All time:** \(totalPomodoros) pomodoros, \(LogStore.fmt(duration: totalFocusSeconds)) total focus\n"
        return out
    }

    static func fmt(duration seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }
}

// MARK: - Fireworks

final class Fireworks {
    private static var activeWindows: [NSWindow] = []

    static func show() {
        guard let screen = NSScreen.main else { return }
        let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        win.contentView = view

        let label = NSTextField(labelWithString: "🎉 Congratulations! Pomodoro complete! 🎉")
        label.font = NSFont.systemFont(ofSize: 42, weight: .heavy)
        label.textColor = .white
        label.alignment = .center
        label.shadow = {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.8)
            s.shadowBlurRadius = 8
            s.shadowOffset = NSSize(width: 0, height: -2)
            return s
        }()
        label.sizeToFit()
        label.frame.origin = NSPoint(
            x: (screen.frame.width - label.frame.width) / 2,
            y: screen.frame.height * 0.55
        )
        view.addSubview(label)
        label.alphaValue = 0

        win.orderFrontRegardless()
        activeWindows.append(win)

        guard let layer = view.layer, let dot = makeDotImage() else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            label.animator().alphaValue = 1
        }

        let size = screen.frame.size
        for i in 0..<9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                let point = CGPoint(
                    x: CGFloat.random(in: size.width * 0.15 ... size.width * 0.85),
                    y: CGFloat.random(in: size.height * 0.35 ... size.height * 0.85)
                )
                burst(at: point, in: layer, dot: dot)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 1.0
                win.animator().alphaValue = 0
                label.animator().alphaValue = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) {
            win.close()
            activeWindows.removeAll { $0 === win }
        }
    }

    private static func burst(at point: CGPoint, in layer: CALayer, dot: CGImage) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .additive

        let cell = CAEmitterCell()
        cell.contents = dot
        cell.birthRate = 700
        cell.lifetime = 1.8
        cell.lifetimeRange = 0.5
        cell.velocity = 200
        cell.velocityRange = 100
        cell.emissionRange = .pi * 2
        cell.yAcceleration = -160
        cell.scale = 0.14
        cell.scaleRange = 0.07
        cell.scaleSpeed = -0.03
        cell.alphaSpeed = -0.5
        cell.redRange = 1.0
        cell.greenRange = 1.0
        cell.blueRange = 1.0
        emitter.emitterCells = [cell]

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { emitter.removeFromSuperlayer() }
    }

    private static func makeDotImage() -> CGImage? {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        var rect = NSRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

// MARK: - App

enum Phase { case idle, work, rest }

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var ticker: Timer?
    private var phase: Phase = .idle
    private var endDate: Date?
    private var pausedRemaining: TimeInterval?
    private var log: LogStore!

    private var startItem: NSMenuItem!
    private var todayItem: NSMenuItem!

    private var workSeconds: TimeInterval {
        TimeInterval(UserDefaults.standard.integer(forKey: "workMinutes") * 60)
    }
    private var restSeconds: TimeInterval {
        TimeInterval(UserDefaults.standard.integer(forKey: "restMinutes") * 60)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["workMinutes": 25, "restMinutes": 5, "fireworksEnabled": true])

        let baseDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        log = LogStore(directory: baseDir)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
        }

        rebuildMenu()
        updateTitle()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        startItem = NSMenuItem(title: "", action: #selector(toggleStartPause), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)

        let skip = NSMenuItem(title: "Skip to Next Phase", action: #selector(skipPhase), keyEquivalent: "")
        skip.target = self
        menu.addItem(skip)

        let reset = NSMenuItem(title: "Stop & Reset", action: #selector(resetTimer), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())
        menu.addItem(makeLengthMenu(title: "Work Length", key: "workMinutes", presets: [15, 25, 50]))
        menu.addItem(makeLengthMenu(title: "Rest Length", key: "restMinutes", presets: [5, 10, 15]))

        let fireworks = NSMenuItem(title: "🎆 Fireworks Celebration", action: #selector(toggleFireworks), keyEquivalent: "")
        fireworks.target = self
        fireworks.state = UserDefaults.standard.bool(forKey: "fireworksEnabled") ? .on : .off
        menu.addItem(fireworks)

        let testFireworks = NSMenuItem(title: "Test Fireworks", action: #selector(previewFireworks), keyEquivalent: "")
        testFireworks.target = self
        menu.addItem(testFireworks)

        menu.addItem(.separator())
        todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(todayItem)

        let total = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        total.title = "All time: \(log.totalPomodoros) pomodoros · \(LogStore.fmt(duration: log.totalFocusSeconds))"
        menu.addItem(total)

        let openLog = NSMenuItem(title: "Open Log", action: #selector(openLog), keyEquivalent: "")
        openLog.target = self
        menu.addItem(openLog)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Tomoporo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        refreshDynamicItems()
    }

    private func makeLengthMenu(title: String, key: String, presets: [Int]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let current = UserDefaults.standard.integer(forKey: key)
        for minutes in presets {
            let opt = NSMenuItem(title: "\(minutes) min", action: #selector(setLength(_:)), keyEquivalent: "")
            opt.target = self
            opt.representedObject = ["key": key, "minutes": minutes]
            opt.state = minutes == current ? .on : .off
            sub.addItem(opt)
        }
        let custom = NSMenuItem(title: "Custom…", action: #selector(setCustomLength(_:)), keyEquivalent: "")
        custom.target = self
        custom.representedObject = key
        custom.state = presets.contains(current) ? .off : .on
        sub.addItem(custom)
        item.submenu = sub
        return item
    }

    private func refreshDynamicItems() {
        switch (phase, pausedRemaining) {
        case (.idle, _): startItem.title = "Start 🍅 (\(Int(workSeconds / 60)) min)"
        case (_, .some): startItem.title = "Resume"
        default: startItem.title = "Pause"
        }
        let t = log.today()
        todayItem.title = "Today: \(t.emojis.joined()) · \(LogStore.fmt(duration: t.focusSeconds)) focus"
    }

    // MARK: Actions

    @objc private func toggleStartPause() {
        switch (phase, pausedRemaining) {
        case (.idle, _):
            startPhase(.work)
        case (_, .some(let remaining)):
            pausedRemaining = nil
            endDate = Date().addingTimeInterval(remaining)
        default:
            if let end = endDate {
                pausedRemaining = end.timeIntervalSinceNow
                endDate = nil
            }
        }
        refreshDynamicItems()
        updateTitle()
    }

    @objc private func skipPhase() {
        pausedRemaining = nil
        switch phase {
        case .work: startPhase(.rest)
        case .rest: startPhase(.work)
        case .idle: break
        }
    }

    @objc private func resetTimer() {
        phase = .idle
        endDate = nil
        pausedRemaining = nil
        refreshDynamicItems()
        updateTitle()
    }

    @objc private func setLength(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let key = info["key"] as? String,
              let minutes = info["minutes"] as? Int else { return }
        applyLength(key: key, minutes: minutes)
    }

    @objc private func setCustomLength(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = key == "workMinutes" ? "Work length (minutes)" : "Rest length (minutes)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        field.stringValue = "\(UserDefaults.standard.integer(forKey: key))"
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Int(field.stringValue), minutes > 0, minutes <= 480 else { return }
        applyLength(key: key, minutes: minutes)
    }

    private func applyLength(key: String, minutes: Int) {
        UserDefaults.standard.set(minutes, forKey: key)
        rebuildMenu()
        updateTitle()
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(log.mdURL)
    }

    @objc private func toggleFireworks(_ sender: NSMenuItem) {
        let enabled = !UserDefaults.standard.bool(forKey: "fireworksEnabled")
        UserDefaults.standard.set(enabled, forKey: "fireworksEnabled")
        sender.state = enabled ? .on : .off
    }

    @objc private func previewFireworks() {
        Fireworks.show()
    }

    // MARK: Timer engine

    private func startPhase(_ newPhase: Phase) {
        phase = newPhase
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(newPhase == .work ? workSeconds : restSeconds)
        refreshDynamicItems()
        updateTitle()
    }

    private func tick() {
        guard let end = endDate else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining <= 0 {
            completePhase()
        } else {
            updateTitle(remaining: remaining)
        }
    }

    private func completePhase() {
        switch phase {
        case .work:
            log.recordPomodoro(focusSeconds: Int(workSeconds))
            notify("🎉 Congratulations! Pomodoro complete — enjoy your break ☕")
            if UserDefaults.standard.bool(forKey: "fireworksEnabled") {
                Fireworks.show()
            }
            rebuildMenu()
            startPhase(.rest)
        case .rest:
            notify("☕ Break over! Click 🍅 in the menu bar to start your next pomodoro 💪")
            resetTimer()
            statusItem.button?.title = "🍅 Ready"
        case .idle:
            break
        }
    }

    private func updateTitle(remaining: TimeInterval? = nil) {
        let title: String
        if let paused = pausedRemaining {
            title = (phase == .work ? "⏸🍅 " : "⏸☕ ") + clock(paused)
        } else {
            switch phase {
            case .idle: title = "🍅"
            case .work: title = "🍅 " + clock(remaining ?? workSeconds)
            case .rest: title = "☕ " + clock(remaining ?? restSeconds)
            }
        }
        statusItem.button?.title = title
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func notify(_ message: String) {
        NSSound(named: NSSound.Name("Glass"))?.play()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "display notification \"\(message)\" with title \"Tomoporo\""]
        try? p.run()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
