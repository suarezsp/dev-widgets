import Foundation
import Testing
@testable import DevWidgetsCore

struct AlertTrackerTests {
    static let START = Date(timeIntervalSinceReferenceDate: 0)
    static let CPU_RULE = AlertRule(
        metric: .cpu,
        limit: 0.9,
        is_Enabled: true
    )

    /// Feeds one value per listed second; returns the alert times.
    static func feed(
        _ values: [Double],
        rule: AlertRule = CPU_RULE,
        timing: AlertSettings = .DEFAULT
    ) -> [Int] {
        var tracker = AlertTracker()
        return values.enumerated().compactMap { second, value in
            let fired = tracker.update(
                rule.classify(value),
                at: START.addingTimeInterval(Double(second)),
                timing: timing.timing
            )
            return fired ? second : nil
        }
    }

    @Test func shortSpikeNeverAlerts() {
        let values = Array(repeating: 0.99, count: 29) + [0.2]
        #expect(Self.feed(values).isEmpty)
    }

    @Test func sustainedLoadAlertsOnceAfterThirtySeconds() {
        let values = Array(repeating: 0.95, count: 120)
        #expect(Self.feed(values) == [30])
    }

    @Test func hoveringAtLimitDoesNotRearm() {
        let busy = Array(repeating: 0.95, count: 40)
        let hovering = (0..<600).map { $0 % 2 == 0 ? 0.95 : 0.88 }
        #expect(Self.feed(busy + hovering) == [30])
    }

    @Test func recoveryAndCooldownAllowSecondAlert() {
        var timing = AlertSettings.DEFAULT
        timing.cooldown_Seconds = 100
        let busy = Array(repeating: 0.95, count: 40)
        let calm = Array(repeating: 0.5, count: 10)
        let values = busy + calm + busy + calm + busy
        #expect(Self.feed(values, timing: timing) == [30, 130])
    }

    @Test func batteryAlertsBelowLimit() {
        let rule = AlertRule(
            metric: .battery,
            limit: 0.1,
            is_Enabled: true
        )
        var timing = AlertSettings.DEFAULT
        timing.sustain_Seconds = 0
        #expect(
            Self.feed(
                [0.3, 0.12, 0.09, 0.08],
                rule: rule,
                timing: timing
            ) == [2]
        )
    }
}

struct AlertMonitorTests {
    /// Idle ticks do not move, so any busy ticks mean 100 % CPU.
    static func makeReadings(busy_Ticks: UInt64) -> MetricReadings {
        let interval = SampleFactory.makeInterval(
            from: SampleFactory.makeSample(
                busy_Ticks: 0,
                received_Bytes: 0,
                read_Bytes: nil
            ),
            to: SampleFactory.makeSample(
                busy_Ticks: busy_Ticks,
                received_Bytes: 0,
                read_Bytes: nil
            ),
            elapsed_Seconds: 1
        )
        return MetricReadings(over: interval)
    }

    @Test func monitorSkipsDisabledAndMissingMetrics() {
        var settings = AlertSettings.DEFAULT
        settings.sustain_Seconds = 0
        settings.rules[0].is_Enabled = false
        var monitor = AlertMonitor()
        // CPU is at 100 %, but its rule is off.
        let alerts = monitor.evaluate(
            Self.makeReadings(busy_Ticks: 9_000),
            settings: settings,
            at: Date()
        )
        // Memory is 8 of 16 GB; the sample has no battery or heat.
        #expect(alerts.isEmpty)
    }

    @Test func monitorAlertsWithMessage() throws {
        var settings = AlertSettings.DEFAULT
        settings.sustain_Seconds = 0
        var monitor = AlertMonitor()
        let alerts = monitor.evaluate(
            Self.makeReadings(busy_Ticks: 500),
            settings: settings,
            at: Date()
        )
        let alert = try #require(alerts.first)
        let message = AlertMessage(alert: alert, settings: settings)
        #expect(alert.rule.metric == .cpu)
        #expect(message.title == "CPU at 100%")
        #expect(
            message.body == "Over your 90% limit for at least 0 s."
        )
    }

    @Test func settingsSurviveJSON() throws {
        var settings = AlertSettings.DEFAULT
        settings.rules[1].limit = 0.8
        let encoded_Data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            AlertSettings.self,
            from: encoded_Data
        )
        #expect(decoded == settings)
        #expect(decoded.rule(for: .memory)?.limit == 0.8)
    }
}

struct CIFailureMonitorTests {
    static let START = Date(timeIntervalSinceReferenceDate: 0)

    static func makeState(_ outcome: CheckOutcome) -> GitHubState {
        var run = WorkflowRunSummary(
            run_ID: 7,
            workflow_Name: "Tests",
            outcome: outcome
        )
        run.page_URL = URL(string: "https://github.com/a/b/runs/7")
        return .available(
            status: GitHubStatus(
                repository: GitHubRepository(owner: "a", name: "b"),
                branch_Name: "main",
                runs: [run]
            )
        )
    }

    /// One outcome per minute; returns the minutes that notified.
    static func feed(_ outcomes: [CheckOutcome]) -> [Int] {
        var monitor = CIFailureMonitor()
        return outcomes.enumerated().compactMap { minute, outcome in
            let alert = monitor.evaluate(
                makeState(outcome),
                at: START.addingTimeInterval(Double(minute) * 60)
            )
            return alert == nil ? nil : minute
        }
    }

    @Test func redAtLaunchIsNotNews() {
        #expect(Self.feed([.failure, .failure, .failure]).isEmpty)
    }

    @Test func greenThenRedNotifiesOnce() {
        #expect(Self.feed([.success, .failure, .failure]) == [1])
    }

    @Test func newRunFailingAgainWaitsForCooldown() {
        let outcomes: [CheckOutcome] = [
            .success, .failure, .pending, .failure, .pending,
            .pending, .pending, .failure,
        ]
        #expect(Self.feed(outcomes) == [1, 7])
    }

    @Test func cancelledRunDoesNotRearm() {
        let outcomes: [CheckOutcome] = [
            .success, .failure, .cancelled, .cancelled, .cancelled,
            .cancelled, .cancelled, .failure,
        ]
        #expect(Self.feed(outcomes) == [1])
    }

    @Test func alertNamesBranchWorkflowAndPage() throws {
        var monitor = CIFailureMonitor()
        _ = monitor.evaluate(Self.makeState(.success), at: Self.START)
        let failure_Alert = monitor.evaluate(
            Self.makeState(.failure),
            at: Self.START
        )
        let alert = try #require(failure_Alert)
        #expect(alert.message.title == "CI failed on main")
        #expect(alert.message.body == "Tests · a/b")
        #expect(alert.identifier == "ci.a/b#main")
        #expect(alert.page_URL?.lastPathComponent == "7")
    }

    @Test func otherStatesAreIgnored() {
        var monitor = CIFailureMonitor()
        #expect(
            monitor.evaluate(.no_Credentials, at: Self.START) == nil
        )
    }
}

struct AlertSettingsCodingTests {
    @Test func olderSettingsKeepLimitsAndGainDefaults() throws {
        let json_Text = """
            {"rules": [{"metric": "cpu", "limit": 0.75,
              "is_Enabled": true}], "sustain_Seconds": 10}
            """
        let settings = try JSONDecoder().decode(
            AlertSettings.self,
            from: Data(json_Text.utf8)
        )
        #expect(settings.rule(for: .cpu)?.limit == 0.75)
        #expect(settings.sustain_Seconds == 10)
        #expect(settings.cooldown_Seconds == 900)
        #expect(settings.notifies_CI_Failure)
    }
}
