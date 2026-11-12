import Foundation
import Testing

@testable import DevWidgetsCore

struct GitHubHostTests {
    static let ENTERPRISE = GitHubHost(text: "ghe.example.com")

    @Test(arguments: [
        ("", "github.com"),
        ("  GitHub.com ", "github.com"),
        ("https://GHE.example.com/", "ghe.example.com"),
        ("http://ghe.example.com/api/v3", "ghe.example.com"),
    ])
    func typedTextBecomesAHostName(text: String, name: String) {
        #expect(GitHubHost(text: text).name == name)
    }

    @Test func enterpriseAPILivesUnderAPIV3() {
        #expect(
            GitHubHost.PUBLIC.api_Base == "https://api.github.com/"
        )
        #expect(
            Self.ENTERPRISE.api_Base
                == "https://ghe.example.com/api/v3/"
        )
    }

    @Test(arguments: [
        "git@ghe.example.com:team/app.git",
        "ssh://git@ghe.example.com/team/app.git",
        "https://ghe.example.com/team/app",
    ])
    func enterpriseRemoteIsFound(remote: String) {
        let repository = GitRemoteParser.parseRepository(
            remote_URL: remote,
            host: Self.ENTERPRISE
        )
        #expect(
            repository == GitHubRepository(owner: "team", name: "app")
        )
    }

    @Test func otherHostIsNotTheProjectsGitHub() {
        let repository = GitRemoteParser.parseRepository(
            remote_URL: "git@github.com:team/app.git",
            host: Self.ENTERPRISE
        )
        #expect(repository == nil)
    }

    @Test func ghIsPointedAtTheEnterpriseHost() {
        let arguments = GhCommandTransport.makeArguments(
            path: "user",
            etag: nil,
            host: Self.ENTERPRISE
        )
        #expect(
            arguments == [
                "api", "-i", "--hostname", "ghe.example.com", "user",
            ]
        )
    }

    @Test func clientKnowsItsTransportsHost() {
        var transport = GhCommandTransport(
            runner: FakeCommandRunner(outputs: [:]),
            gh_URL: URL(fileURLWithPath: "/usr/bin/gh")
        )
        transport.host = Self.ENTERPRISE
        #expect(
            GitHubClient(transport: transport).host == Self.ENTERPRISE
        )
        let token_Transport = GitHubTransportChoice.choose(
            token: "t",
            host: Self.ENTERPRISE
        )
        #expect(token_Transport?.host == Self.ENTERPRISE)
    }

    @Test func enterpriseReviewRepositoryIsRead() {
        let repository = ReviewQueueParser.parseRepository(
            "https://ghe.example.com/api/v3/repos/team/app"
        )
        #expect(
            repository == GitHubRepository(owner: "team", name: "app")
        )
    }
}
