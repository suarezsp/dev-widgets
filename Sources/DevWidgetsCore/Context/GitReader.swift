import Foundation

/// Status of the one project folder the user chose.
public struct GitReader: Sendable {
    /// On macOS `/usr/bin/git` is a stub that pops up the Command
    /// Line Tools installer, so only real installs are searched.
    #if os(macOS)
    public static let DIRECTORIES = [
        "/opt/homebrew/bin", "/usr/local/bin",
        "/Library/Developer/CommandLineTools/usr/bin",
        "/Applications/Xcode.app/Contents/Developer/usr/bin",
    ]
    #else
    public static let DIRECTORIES = ["/usr/local/bin", "/usr/bin"]
    #endif

    public let runner: CommandRunner
    public let git_URL: URL?

    public init(
        runner: CommandRunner,
        git_URL: URL? = ExecutableSearch.locate(
            "git",
            in: DIRECTORIES
        )
    ) {
        self.runner = runner
        self.git_URL = git_URL
    }

    public func readState(project_URL: URL?) -> GitState {
        guard let project_URL else { return .not_Configured }
        guard let git_URL else { return .not_Installed }
        let project_Name = project_URL.lastPathComponent
        var command = Command(
            executable_URL: git_URL,
            arguments: GitStatusParser.ARGUMENTS
        )
        command.working_Directory = project_URL
        guard let status_Text = try? runner.run(command) else {
            return .not_A_Repository(project_Name: project_Name)
        }
        var status = Self.makeStatus(
            project_Name: project_Name,
            status_Text: status_Text
        )
        status.remote_URL = readRemoteURL(
            of: status.branch,
            in: project_URL
        )
        return .available(status: status)
    }

    static func makeStatus(
        project_Name: String,
        status_Text: String
    ) -> GitStatus {
        GitStatus(
            project_Name: project_Name,
            branch: GitStatusParser.parseBranch(
                status_Text: status_Text
            ),
            changes: GitStatusParser.parseChanges(
                status_Text: status_Text
            )
        )
    }

    /// The upstream's remote ("origin" in "origin/main"), or
    /// origin when the branch tracks nothing.
    func readRemoteURL(
        of branch: BranchStatus,
        in project_URL: URL
    ) -> String? {
        guard let git_URL else { return nil }
        let remote_Name =
            branch.upstream?.split(separator: "/").first
            .map(String.init) ?? "origin"
        var command = Command(
            executable_URL: git_URL,
            arguments: ["remote", "get-url", remote_Name]
        )
        command.working_Directory = project_URL
        let remote_Text = try? runner.run(command)
        return remote_Text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
