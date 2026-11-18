import Cocoa
import WebKit
import AuthenticationServices

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class DesktopApp: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, ASWebAuthenticationPresentationContextProviding, WKScriptMessageHandler {
    private var window: DesktopWindow!
    private var webView: WKWebView!
    private var statusItem: NSStatusItem!
    private var authentication: ASWebAuthenticationSession?
    private var configuration = DesktopConfiguration()
    private var desktopMode = false
    private var signedIn = false
    private var clickThrough = false
    private var selectedScreen: NSScreen?
    private var errorLabel: NSTextField!
    private var reloadButton: NSButton!
    private var screenObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var focusObserver: NSObjectProtocol?
    private var hiding = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One desktop companion per user; a second launch brings up the existing one.
        if let identifier = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        if let saved = UserDefaults.standard.string(forKey: "appURL"), let url = DesktopConfiguration.validatedURL(saved) { configuration = DesktopConfiguration(appURL: url) }
        selectedScreen = NSScreen.screens.first(where: { screenID($0) == UserDefaults.standard.integer(forKey: "screenID") }) ?? NSScreen.main
        makeMainMenu()
        makeWindow()
        makeStatusItem()
        openHome()
        openAsWindow()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateDisplay() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshData() }
        }
        focusObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshData() }
        }
    }

    private func makeMainMenu() {
        let main = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(menuItem("Quit Zendo Desktop", #selector(quit), key: "q"))
        application.submenu = appMenu
        main.addItem(application)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func makeWindow() {
        let screen = selectedScreen ?? NSScreen.main!
        window = DesktopWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Zendo Desktop"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        content.autoresizingMask = [.width, .height]
        let preferences = WKWebViewConfiguration()
        preferences.websiteDataStore = .default()
        preferences.userContentController.add(self, name: "zendoSession")
        // Observe only signed-in UI state, never tokens or account contents.
        // The DOM fallback also supports the currently deployed website.
        let sessionObserver = """
        (() => {
          let previous = null;
          const notify = () => {
            const explicit = document.documentElement.dataset.zendoAuth;
            const state = explicit === 'signed-in' ? true : explicit === 'signed-out' ? false
              : document.querySelector('.app-shell') ? true : document.querySelector('.welcome') ? false : null;
            if (state !== null && state !== previous) {
              previous = state;
              window.webkit.messageHandlers.zendoSession.postMessage({signedIn: state});
            }
          };
          new MutationObserver(notify).observe(document.documentElement, {childList: true, subtree: true, attributes: true, attributeFilter: ['data-zendo-auth']});
          notify();
        })();
        """
        preferences.userContentController.addUserScript(WKUserScript(source: sessionObserver, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView = WKWebView(frame: content.bounds, configuration: preferences)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        content.addSubview(webView)
        errorLabel = NSTextField(wrappingLabelWithString: "")
        errorLabel.alignment = .center
        errorLabel.font = .systemFont(ofSize: 15)
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(errorLabel)
        reloadButton = NSButton(title: "Retry", target: self, action: #selector(reloadPage))
        reloadButton.bezelStyle = .rounded
        reloadButton.isHidden = true
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(reloadButton)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: -20),
            errorLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 30),
            reloadButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            reloadButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 18)
        ])
        window.contentView = content
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Z"
        statusItem.button?.font = .systemFont(ofSize: 16, weight: .bold)
        statusItem.button?.toolTip = "Zendo Desktop"
        updateMenu()
    }

    private func updateMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        let heading = NSMenuItem(title: "Zendo Desktop", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        menu.addItem(menuItem("Show Command Center", #selector(showDesktop)))
        menu.addItem(menuItem("Open as Window", #selector(openAsWindow), key: "o"))
        menu.addItem(menuItem("Hide Dashboard", #selector(hideDashboard), key: "h"))
        let click = menuItem("Click Through to Desktop", #selector(toggleClickThrough))
        click.state = clickThrough ? .on : .off
        click.isEnabled = desktopMode
        menu.addItem(click)
        let screens = NSMenu()
        for (index, screen) in NSScreen.screens.enumerated() {
            let item = menuItem(screen.localizedName, #selector(chooseDisplay(_:)))
            item.tag = index
            item.state = screenID(screen) == selectedScreen.map(screenID) ? .on : .off
            screens.addItem(item)
        }
        let display = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        display.submenu = screens
        menu.addItem(display)
        menu.addItem(.separator())
        menu.addItem(menuItem("Reload", #selector(reloadPage), key: "r"))
        menu.addItem(menuItem("Open in Browser", #selector(openInBrowser)))
        menu.addItem(menuItem("Dashboard Address…", #selector(changeAddress)))
        menu.addItem(menuItem("Google Sign-in Setup…", #selector(signInSetup)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Zendo Desktop", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func screenID(_ screen: NSScreen) -> Int {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
    }

    private func updateDisplay() {
        selectedScreen = NSScreen.screens.first(where: { screenID($0) == selectedScreen.map(screenID) }) ?? NSScreen.main
        if desktopMode, let screen = selectedScreen { window.setFrame(screen.frame, display: true) }
        updateMenu()
    }

    @objc private func chooseDisplay(_ sender: NSMenuItem) {
        guard NSScreen.screens.indices.contains(sender.tag) else { return }
        selectedScreen = NSScreen.screens[sender.tag]
        UserDefaults.standard.set(screenID(selectedScreen!), forKey: "screenID")
        showOnDesktop()
    }

    private func showOnDesktop() {
        guard signedIn else { openAsWindow(); return }
        desktopMode = true
        hiding = false
        window.styleMask = [.borderless]
        // Above Finder's desktop icons for interaction, below ordinary app windows.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = clickThrough
        if let screen = selectedScreen ?? NSScreen.main { window.setFrame(screen.frame, display: true) }
        window.orderFrontRegardless()
        refreshData()
        updateMenu()
    }

    @objc private func showDesktop() { showOnDesktop() }

    @objc private func openAsWindow() {
        desktopMode = false
        hiding = false
        window.ignoresMouseEvents = false
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.level = .normal
        window.collectionBehavior = [.managed]
        let visible = (selectedScreen ?? NSScreen.main!).visibleFrame
        let size = NSSize(width: min(1280, visible.width - 60), height: min(900, visible.height - 60))
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshData()
        updateMenu()
    }

    @objc private func hideDashboard() {
        hiding = true
        window.orderOut(nil)
    }

    @objc private func toggleClickThrough() {
        clickThrough.toggle()
        if desktopMode { window.ignoresMouseEvents = clickThrough }
        updateMenu()
    }

    @objc private func openInBrowser() { NSWorkspace.shared.open(configuration.appURL) }

    @objc private func reloadPage() {
        if webView.url != nil && !webView.isHidden { webView.reload() } else { openHome() }
    }

    private func openHome() {
        webView.isHidden = false
        errorLabel.isHidden = true
        reloadButton.isHidden = true
        webView.load(URLRequest(url: configuration.appURL))
    }

    private func refreshData() {
        guard webView != nil, !hiding else { return }
        // Refresh data and today's date without reloading or losing an open draft.
        webView.evaluateJavaScript("window.dispatchEvent(new Event('focus'))", completionHandler: nil)
    }

    @objc private func changeAddress() {
        let alert = NSAlert()
        alert.messageText = "Dashboard address"
        alert.informativeText = "Use your deployed Zendo address, or http://localhost:3000/ while npm run dev is running. Changing origins requires signing in again."
        let field = NSTextField(string: configuration.appURL.absoluteString)
        field.frame = NSRect(x: 0, y: 0, width: 420, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let url = DesktopConfiguration.validatedURL(field.stringValue) else {
            showAlert("Invalid address", "Use an HTTPS address without credentials, query parameters, or fragments. HTTP is allowed only for localhost development.")
            return
        }
        authentication?.cancel()
        signedIn = false
        openAsWindow()
        configuration = DesktopConfiguration(appURL: url)
        UserDefaults.standard.set(url.absoluteString, forKey: "appURL")
        openHome()
    }

    @objc private func signInSetup() {
        showAlert("Google sign-in setup", "In Supabase → Authentication → URL Configuration → Redirect URLs, add:\n\n\(DesktopConfiguration.nativeCallback.absoluteString)\n\nKeep your existing Google Cloud callback and website URLs. Google sign-in opens in a system browser session, then returns here. Do not paste client secrets into this app.")
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { window }

    private func authenticate(_ url: URL) {
        guard authentication == nil else { return }
        openAsWindow()
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: DesktopConfiguration.nativeCallback.scheme) { [weak self] callback, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.authentication = nil
                if let callback, let webURL = self.configuration.webCallback(from: callback) {
                    // The verifier remains in this WKWebView's persistent local storage.
                    // Only the short-lived code returns; tokens are never logged or copied.
                    self.webView.load(URLRequest(url: webURL))
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    self.openHome()
                } else {
                    self.showAlert("Sign-in did not finish", "Check the native callback in Supabase Redirect URLs. Start a new sign-in from this app and complete it in the browser session that opens.")
                    self.openHome()
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authentication = session
        if !session.start() {
            authentication = nil
            showAlert("Could not open sign-in", "Try Google sign-in again, or open Zendo in your browser.")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "zendoSession", message.frameInfo.isMainFrame,
              let source = message.frameInfo.request.url, configuration.belongsToApp(source),
              let body = message.body as? [String: Any], let authenticated = body["signedIn"] as? Bool else { return }
        let wasSignedIn = signedIn
        signedIn = authenticated
        if authenticated && !wasSignedIn && !hiding {
            showOnDesktop()
        } else if !authenticated && desktopMode && !hiding {
            openAsWindow()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if let auth = configuration.nativeAuthorizationURL(from: url) {
            decisionHandler(.cancel)
            authenticate(auth)
            return
        }
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        if configuration.belongsToApp(url) || url.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            if ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorLabel.isHidden = true
        reloadButton.isHidden = true
        webView.isHidden = false
    }

    private func navigationFailed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        webView.isHidden = true
        errorLabel.stringValue = "Zendo couldn’t load. Check your connection and dashboard address, then retry. If using localhost, start npm run dev first."
        errorLabel.isHidden = false
        reloadButton.isHidden = false
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "Confirm")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { hideDashboard(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc private func quit() { authentication?.cancel(); NSApp.terminate(nil) }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = DesktopApp()
    app.delegate = delegate
    app.run()
}
