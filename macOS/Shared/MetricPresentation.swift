import DevWidgetsCore
import Foundation

/// Display-ready texts and values for one metric.
public struct MetricPresentation: Equatable {
    public static let UNAVAILABLE_VALUE_TEXT = "—"

    public let kind: MetricKind
    public let value_Text: String
    public let detail_Text: String
    /// Gauge fill in 0...1; nil for rates, which have no maximum.
    public private(set) var fraction: Double?
    public private(set) var level = LoadLevel.normal
    /// False for machines without the sensor, e.g. a desktop's
    /// battery. Set explicitly, never inferred from the text.
    public private(set) var is_Available = true

    public init(
        kind: MetricKind,
        value_Text: String,
        detail_Text: String
    ) {
        self.kind = kind
        self.value_Text = value_Text
        self.detail_Text = detail_Text
    }

    public static func makeUnavailable(
        _ kind: MetricKind
    ) -> MetricPresentation {
        var unavailable = MetricPresentation(
            kind: kind,
            value_Text: UNAVAILABLE_VALUE_TEXT,
            detail_Text: String(localized: "Not available")
        )
        unavailable.is_Available = false
        return unavailable
    }

    public var title: String { kind.title }
    public var symbol_Name: String { kind.symbol_Name }

    public func with(level: LoadLevel, fraction: Double?) -> Self {
        var graded = self
        graded.level = level
        graded.fraction = fraction
        return graded
    }
}

extension MetricKind {
    public static func presentShare(
        _ kind: MetricKind,
        fraction: Double,
        detail_Text: String
    ) -> MetricPresentation {
        MetricPresentation(
            kind: kind,
            value_Text: MetricFormatting.describePercent(
                fraction: fraction
            ),
            detail_Text: detail_Text
        )
        .with(
            level: LoadThresholds.DEFAULT.level(for: fraction),
            fraction: fraction
        )
    }

    public static func presentCPU(
        _ cpu: CPUUsage
    ) -> MetricPresentation {
        presentShare(
            .cpu,
            fraction: cpu.total_Fraction,
            detail_Text: String(
                localized: "\(cpu.core_Fractions.count) cores"
            )
        )
    }

    /// Graded by memory pressure, not by share: a Mac full of
    /// cache is healthy.
    public static func presentMemory(
        _ memory: MemoryUsage
    ) -> MetricPresentation {
        let physical = memory.physical
        let used_Text = MetricFormatting.describe(
            bytes: Double(physical.used_Bytes)
        )
        let total_Text = MetricFormatting.describe(
            bytes: Double(physical.total_Bytes)
        )
        return MetricPresentation(
            kind: .memory,
            value_Text: MetricFormatting.describePercent(
                fraction: physical.used_Fraction
            ),
            detail_Text: String(
                localized: "\(used_Text) of \(total_Text)"
            )
        )
        .with(
            level: memory.pressure,
            fraction: physical.used_Fraction
        )
    }

    public static func presentDisk(
        _ disk: DiskUsage
    ) -> MetricPresentation {
        let free_Text = MetricFormatting.describe(
            bytes: Double(disk.space.free_Bytes)
        )
        return presentShare(
            .disk,
            fraction: disk.space.used_Fraction,
            detail_Text: String(localized: "\(free_Text) free")
        )
    }

    public static func presentNetwork(
        _ network: NetworkThroughput
    ) -> MetricPresentation {
        let download_Text = MetricFormatting.describeRate(
            bytes_Per_Second: network.download_Bytes_Per_Second
        )
        let upload_Text = MetricFormatting.describeRate(
            bytes_Per_Second: network.upload_Bytes_Per_Second
        )
        return MetricPresentation(
            kind: .network,
            value_Text: "↓ \(download_Text)",
            detail_Text: "↑ \(upload_Text)"
        )
    }
}
