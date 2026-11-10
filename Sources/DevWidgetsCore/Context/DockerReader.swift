import Foundation

/// Lists containers with the `docker` command. It works the same
/// with Docker Desktop, Colima or OrbStack, because they all serve
/// the CLI's current context.
public struct DockerReader: Sendable {
    public let runner: CommandRunner
    public let docker_URL: URL?

    public init(
        runner: CommandRunner,
        docker_URL: URL? = ExecutableSearch.locate("docker")
    ) {
        self.runner = runner
        self.docker_URL = docker_URL
    }

    public func readState() -> DockerState {
        guard let docker_URL else { return .not_Installed }
        let ps_Command = Command(
            executable_URL: docker_URL,
            arguments: [
                "ps", "--all", "--format", DockerParser.JSON_FORMAT,
            ]
        )
        guard let ps_Text = try? runner.run(ps_Command) else {
            return .not_Running
        }
        let containers = DockerParser.parseContainers(
            ps_Text: ps_Text
        )
        return .available(containers: measureRunning(containers))
    }

    /// `docker stats --no-stream` takes about two seconds, so it is
    /// skipped when nothing runs.
    func measureRunning(
        _ containers: [ContainerUsage]
    ) -> [ContainerUsage] {
        guard let docker_URL, containers.contains(where: \.is_Running)
        else { return containers }
        let stats_Command = Command(
            executable_URL: docker_URL,
            arguments: [
                "stats", "--no-stream", "--format",
                DockerParser.JSON_FORMAT,
            ]
        )
        guard let stats_Text = try? runner.run(stats_Command) else {
            return containers
        }
        return DockerParser.addUsage(
            stats_Text: stats_Text,
            to: containers
        )
    }
}
