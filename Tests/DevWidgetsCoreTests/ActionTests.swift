import Foundation
import Testing
@testable import DevWidgetsCore

struct ActionInboxTests {
    static let DATABASE = ContainerIdentity(
        container_ID: "3f1c2a9b7d10",
        name: "api-db-1",
        image: "postgres:16"
    )

    @Test func postedActionsDrainOnceInOrder() throws {
        let inbox = ActionInbox(
            container_URL: try GitSandbox.makeFolder()
        )
        try inbox.post(.stop_Container(container: Self.DATABASE))
        Thread.sleep(forTimeInterval: 0.02)
        try inbox.post(.open_Project)
        #expect(
            inbox.drain()
                == [
                    .stop_Container(container: Self.DATABASE),
                    .open_Project,
                ]
        )
        #expect(inbox.drain().isEmpty)
    }

    @Test func staleRequestsAreDropped() throws {
        let inbox = ActionInbox(
            container_URL: try GitSandbox.makeFolder()
        )
        try inbox.post(.open_Project)
        let much_Later = Date().addingTimeInterval(
            ActionInbox.MAX_AGE_SECONDS + 1
        )
        #expect(inbox.drain(at: much_Later).isEmpty)
        #expect(inbox.listRequestFiles().isEmpty)
    }
}

struct ConfirmationGateTests {
    static let STOP = WidgetAction.stop_Container(
        container: ActionInboxTests.DATABASE
    )

    @Test func secondTapConfirms() throws {
        let gate = ConfirmationGate(
            container_URL: try GitSandbox.makeFolder()
        )
        let now = Date()
        #expect(try !gate.confirm(Self.STOP, at: now))
        #expect(gate.readArmedAction(at: now) == Self.STOP)
        #expect(
            try gate.confirm(Self.STOP, at: now.addingTimeInterval(3))
        )
        #expect(gate.readArmedAction(at: now) == nil)
    }

    @Test func lateOrDifferentTapArmsAgain() throws {
        let gate = ConfirmationGate(
            container_URL: try GitSandbox.makeFolder()
        )
        let now = Date()
        let quit_Node = WidgetAction.terminate_Process(
            process: ProcessIdentity(pid: 812, name: "node")
        )
        _ = try gate.confirm(Self.STOP, at: now)
        #expect(try !gate.confirm(quit_Node, at: now))
        let too_Late = now.addingTimeInterval(
            ConfirmationGate.WINDOW_SECONDS + 1
        )
        #expect(try !gate.confirm(quit_Node, at: too_Late))
    }

    @Test func openingProjectNeedsNoConfirmation() throws {
        let gate = ConfirmationGate(
            container_URL: try GitSandbox.makeFolder()
        )
        #expect(try gate.confirm(.open_Project))
    }
}

/// A real child that sleeps, and how the system names it.
enum Sleeper {
    #if os(macOS)
    static let EXECUTABLE_PATH = "/bin/sleep"
    static let ARGUMENTS = ["30"]
    static let NAME = "sleep"
    #else
    // The Linux test runner starts children with SIGTERM
    // blocked, so Python unblocks it first, as any normally
    // launched program has it.
    static let EXECUTABLE_PATH = "/usr/bin/python3"
    static let ARGUMENTS = [
        "-c",
        "import signal, time; "
            + "signal.pthread_sigmask(signal.SIG_UNBLOCK, "
            + "[signal.SIGTERM]); time.sleep(30)",
    ]
    static let NAME = "python3"
    #endif

    static func start() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: EXECUTABLE_PATH)
        process.arguments = ARGUMENTS
        try process.run()
        return process
    }

    /// The name the app's own reader would give.
    static func readName(of process_ID: Int32) -> String? {
        #if os(macOS)
        var name_Buffer = [CChar](repeating: 0, count: 64)
        let length = proc_name(
            process_ID,
            &name_Buffer,
            UInt32(name_Buffer.count)
        )
        return length > 0 ? stringFromCBuffer(name_Buffer) : nil
        #else
        LinuxProcessReader.readName(of: process_ID)
        #endif
    }
}

struct ActionPerformerTests {
    static let TERMINATOR = ProcessTerminator { process_ID in
        Sleeper.readName(of: process_ID)
    }

    @Test func terminatesRealProcessWithSigterm() throws {
        let process = try Sleeper.start()
        let identity = ProcessIdentity(
            pid: process.processIdentifier,
            name: Sleeper.NAME
        )
        #expect(Self.TERMINATOR.terminate(identity) == .done)
        process.waitUntilExit()
        #expect(process.terminationReason == .uncaughtSignal)
        #expect(process.terminationStatus == SIGTERM)
    }

    @Test func reusedPidIsLeftAlone() throws {
        let process = try Sleeper.start()
        defer { process.terminate() }
        let stale_Identity = ProcessIdentity(
            pid: process.processIdentifier,
            name: "node"
        )
        let outcome = Self.TERMINATOR.terminate(stale_Identity)
        #expect(outcome == .refused(reason: "node already quit"))
        #expect(process.isRunning)
    }

    @Test func appsAreAskedToQuitBeforeAnySignal() throws {
        let process = try Sleeper.start()
        defer { process.terminate() }
        let terminator = ProcessTerminator(
            name_Lookup: { Sleeper.readName(of: $0) },
            app_Quitter: { _ in true }
        )
        let identity = ProcessIdentity(
            pid: process.processIdentifier,
            name: Sleeper.NAME
        )
        #expect(terminator.terminate(identity) == .done)
        #expect(process.isRunning)
    }

    @Test func otherUsersProcessesSayWhyTheyCannotQuit() {
        let outcome = ProcessTerminator.describeSignalError(
            EPERM,
            name: "sshd"
        )
        #expect(
            outcome
                == .failed(
                    reason: "sshd is not your process: only your own"
                        + " processes can be quit"
                )
        )
    }

    @Test func protectedProcessesAreRefused() {
        let own_Identity = ProcessIdentity(
            pid: ProcessInfo.processInfo.processIdentifier,
            name: "devwidgets"
        )
        let init_Identity = ProcessIdentity(pid: 1, name: "init")
        #expect(
            Self.TERMINATOR.terminate(own_Identity)
                == .refused(reason: "Protected process")
        )
        #expect(
            Self.TERMINATOR.terminate(init_Identity)
                == .refused(reason: "Protected process")
        )
    }

    static func makeController(
        _ runner: FakeCommandRunner
    ) -> ContainerController {
        ContainerController(
            runner: runner,
            docker_URL: URL(fileURLWithPath: "/usr/bin/docker")
        )
    }

    @Test(arguments: ["stop", "restart"])
    func controllerRunsDockerWithLongTimeout(
        verb: String
    ) async throws {
        let runner = FakeCommandRunner(outputs: [verb: "3f1c2a9b\n"])
        let controller = Self.makeController(runner)
        let outcome =
            verb == "stop"
            ? await controller.stop(ActionInboxTests.DATABASE)
            : await controller.restart(ActionInboxTests.DATABASE)
        #expect(outcome == .done)
        let command = try #require(runner.run_Commands.first)
        #expect(
            command.arguments == [
                verb, "--time", "10", "3f1c2a9b7d10",
            ]
        )
        #expect(command.timeout_Seconds == 30)
    }

    @Test func controllerReportsDockerErrorsAndAbsence() async {
        let failing = Self.makeController(
            FakeCommandRunner(outputs: [:])
        )
        let missing = ContainerController(
            runner: FakeCommandRunner(outputs: [:]),
            docker_URL: nil
        )
        #expect(
            await failing.restart(ActionInboxTests.DATABASE)
                == .failed(reason: "fake")
        )
        #expect(
            await missing.stop(ActionInboxTests.DATABASE)
                == .failed(reason: "Docker not found")
        )
    }

    @Test func restartNeedsConfirmation() {
        let action = WidgetAction.restart_Container(
            container: ActionInboxTests.DATABASE
        )
        #expect(action.needs_Confirmation)
        #expect(action.title == "Restart api-db-1")
    }
}
