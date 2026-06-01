import Testing
@testable import VoiceFlowRefiner

@Suite("SimpleRefiner")
struct SimpleRefinerTests {

    // MARK: - English filler removal

    @Test func englishFillerRemoval() {
        let result = SimpleRefiner.clean("I um think uh this is like good")
        #expect(!result.contains("um"))
        #expect(!result.contains("uh"))
        #expect(!result.contains("like"))
        #expect(result.contains("think"))
        #expect(result.contains("good"))
    }

    @Test func englishFillerCaseInsensitive() {
        let result = SimpleRefiner.clean("Um I think Actually this")
        #expect(!result.lowercased().contains("actually"))
    }

    @Test func englishFillerWordBoundary() {
        let result = SimpleRefiner.clean("summary of the document")
        #expect(result.contains("summary"))
    }

    // MARK: - Japanese filler removal

    @Test func japaneseFillerRemoval() {
        let result = SimpleRefiner.clean("えーと、今日はいい天気ですね")
        #expect(!result.contains("えーと"))
        #expect(result.contains("今日"))
    }

    @Test func japaneseFillerAtStart() {
        let result = SimpleRefiner.clean("えーと始めます")
        #expect(result.contains("始めます"))
    }

    // MARK: - Boundary safety

    @Test func plainTextWithoutFillersUnchanged() {
        let input = "今日の会議は3時から"
        let result = SimpleRefiner.clean(input)
        #expect(result == input)
    }

    @Test func englishPlainTextUnchanged() {
        let input = "The meeting starts at 3pm"
        let result = SimpleRefiner.clean(input)
        #expect(result == input)
    }

    // MARK: - Edge cases

    @Test func emptyInputReturnsOriginal() {
        let result = SimpleRefiner.clean("")
        #expect(result == "")
    }

    @Test func onlyEnglishFillersReturnsOriginal() {
        let result = SimpleRefiner.clean("um uh like")
        #expect(!result.isEmpty)
    }

    @Test func whitespaceNormalization() {
        let result = SimpleRefiner.clean("hello   world")
        #expect(!result.contains("  "))
    }

    @Test func trimmingWhitespace() {
        let result = SimpleRefiner.clean("  hello world  ")
        #expect(!result.hasPrefix(" "))
        #expect(!result.hasSuffix(" "))
    }
}
