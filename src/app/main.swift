// Travel Mode: a small native front end for the `travel-mode` script bundled in Resources/bin.
// Window with the standard close / minimise / zoom buttons, plus an optional menu bar icon.
//
//   TravelMode                          normal launch
//   TravelMode --snapshot out.png [--dark] [--demo]   render the window content to a PNG and exit
//                                                      (--demo uses sample data, for the README)
import AppKit
import SwiftUI

// MARK: - Shell

enum Shell {
    @discardableResult
    static func run(_ path: String, _ args: [String] = []) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (p.terminationStatus, out)
    }
}

// MARK: - Model

final class TravelModel: ObservableObject {
    struct State {
        var isOn = false
        var wifiState = "none"          // hotspot | other | off | none
        var wifiMessage = "Checking…"
        var battery = ""
        var pluggedIn = false
        var hotspot = ""                // remembered hotspot name
    }

    @Published private(set) var state = State()
    @Published var busy = false
    @Published var note = ""
    @Published var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
            onMenuBarChange?(showInMenuBar)
        }
    }

    var onMenuBarChange: ((Bool) -> Void)?
    var onChange: (() -> Void)?

    let tool: String
    private var timer: Timer?
    private var refreshing = false

    init() {
        tool = Bundle.main.resourceURL!.appendingPathComponent("bin/travel-mode").path
        showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
    }

    static func read(tool: String) -> State {
        var s = State()
        s.isOn = Shell.run(tool, ["is-on"]).status == 0
        let wifi = Shell.run(tool, ["wifi"]).out.components(separatedBy: "\t")
        s.wifiState = wifi.first ?? "none"
        if wifi.count > 1 { s.wifiMessage = String(wifi[1].drop(while: { !$0.isLetter })) }
        s.hotspot = Shell.run(tool, ["hotspot"]).out
        let batt = Shell.run("/usr/bin/pmset", ["-g", "batt"]).out
        if let r = batt.range(of: #"\d+%"#, options: .regularExpression) {
            s.battery = String(batt[r])
        } else {
            s.battery = "No battery"
        }
        s.pluggedIn = batt.contains("AC Power")
        return s
    }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        let tool = self.tool
        DispatchQueue.global(qos: .userInitiated).async {
            let s = TravelModel.read(tool: tool)
            DispatchQueue.main.async {
                self.refreshing = false
                self.state = s
                self.onChange?()
            }
        }
    }

    func refreshNow() {
        state = TravelModel.read(tool: tool)
        onChange?()
    }

    func loadDemo() { // sample data for README screenshots
        state = State(isOn: true, wifiState: "hotspot", wifiMessage: "On your iPhone hotspot (My iPhone)",
                      battery: "82%", pluggedIn: false, hotspot: "My iPhone")
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func setOn(_ on: Bool) { perform([on ? "on" : "off"]) }

    func join(_ name: String? = nil) {
        var args = ["join"]
        if let name = name { args.append(name) }
        perform(args)
    }

    func networks() -> [String] {
        Shell.run(tool, ["networks"]).out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    func rememberHotspot(_ name: String) { Shell.run(tool, ["hotspot", name]) }

    private func perform(_ args: [String]) {
        busy = true
        note = args.first == "join" ? "Joining…" : ""
        let tool = self.tool
        DispatchQueue.global(qos: .userInitiated).async {
            let r = Shell.run(tool, args)
            DispatchQueue.main.async {
                self.busy = false
                self.note = r.status == 0 ? "" : (r.out.components(separatedBy: "\n").last ?? "Nothing changed.")
                self.refresh()
            }
        }
    }

    // Presentation helpers
    var onHotspot: Bool { state.wifiState == "hotspot" }
    var joinTitle: String { state.hotspot.isEmpty ? "Join Hotspot…" : "Join \(state.hotspot)" }
    var batterySymbol: String {
        if state.pluggedIn { return "battery.100.bolt" }
        let n = Int(state.battery.prefix { $0.isNumber }) ?? 100
        if n >= 88 { return "battery.100" }
        if n >= 63 { return "battery.75" }
        if n >= 38 { return "battery.50" }
        if n >= 13 { return "battery.25" }
        return "battery.0"
    }
}

// MARK: - Views

struct InfoRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 22)
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
    }
}

struct ContentView: View {
    @ObservedObject var model: TravelModel
    var chooseHotspot: () -> Void

    var body: some View {
        let s = model.state
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Travel Mode").font(.title2.weight(.semibold))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(s.isOn ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(s.isOn ? "On" : "Off").foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            VStack(spacing: 0) {
                InfoRow(symbol: "lock.laptopcomputer",
                        tint: s.isOn ? .accentColor : .secondary,
                        title: "Lid",
                        value: s.isOn ? "Stays awake, locks when closed" : "Sleeps when closed")
                Divider().padding(.leading, 34)
                InfoRow(symbol: model.onHotspot ? "personalhotspot" : "wifi.exclamationmark",
                        tint: model.onHotspot ? .green : .orange,
                        title: "Wi-Fi",
                        value: s.wifiMessage)
                Divider().padding(.leading, 34)
                InfoRow(symbol: model.batterySymbol,
                        tint: .secondary,
                        title: "Battery",
                        value: s.pluggedIn ? "\(s.battery), plugged in" : s.battery)
                Divider().padding(.leading, 34)
                InfoRow(symbol: "arrow.triangle.2.circlepath",
                        tint: .secondary,
                        title: "Rejoins",
                        value: s.hotspot.isEmpty ? "No hotspot yet" : s.hotspot)
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))

            HStack(spacing: 10) {
                if !model.onHotspot {
                    Button(model.joinTitle) {
                        if s.hotspot.isEmpty { chooseHotspot() } else { model.join() }
                    }
                    .controlSize(.large)
                }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button(s.isOn ? "Turn Off" : "Turn On") { model.setOn(!s.isOn) }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .disabled(model.busy)

            if !model.note.isEmpty {
                Text(model.note).font(.callout).foregroundColor(.secondary)
            }

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show in menu bar")
                    Text("Keeps Travel Mode in the menu bar after you close this window.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("Show in menu bar", isOn: $model.showInMenuBar)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 400, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = TravelModel()
    var window: NSWindow!
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        buildWindow()
        model.onMenuBarChange = { [weak self] show in self?.setStatusItem(show) }
        model.onChange = { [weak self] in self?.updateStatusIcon() }
        setStatusItem(model.showInMenuBar)
        model.refresh()
        model.startTimer()
        showWindow()
        checkLocation()
    }

    /// Opened straight from the disk image (or a quarantine "translocated" copy): the background
    /// watcher would point at a path that disappears, so ask the user to move the app first.
    func checkLocation() {
        let path = Bundle.main.bundlePath
        guard path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/") else { return }
        let alert = NSAlert()
        alert.messageText = "Move Travel Mode to Applications first"
        alert.informativeText = "Travel Mode is running from the disk image or a temporary location, and its background helper needs a permanent home.\n\nQuit, drag Travel Mode into the Applications folder, eject the disk image, then open Travel Mode from Applications."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Continue Anyway")
        if alert.runModal() == .alertFirstButtonReturn { NSApp.terminate(nil) }
    }

    @objc func uninstall() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Uninstall Travel Mode?"
        alert.informativeText = "This turns Travel Mode off so your Mac sleeps normally again, removes its background helper and settings, and moves the app to the Trash."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if Shell.run(model.tool, ["is-on"]).status == 0, Shell.run(model.tool, ["off"]).status != 0 {
            let stop = NSAlert()
            stop.messageText = "Travel Mode is still on"
            stop.informativeText = "Nothing was removed. Turning it off needs your Mac password."
            stop.runModal()
            return
        }
        Shell.run(model.tool, ["_uninstall"])
        window.setFrameAutosaveName("")
        if let id = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: id) }
        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !model.showInMenuBar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        // With the menu bar icon on, closing the window keeps the app running without a Dock icon.
        if model.showInMenuBar { NSApp.setActivationPolicy(.accessory) }
    }

    @objc func showWindow() {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        model.refresh()
    }

    func buildWindow() {
        let view = ContentView(model: model, chooseHotspot: { [weak self] in self?.chooseHotspot() })
        window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Travel Mode"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("TravelModeMainWindow")
        if !window.setFrameUsingName("TravelModeMainWindow") { window.center() }
    }

    func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Travel Mode",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let uninstallItem = NSMenuItem(title: "Uninstall Travel Mode…", action: #selector(uninstall), keyEquivalent: "")
        uninstallItem.target = self
        appMenu.addItem(uninstallItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Travel Mode", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Travel Mode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    // MARK: Menu bar icon

    func setStatusItem(_ show: Bool) {
        if show, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.delegate = self
            item.menu = menu
            statusItem = item
            updateStatusIcon()
        } else if !show, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let on = model.state.isOn
        let image = NSImage(systemSymbolName: on ? "suitcase.rolling.fill" : "suitcase.rolling",
                            accessibilityDescription: "Travel Mode")
            ?? NSImage(systemSymbolName: on ? "suitcase.fill" : "suitcase", accessibilityDescription: "Travel Mode")
        image?.isTemplate = true
        button.image = image
        button.toolTip = on ? "Travel Mode is on" : "Travel Mode is off"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refresh()
        let s = model.state
        menu.removeAllItems()

        func info(_ title: String) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        func action(_ title: String, _ selector: Selector, key: String = "", target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = target ?? self
            item.isEnabled = !model.busy || selector == #selector(showWindow)
            menu.addItem(item)
        }

        info(s.isOn ? "Travel Mode is On" : "Travel Mode is Off")
        info("Wi-Fi: \(s.wifiMessage)")
        info("Battery: \(s.battery)\(s.pluggedIn ? ", plugged in" : "")")
        menu.addItem(.separator())
        action(s.isOn ? "Turn Off" : "Turn On", #selector(toggleFromMenu))
        if !model.onHotspot { action(model.joinTitle, #selector(joinFromMenu)) }
        menu.addItem(.separator())
        action("Open Travel Mode…", #selector(showWindow))
        let quit = NSMenuItem(title: "Quit Travel Mode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc func toggleFromMenu() { model.setOn(!model.state.isOn) }

    @objc func joinFromMenu() {
        if model.state.hotspot.isEmpty { showWindow(); chooseHotspot() } else { model.join() }
    }

    // MARK: Hotspot picker

    func chooseHotspot() {
        let nets = model.networks()
        let alert = NSAlert()
        if nets.isEmpty {
            alert.messageText = "No saved Wi-Fi networks"
            alert.informativeText = "Join your iPhone's hotspot once from the Wi-Fi menu. Travel Mode remembers it after that."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        alert.messageText = "Which saved network is your iPhone hotspot?"
        alert.informativeText = "Travel Mode joins it now, and rejoins it if Wi-Fi drops while Travel Mode is on."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 26), pullsDown: false)
        popup.addItems(withTitles: nets)
        alert.accessoryView = popup
        alert.addButton(withTitle: "Join")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, let name = popup.titleOfSelectedItem {
            model.rememberHotspot(name)
            model.join(name)
        }
    }
}

// MARK: - Snapshot (docs and checks)

func snapshot(to path: String, dark: Bool, demo: Bool) -> Int32 {
    let model = TravelModel()
    if demo { model.loadDemo() } else { model.refreshNow() }
    let host = NSHostingView(rootView: ContentView(model: model, chooseHotspot: {})
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor)))
    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let size = host.fittingSize
    let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: size.width, height: size.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = host.appearance
    window.backgroundColor = dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.97, alpha: 1)
    window.contentView = host
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 1 }
    host.cacheDisplay(in: host.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else { return 1 }
    do { try png.write(to: URL(fileURLWithPath: path)) } catch { return 1 }
    return 0
}

// MARK: - Entry point

let app = NSApplication.shared
let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count {
    app.setActivationPolicy(.prohibited)
    exit(snapshot(to: arguments[i + 1], dark: arguments.contains("--dark"), demo: arguments.contains("--demo")))
}
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
