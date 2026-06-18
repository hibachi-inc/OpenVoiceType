import Testing
@testable import VoiceFlowApp

@Suite("AppContext.classify")
struct AppContextTests {

    @Test func slackIsChat() {
        let ctx = AppContext.forTesting(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        #expect(ctx.category == .chat)
    }

    @Test func discordIsChat() {
        let ctx = AppContext.forTesting(appName: "Discord", bundleID: "com.hnc.Discord")
        #expect(ctx.category == .chat)
    }

    @Test func mailIsEmail() {
        let ctx = AppContext.forTesting(appName: "Mail", bundleID: "com.apple.mail")
        #expect(ctx.category == .email)
    }

    @Test func outlookIsEmail() {
        let ctx = AppContext.forTesting(appName: "Microsoft Outlook", bundleID: "com.microsoft.Outlook")
        #expect(ctx.category == .email)
    }

    @Test func xcodeIsCode() {
        let ctx = AppContext.forTesting(appName: "Xcode", bundleID: "com.apple.dt.Xcode")
        #expect(ctx.category == .code)
    }

    @Test func cursorIsCode() {
        let ctx = AppContext.forTesting(appName: "Cursor", bundleID: "com.todesktop.cursor")
        #expect(ctx.category == .code)
    }

    @Test func codexIsCode() {
        let ctx = AppContext.forTesting(appName: "Codex", bundleID: "com.openai.codex")
        #expect(ctx.category == .code)
    }

    @Test func claudeIsChat() {
        let ctx = AppContext.forTesting(appName: "Claude", bundleID: "com.anthropic.claude")
        #expect(ctx.category == .chat)
    }

    @Test func terminalIsTerminal() {
        let ctx = AppContext.forTesting(appName: "Terminal", bundleID: "com.apple.Terminal")
        #expect(ctx.category == .terminal)
    }

    @Test func warpIsTerminal() {
        let ctx = AppContext.forTesting(appName: "Warp", bundleID: "dev.warp.Warp-Stable")
        #expect(ctx.category == .terminal)
    }

    @Test func notionIsNotes() {
        let ctx = AppContext.forTesting(appName: "Notion", bundleID: "notion.id")
        #expect(ctx.category == .notes)
    }

    @Test func obsidianIsNotes() {
        let ctx = AppContext.forTesting(appName: "Obsidian", bundleID: "md.obsidian")
        #expect(ctx.category == .notes)
    }

    @Test func safariIsBrowser() {
        let ctx = AppContext.forTesting(appName: "Safari", bundleID: "com.apple.Safari")
        #expect(ctx.category == .browser)
    }

    @Test func arcIsBrowser() {
        let ctx = AppContext.forTesting(appName: "Arc", bundleID: "company.thebrowser.Browser")
        #expect(ctx.category == .browser)
    }

    @Test func unknownAppIsGeneric() {
        let ctx = AppContext.forTesting(appName: "MyCustomApp", bundleID: "com.example.myapp")
        #expect(ctx.category == .generic)
    }

    @Test func finderIsGeneric() {
        let ctx = AppContext.forTesting(appName: "Finder", bundleID: "com.apple.finder")
        #expect(ctx.category == .generic)
    }

    @Test func nilBundleIDFallsBackToAppName() {
        let ctx = AppContext.forTesting(appName: "Slack", bundleID: nil)
        #expect(ctx.category == .chat)
    }

    @Test func ghosttyIsTerminal() {
        let ctx = AppContext.forTesting(appName: "Ghostty", bundleID: "com.mitchellh.ghostty")
        #expect(ctx.category == .terminal)
    }

    @Test func lineIsChat() {
        let ctx = AppContext.forTesting(appName: "LINE", bundleID: "jp.naver.line.mac")
        #expect(ctx.category == .chat)
    }

    @Test func emailPriorityOverGeneric() {
        let ctx = AppContext.forTesting(appName: "Airmail", bundleID: "it.bloop.airmail2")
        #expect(ctx.category == .email)
    }

    @Test func fileURLIsNotSiteDomain() {
        #expect(AppContext.siteKeyForTesting(from: "file") == nil)
        #expect(AppContext.siteKeyForTesting(from: "file:///Users/kotatsu/test.html") == nil)
    }

    @Test func browserInternalURLIsNotSiteDomain() {
        #expect(AppContext.siteKeyForTesting(from: "chrome://new-tab-page") == nil)
    }

    @Test func regularDomainBecomesSiteDomain() {
        #expect(AppContext.siteKeyForTesting(from: "https://claude.ai/chat/abc") == "claude.ai")
        #expect(AppContext.siteKeyForTesting(from: "github.com/openai/codex") == "github.com")
    }

    @Test func desktopAppsDoNotCaptureSiteDomain() {
        #expect(AppContext.shouldCaptureSiteDomainForTesting(appName: "Claude", bundleID: "com.anthropic.claude") == false)
        #expect(AppContext.shouldCaptureSiteDomainForTesting(appName: "Codex", bundleID: "com.openai.codex") == false)
        #expect(AppContext.shouldCaptureSiteDomainForTesting(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap") == false)
    }

    @Test func browsersCaptureSiteDomain() {
        #expect(AppContext.shouldCaptureSiteDomainForTesting(appName: "Safari", bundleID: "com.apple.Safari") == true)
        #expect(AppContext.shouldCaptureSiteDomainForTesting(appName: "Google Chrome", bundleID: "com.google.Chrome") == true)
        #expect(AppContext.shouldCaptureSiteDomainForTesting(appName: "Comet", bundleID: "com.perplexity.Comet") == true)
    }
}
