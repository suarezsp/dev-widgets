import Foundation
import Testing
@testable import DevWidgetsCore

/// Git fixtures are real `git status` output from scratch repos.
struct GitTests {
    @Test func featureBranchStatusIsCounted() throws {
        let status_Text = try Fixtures.rootText(
            "git/status-feature-branch.txt"
        )
        let branch = GitStatusParser.parseBranch(
            status_Text: status_Text
        )
        #expect(branch.name == "feature/charts")
        #expect(branch.upstream == "origin/main")
        #expect(branch.ahead_Count == 3)
        #expect(branch.behind_Count == 1)
        #expect(branch.short_Commit_ID == "a195cf2")
        let changes = GitStatusParser.parseChanges(
            status_Text: status_Text
        )
        #expect(changes.staged == 2)
        #expect(changes.modified == 1)
        #expect(changes.conflicted == 1)
        #expect(changes.untracked == 1)
    }

    @Test func detachedHeadHasNoBranchName() throws {
        let status_Text = try Fixtures.rootText(
            "git/status-detached-clean.txt"
        )
        let branch = GitStatusParser.parseBranch(
            status_Text: status_Text
        )
        #expect(branch.name == nil)
        #expect(branch.upstream == nil)
        let changes = GitStatusParser.parseChanges(
            status_Text: status_Text
        )
        #expect(changes.is_Clean)
    }

    @Test func noFolderMeansNotConfigured() {
        let reader = GitReader(
            runner: FakeCommandRunner(outputs: [:])
        )
        #expect(reader.readState(project_URL: nil) == .not_Configured)
    }

    @Test func realRepositoryIsRead() throws {
        let project_URL = try GitSandbox.makeRepository()
        let state = GitReader(runner: ProcessCommandRunner())
            .readState(project_URL: project_URL)
        guard case .available(let status) = state else {
            Issue.record("expected a status, got \(state)")
            return
        }
        #expect(status.project_Name == project_URL.lastPathComponent)
        #expect(status.branch.name == "main")
        #expect(status.changes.untracked == 1)
    }

    @Test func readerFindsOriginRemote() throws {
        let project_URL = try GitSandbox.makeRepository()
        try GitSandbox.runGit(
            [
                "remote", "add", "origin",
                "git@github.com:acme/api.git",
            ],
            in: project_URL
        )
        let state = GitReader(runner: ProcessCommandRunner())
            .readState(project_URL: project_URL)
        guard case .available(let status) = state else {
            Issue.record("expected a status, got \(state)")
            return
        }
        #expect(status.remote_URL == "git@github.com:acme/api.git")
    }

    @Test func plainFolderIsNotARepository() throws {
        let folder_URL = try GitSandbox.makeFolder()
        let state = GitReader(runner: ProcessCommandRunner())
            .readState(project_URL: folder_URL)
        #expect(
            state
                == .not_A_Repository(
                    project_Name: folder_URL.lastPathComponent
                )
        )
    }
}

/// Scratch folders in the temporary directory, made with real git.
enum GitSandbox {
    static func makeFolder() throws -> URL {
        let folder_URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "devwidgets-git-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: folder_URL,
            withIntermediateDirectories: true
        )
        return folder_URL
    }

    static func makeRepository() throws -> URL {
        let folder_URL = try makeFolder()
        try runGit(
            ["init", "--quiet", "--initial-branch=main"],
            in: folder_URL
        )
        try Data("draft".utf8).write(
            to: folder_URL.appendingPathComponent("notes.md")
        )
        return folder_URL
    }

    static func runGit(
        _ arguments: [String],
        in folder_URL: URL
    ) throws {
        let git_URL = try #require(
            ExecutableSearch.locate("git", in: GitReader.DIRECTORIES)
        )
        var command = Command(
            executable_URL: git_URL,
            arguments: arguments
        )
        command.working_Directory = folder_URL
        _ = try ProcessCommandRunner().run(command)
    }
}
