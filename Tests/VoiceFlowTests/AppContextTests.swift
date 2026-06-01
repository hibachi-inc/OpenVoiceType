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
}
