import AppKit
import WebKit
import AuthenticationServices
import ServiceManagement
import UniformTypeIdentifiers

final class CommandWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct LocalShortcut: Codable {
    let id: String
    let name: String
    let kind: String
    let bookmark: Data
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply, ASWebAuthenticationPresentationContextProviding, NSWindowDelegate {
    var window: CommandWindow!
    var webView: WKWebView!
    var status: NSStatusItem!
    var authSession: ASWebAuthenticationSession?
    var desktop = false
    var normalFrame = NSRect(x: 0, y: 0, width: 1280, height: 850)
    var shortcuts: [LocalShortcut] = []
    var snapshotPath: String?
    var baseURL: URL {
        if let index = CommandLine.arguments.firstIndex(of: "--url"), CommandLine.arguments.count > index + 1,
           let url = URL(string: CommandLine.arguments[index + 1]), url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") { return url }
        return URL(string: Bundle.main.object(forInfoDictionaryKey: "ZendoWebURL") as? String ?? "https://schoi2032.github.io/zendo/")!
    }
    var authOrigin: String { Bundle.main.object(forInfoDictionaryKey: "ZendoAuthOrigin") as? String ?? "https://bvmhulpfpwqdpfopucpg.supabase.co" }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let data = UserDefaults.standard.data(forKey: "shortcuts"), let saved = try? JSONDecoder().decode([LocalShortcut].self, from: data) { shortcuts = saved }
        let content = WKUserContentController()
        content.addScriptMessageHandler(self, contentWorld: .page, name: "zendo")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        window = CommandWindow(contentRect: normalFrame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Zendo — Command Center"
        window.minSize = NSSize(width: 720, height: 550)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = webView
        window.center()
        normalFrame = window.frame
        makeMenus()
        webView.load(URLRequest(url: baseURL))
        if UserDefaults.standard.bool(forKey: "desktopMode") { setDesktop(true) }
        else { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 { snapshotPath = CommandLine.arguments[i + 1] }
    }
    func makeMenus() {
        let main = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Zendo", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Zendo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = appMenu
        main.addItem(application)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (name, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: name, action: Selector(action), keyEquivalent: key)
        }
        edit.submenu = editMenu
        main.addItem(edit)
        NSApp.mainMenu = main
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Zendo")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Command Center", action: #selector(openWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Use as Desktop", action: #selector(toggleDesktop), keyEquivalent: "")
        menu.addItem(withTitle: "Show / Hide", action: #selector(toggleVisibility), keyEquivalent: "")
        menu.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Zendo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items { if item.action != #selector(NSApplication.terminate(_:)) { item.target = self } }
        status.menu = menu
    }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Zendo", .applicationVersion: "1.1 development preview", .credits: NSAttributedString(string: "Your desktop Command Center. Local app and file shortcuts stay on this Mac.")])
    }
    @objc func reload() { webView.reload() }
    @objc func openWindow() { setDesktop(false); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func toggleVisibility() { if window.isVisible { window.orderOut(nil) } else if desktop { window.orderFrontRegardless() } else { openWindow() } }
    @objc func toggleDesktop() { requestDesktop(!desktop) { _ in } }
    @objc func screenChanged() { if desktop, let screen = NSScreen.screens.first { window.setFrame(screen.visibleFrame, display: true) } }
    func windowShouldClose(_ sender: NSWindow) -> Bool { window.orderOut(nil); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { authSession?.cancel() }

    func requestDesktop(_ enabled: Bool, done: @escaping (Bool) -> Void) {
        guard enabled, !UserDefaults.standard.bool(forKey: "desktopConsent") else { setDesktop(enabled); done(true); return }
        let alert = NSAlert()
        alert.messageText = "Use Zendo as your desktop?"
        alert.informativeText = "Zendo will fill your main display behind your regular windows and cover Finder’s desktop icons. Your wallpaper and files stay in place. Use the Zendo menu bar icon to hide it or return to a normal window at any time."
        alert.addButton(withTitle: "Enable Desktop Mode")
        alert.addButton(withTitle: "Keep as Window")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { UserDefaults.standard.set(true, forKey: "desktopConsent"); self.setDesktop(true); done(true) }
            else { done(false) }
        }
    }
    func setDesktop(_ enabled: Bool) {
        if enabled && !desktop { normalFrame = window.frame }
        desktop = enabled
        if enabled {
            window.styleMask = [.borderless]
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.hasShadow = false
            if let screen = NSScreen.screens.first { window.setFrame(screen.visibleFrame, display: true) }
            window.orderFrontRegardless()
        } else {
            window.level = .normal
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.collectionBehavior = []
            window.hasShadow = true
            window.setFrame(normalFrame, display: true)
        }
        UserDefaults.standard.set(enabled, forKey: "desktopMode")
        status?.menu?.items[1].title = enabled ? "Leave Desktop Mode" : "Use as Desktop"
        if webView != nil { webView.evaluateJavaScript("window.dispatchEvent(new Event('focus'))", completionHandler: nil) }
    }
    func trusted(_ url: URL?) -> Bool {
        guard let url = url, url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else { return false }
        let prefix = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        return url.path == baseURL.path || url.path.hasPrefix(prefix)
    }
    func state() -> [String: Any] {
        return ["desktop": desktop, "login": SMAppService.mainApp.status == .enabled,
                "shortcuts": shortcuts.map { ["id": $0.id, "name": $0.name, "kind": $0.kind] }]
    }
    func saveShortcuts() { if let data = try? JSONEncoder().encode(shortcuts) { UserDefaults.standard.set(data, forKey: "shortcuts") } }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler reply: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame, trusted(message.frameInfo.request.url), trusted(webView.url),
              let body = message.body as? [String: Any], let action = body["action"] as? String else { reply(nil, "Untrusted desktop request."); return }
        switch action {
        case "getState": reply(state(), nil)
        case "setDesktop":
            guard let value = body["value"] as? Bool else { reply(nil, "Invalid desktop setting."); return }
            requestDesktop(value) { _ in reply(self.state(), nil) }
        case "setLogin":
            guard let enabled = body["value"] as? Bool else { reply(nil, "Invalid login setting."); return }
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                if enabled && SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                reply(state(), nil)
            } catch { reply(nil, "Could not change launch at login. Move Zendo to Applications, then try again.") }
        case "addShortcut":
            guard let kind = body["value"] as? String, ["app", "file", "folder"].contains(kind) else { reply(nil, "Choose an app, file, or folder."); return }
            let wasDesktop = desktop
            if wasDesktop { window.level = .normal }
            let picker = NSOpenPanel()
            picker.title = kind == "app" ? "Choose an application" : kind == "folder" ? "Choose a folder" : "Choose a document"
            picker.prompt = "Add shortcut"
            picker.canChooseDirectories = kind == "folder"
            picker.canChooseFiles = kind != "folder"
            picker.allowsMultipleSelection = false
            if kind == "app" { picker.allowedContentTypes = [.applicationBundle]; picker.directoryURL = URL(fileURLWithPath: "/Applications") }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            picker.beginSheetModal(for: window) { response in
                defer { if wasDesktop { self.setDesktop(true) } }
                guard response == .OK, let url = picker.url else { reply(self.state(), nil); return }
                do {
                    let values = try url.resourceValues(forKeys: [.isExecutableKey, .isDirectoryKey, .contentTypeKey])
                    // Local files are documents; scripts and executable files cannot be launched as file shortcuts.
                    if kind == "file" && (values.isExecutable == true || values.contentType?.conforms(to: .executable) == true || values.contentType?.conforms(to: .script) == true) { reply(nil, "Choose a document rather than an executable or script."); return }
                    let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    let shortcut = LocalShortcut(id: UUID().uuidString, name: kind == "app" ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent, kind: kind, bookmark: bookmark)
                    self.shortcuts.append(shortcut); self.saveShortcuts(); reply(self.state(), nil)
                } catch { reply(nil, "This item could not be added. Try choosing it again.") }
            }
        case "openShortcut":
            guard let id = body["value"] as? String, let shortcut = shortcuts.first(where: { $0.id == id }) else { reply(nil, "Shortcut not found."); return }
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: shortcut.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
                guard FileManager.default.fileExists(atPath: url.path) else { reply(nil, "This item has moved or was removed. Add it again with the picker."); return }
                if shortcut.kind == "app" {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in DispatchQueue.main.async { reply(error == nil ? self.state() : nil, error == nil ? nil : "Could not open this app.") } }
                } else {
                    // Check again because a chosen document may have changed since it was pinned.
                    let values = try url.resourceValues(forKeys: [.isExecutableKey, .contentTypeKey])
                    if shortcut.kind == "file" && (values.isExecutable == true || values.contentType?.conforms(to: .executable) == true || values.contentType?.conforms(to: .script) == true) { reply(nil, "This shortcut now points to an executable. Choose the document again."); return }
                    if NSWorkspace.shared.open(url) { reply(state(), nil) } else { reply(nil, "Could not open this item.") }
                }
            } catch { reply(nil, "This shortcut is unavailable. Add it again with the picker.") }
        case "removeShortcut":
            guard let id = body["value"] as? String else { reply(nil, "Invalid shortcut."); return }
            shortcuts.removeAll { $0.id == id }; saveShortcuts(); reply(state(), nil)
        case "signIn":
            guard let value = body["value"] as? String, let url = URL(string: value),
                  let origin = URL(string: authOrigin), url.scheme == "https", url.host == origin.host, url.port == origin.port,
                  url.path == "/auth/v1/authorize", url.user == nil, url.password == nil,
                  let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  parts.queryItems?.first(where: { $0.name == "provider" })?.value == "google",
                  parts.queryItems?.first(where: { $0.name == "redirect_to" })?.value == baseURL.appendingPathComponent("auth/callback/").absoluteString else { reply(nil, "Invalid sign-in request."); return }
            guard authSession == nil else { reply(nil, "Sign-in is already in progress."); return }
            let nonce = UUID().uuidString
            var start = URLComponents(url: baseURL.appendingPathComponent("desktop-auth/"), resolvingAgainstBaseURL: false)!
            var fragment = URLComponents()
            fragment.queryItems = [URLQueryItem(name: "url", value: value), URLQueryItem(name: "state", value: nonce)]
            start.percentEncodedFragment = fragment.percentEncodedQuery
            let session = ASWebAuthenticationSession(url: start.url!, callbackURLScheme: "zendo") { callback, error in
                DispatchQueue.main.async {
                    self.authSession = nil
                    guard error == nil, let callback = callback, callback.host == "auth", callback.path == "/callback", let result = URLComponents(url: callback, resolvingAgainstBaseURL: false), result.queryItems?.first(where: { $0.name == "state" })?.value == nonce else { reply(nil, "Sign-in was cancelled. Please try again."); return }
                    guard let code = result.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else { reply(nil, "Google sign-in could not finish. Please try again."); return }
                    reply(["code": code], nil)
                    if !self.desktop { self.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
                }
            }
            session.presentationContextProvider = self
            authSession = session
            if !session.start() { authSession = nil; reply(nil, "Your Mac could not start browser sign-in.") }
        default: reply(nil, "Unsupported desktop action.")
        }
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { window }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if trusted(url) && navigationAction.targetFrame != nil && !url.path.hasSuffix(".zip") { decisionHandler(.allow); return }
        if ["https", "http"].contains(url.scheme ?? ""), url.user == nil, url.password == nil { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard trusted(frame.request.url) else { completionHandler(false); return }
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "Confirm"); alert.addButton(withTitle: "Cancel")
        let wasDesktop = desktop
        if wasDesktop { window.level = .normal }
        alert.beginSheetModal(for: window) { response in if wasDesktop { self.setDesktop(true) }; completionHandler(response == .alertFirstButtonReturn) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let output = snapshotPath else { return }
        snapshotPath = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.webView.takeSnapshot(with: nil) { image, error in
                guard let image = image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fputs("Snapshot failed\n", stderr); NSApp.terminate(nil); return }
                do { try png.write(to: URL(fileURLWithPath: output)); print("Snapshot saved") } catch { fputs("Snapshot write failed\n", stderr) }
                NSApp.terminate(nil)
            }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        let alert = NSAlert(); alert.messageText = "Zendo could not connect"; alert.informativeText = "Check your internet connection, then use Reload in the Zendo menu bar menu. Your existing data is kept."; alert.addButton(withTitle: "OK"); alert.beginSheetModal(for: window)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
