import Testing
@testable import MemoRadarCore

@Suite struct WindowMatcherTests {
    private let folder = "/x/projeto-a"

    @Test func matchesFolderInTitle() {
        let titles = ["main.swift — projeto-b — Visual Studio Code", "main.swift — projeto-a — Visual Studio Code"]
        #expect(WindowMatcher.match(folder: folder, siblingFolders: [folder], titles: titles) == .unique(1))
    }

    @Test func matchesTitleWithoutFile() {
        #expect(WindowMatcher.match(folder: folder, siblingFolders: [], titles: ["projeto-a"]) == .unique(0))
    }

    @Test func matchesTitleWithUnsavedMark() {
        #expect(WindowMatcher.match(folder: folder, siblingFolders: [], titles: ["● main.swift — projeto-a"]) == .unique(0))
    }

    @Test func noMatchIsNone() {
        #expect(WindowMatcher.match(folder: folder, siblingFolders: [], titles: ["x — projeto-b"]) == .none)
    }

    @Test func sameFolderNameTwiceIsAmbiguous() {
        let titles = ["a — projeto-a", "b — projeto-a"]
        #expect(WindowMatcher.match(folder: folder, siblingFolders: [], titles: titles) == .ambiguous)
    }

    @Test func sameBasenameInOtherPathIsAmbiguous() {
        let siblings = ["/a/projeto-a", "/x/projeto-a"]
        #expect(WindowMatcher.match(folder: folder, siblingFolders: siblings, titles: ["a — projeto-a"]) == .ambiguous)
    }

    @Test func partialNameDoesNotMatch() {
        #expect(WindowMatcher.match(folder: folder, siblingFolders: [], titles: ["a — projeto-a2"]) == .none)
    }
}
