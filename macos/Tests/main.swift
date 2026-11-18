import Foundation

func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
let config = DesktopConfiguration()
expect(config.belongsToApp(URL(string:"https://schoi2032.github.io/zendo/")!),"App root")
expect(config.belongsToApp(URL(string:"https://schoi2032.github.io/zendo/auth/callback/?code=test")!),"App callback")
expect(!config.belongsToApp(URL(string:"https://schoi2032.github.io/zendo-evil/")!),"Reject adjacent path")
expect(!config.belongsToApp(URL(string:"https://evil.example/zendo/")!),"Reject foreign host")
expect(!config.belongsToApp(URL(string:"http://schoi2032.github.io/zendo/")!),"Reject HTTP downgrade")
expect(DesktopConfiguration.validatedURL("http://localhost:3000")?.absoluteString == "http://localhost:3000/","Local development URL")
for url in ["javascript:alert(1)","file:///etc/passwd","http://example.com/","https://user:secret@example.com/","https://example.com/?code=secret"] {
    expect(DesktopConfiguration.validatedURL(url) == nil,"Reject unsafe dashboard URL")
}
let authorization = URL(string:"https://bvmhulpfpwqdpfopucpg.supabase.co/auth/v1/authorize?provider=google&redirect_to=https%3A%2F%2Fschoi2032.github.io%2Fzendo%2Fauth%2Fcallback%2F&code_challenge=test-challenge&code_challenge_method=s256")!
let rewritten = config.nativeAuthorizationURL(from: authorization)!
let query = URLComponents(url:rewritten,resolvingAgainstBaseURL:false)!.queryItems!
expect(query.first(where:{$0.name=="redirect_to"})?.value == DesktopConfiguration.nativeCallback.absoluteString,"Native redirect")
expect(query.first(where:{$0.name=="code_challenge"})?.value == "test-challenge","Preserve PKCE challenge")
expect(query.filter({$0.name=="redirect_to"}).count==1,"One redirect")
expect(config.nativeAuthorizationURL(from:URL(string:"https://evil.example/auth/v1/authorize?provider=google")!) == nil,"Reject foreign authorization URL")
expect(config.nativeAuthorizationURL(from:URL(string:"https://bvmhulpfpwqdpfopucpg.supabase.co/auth/v1/token?provider=google")!) == nil,"Reject non-authorization endpoint")
let callback = config.webCallback(from:URL(string:"com.zendo.desktop://auth/callback?code=one-use-code&access_token=do-not-forward")!)!
expect(callback.host == "schoi2032.github.io","Return to same app origin")
expect(callback.path.hasPrefix("/zendo/auth/callback"),"Return to web callback")
let callbackQuery = URLComponents(url:callback,resolvingAgainstBaseURL:false)!.queryItems!
expect(callbackQuery.count == 1 && callbackQuery[0].name == "code","Forward only one-use code")
expect(config.webCallback(from:URL(string:"com.zendo.desktop://evil/callback?code=x")!) == nil,"Reject wrong callback host")
expect(config.webCallback(from:URL(string:"com.zendo.desktop://auth/callback?error=denied")!) == nil,"Reject failed authorization")
print("Desktop configuration and OAuth routing tests passed.")
