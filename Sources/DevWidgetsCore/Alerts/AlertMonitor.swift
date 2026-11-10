import Foundation

/// One notification to show.
public struct ThresholdAlert: Equatable, Sendable {
    public let rule: AlertRule
    public let value: Double
}

/// Where one reading stands against its limit. The gap between
/// the limit and the re-arm margin is `between`: still noisy.
public enum AlertCondition: Equatable, Sendable {
    case breached
    case between
    case recovered
}

extension AlertRule {
    public func classify(_ value: Double) -> AlertCondition {
        if isBreached(by: value) { return .breached }
        return isRecovered(by: value) ? .recovered : .between
    }
}

/// The two waits of the debounce.
public struct AlertTiming: Equatable, Sendable {
    /// How long a condition must last before it notifies.
    public let sustain_Seconds: Double
    /// Minimum time between two notifications of one tracker.
    public let cooldown_Seconds: Double

    public init(sustain_Seconds: Double, cooldown_Seconds: Double) {
        self.sustain_Seconds = sustain_Seconds
        self.cooldown_Seconds = cooldown_Seconds
    }
}

/// Debounce state of one metric or one branch's CI.
public struct AlertTracker: Equatable, Sendable {
    enum Phase: Equatable {
        case clear
        case breaching(since: Date)
        /// Fired; waits for the reading to recover.
        case alerted
    }

    private(set) var phase = Phase.clear
    private(set) var last_Alert_Date: Date?

    public init() {}

    /// True when this observation should notify.
    public mutating func update(
        _ condition: AlertCondition,
        at now: Date,
        timing: AlertTiming
    ) -> Bool {
        switch phase {
        case .clear:
            if condition == .breached {
                phase = .breaching(since: now)
                return fireIfDue(since: now, timing: timing, at: now)
            }
        case .breaching(let since):
            guard condition == .breached else {
                phase = .clear
                return false
            }
            return fireIfDue(since: since, timing: timing, at: now)
        case .alerted:
            if condition == .recovered { phase = .clear }
        }
        return false
    }

    private mutating func fireIfDue(
        since: Date,
        timing: AlertTiming,
        at now: Date
    ) -> Bool {
        let sustained_Seconds = now.timeIntervalSince(since)
        guard sustained_Seconds >= timing.sustain_Seconds else {
            return false
        }
        if let last_Alert_Date,
            now.timeIntervalSince(last_Alert_Date)
                < timing.cooldown_Seconds
        {
            return false
        }
        phase = .alerted
        last_Alert_Date = now
        return true
    }

    /// A metric that disappears (laptop plugged in) starts over;
    /// the cooldown still holds.
    public mutating func reset() {
        phase = .clear
    }

    /// Treats a condition found at start-up as already notified:
    /// a branch that was red before DevWidgets launched is news
    /// to nobody.
    public mutating func acknowledge() {
        phase = .alerted
    }
}

/// Feeds every reading to its tracker; owned by the sampling loop.
public struct AlertMonitor: Sendable {
    private var trackers: [AlertMetric: AlertTracker] = [:]

    public init() {}

    /// `now` is the sample's capture date.
    public mutating func evaluate(
        _ readings: MetricReadings,
        settings: AlertSettings,
        at now: Date
    ) -> [ThresholdAlert] {
        settings.rules.filter(\.is_Enabled).compactMap { rule in
            var tracker = trackers[rule.metric] ?? AlertTracker()
            defer { trackers[rule.metric] = tracker }
            guard let value = rule.metric.measure(readings) else {
                tracker.reset()
                return nil
            }
            let should_Notify = tracker.update(
                rule.classify(value),
                at: now,
                timing: settings.timing
            )
            return should_Notify
                ? ThresholdAlert(rule: rule, value: value) : nil
        }
    }
}
