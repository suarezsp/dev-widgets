import Foundation
import Testing
@testable import DevWidgetsCore

/// Docker fixtures are hand-written (no Docker on the build box).
struct DockerTests {
    static let DOCKER_URL = URL(fileURLWithPath: "/usr/bin/docker")

    @Test func psListsEveryContainerWithState() throws {
        let containers = DockerParser.parseContainers(
            ps_Text: try Fixtures.rootText("docker/ps.jsonl")
        )
        #expect(
            containers.map(\.identity.name) == [
                "api-db-1", "api-cache-1", "web-old",
            ]
        )
        #expect(containers.filter(\.is_Running).count == 2)
    }

    @Test func statsAddCPUAndMemoryToRunningOnes() throws {
        let measured = try readFixtureContainers()
        #expect(isClose(measured[0].cpu_Fraction, 0.0085))
        #expect(measured[0].memory_Bytes == 80_111_206)
        #expect(isClose(measured[1].cpu_Fraction, 1.523))
        #expect(measured[2].cpu_Fraction == nil)
    }

    @Test(
        arguments: [
            ("0B", 0), ("512kB", 512_000), ("9.5MiB", 9_961_472),
            ("1.5GB", 1_500_000_000),
        ] as [(String, UInt64)]
    )
    func sizesInDockerUnits(size_Text: String, expected_Bytes: UInt64)
    {
        #expect(UnitTextParser.parseSize(size_Text) == expected_Bytes)
    }

    @Test func unknownValuesAreNil() {
        #expect(UnitTextParser.parsePercent("--") == nil)
        #expect(UnitTextParser.parseSize("12 parsecs") == nil)
        #expect(UnitTextParser.parseSize("MiB") == nil)
    }

    @Test func missingCommandMeansNotInstalled() {
        let reader = DockerReader(
            runner: FakeCommandRunner(outputs: [:]),
            docker_URL: nil
        )
        #expect(reader.readState() == .not_Installed)
    }

    @Test func failingCommandMeansDaemonDown() {
        let reader = DockerReader(
            runner: FakeCommandRunner(outputs: [:]),
            docker_URL: Self.DOCKER_URL
        )
        #expect(reader.readState() == .not_Running)
    }

    @Test func statsAreSkippedWhenNothingRuns() throws {
        let stopped_Line =
            try Fixtures.rootText("docker/ps.jsonl")
            .split(separator: "\n").last.map(String.init) ?? ""
        let runner = FakeCommandRunner(outputs: ["ps": stopped_Line])
        let state = DockerReader(
            runner: runner,
            docker_URL: Self.DOCKER_URL
        ).readState()
        #expect(state.running_Containers.isEmpty)
        #expect(runner.run_Commands.count == 1)
    }

    func readFixtureContainers() throws -> [ContainerUsage] {
        let runner = FakeCommandRunner(outputs: [
            "ps": try Fixtures.rootText("docker/ps.jsonl"),
            "stats": try Fixtures.rootText("docker/stats.jsonl"),
        ])
        let state = DockerReader(
            runner: runner,
            docker_URL: Self.DOCKER_URL
        ).readState()
        guard case .available(let containers) = state else {
            return []
        }
        return containers
    }

    func isClose(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }
}
