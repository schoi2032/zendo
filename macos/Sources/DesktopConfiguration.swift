import Foundation

struct DesktopConfiguration {
    static let nativeCallback = URL(string: "com.zendo.desktop://auth/callback")!
    static let defaultURL = URL(string: "https://schoi2032.github.io/zendo/")!
    static let supabaseHost = "bvmhulpfpwqdpfopucpg.supabase.co"
    let appURL: URL

    init(appURL: URL = defaultURL) { self.appURL = appURL }

    static func validatedURL(_ string: String) -> URL? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(host)) else { return nil }
        return URL(string: url.absoluteString.hasSuffix("/") ? url.absoluteString : url.absoluteString + "/")
    }

    func belongsToApp(_ url: URL) -> Bool {
        url.scheme == appURL.scheme && url.host == appURL.host && url.port == appURL.port &&
        (url.path == appURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).appendingPrefixSlash || url.path.hasPrefix(appURL.path.hasSuffix("/") ? appURL.path : appURL.path + "/"))
    }

    func nativeAuthorizationURL(from url: URL) -> URL? {
        guard url.scheme == "https", url.host == Self.supabaseHost,
              url.port == nil || url.port == 443,
              url.path == "/auth/v1/authorize",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.queryItems?.first(where: { $0.name == "provider" })?.value == "google" else { return nil }
        var query = components.queryItems ?? []
        query.removeAll { $0.name == "redirect_to" }
        query.append(URLQueryItem(name: "redirect_to", value: Self.nativeCallback.absoluteString))
        components.queryItems = query
        return components.url
    }

    func webCallback(from callback: URL) -> URL? {
        guard callback.scheme == Self.nativeCallback.scheme, callback.host == "auth", callback.path == "/callback",
              let incoming = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let code = incoming.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return nil }
        let url = appURL.appendingPathComponent("auth/callback/")
        var outgoing = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        outgoing.queryItems = [URLQueryItem(name: "code", value: code)]
        return outgoing.url
    }
}

private extension String {
    var appendingPrefixSlash: String { "/" + self }
}
