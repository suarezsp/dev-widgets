/// Which container, independent of its state.
public struct ContainerIdentity: Codable, Hashable, Sendable {
    public let container_ID: String
    public let name: String
    public let image: String

    public init(container_ID: String, name: String, image: String) {
        self.container_ID = container_ID
        self.name = name
        self.image = image
    }
}

/// One container and, when it is running, what it consumes.
public struct ContainerUsage: Codable, Equatable, Sendable {
    public let identity: ContainerIdentity
    /// Docker's state word: running, exited, paused, restarting...
    public let state: String
    /// 1.0 = one full core, as `docker stats` reports it.
    public var cpu_Fraction: Double?
    public var memory_Bytes: UInt64?

    public init(identity: ContainerIdentity, state: String) {
        self.identity = identity
        self.state = state
    }

    public var is_Running: Bool { state == "running" }
}

/// What the developer-context widget can say about Docker.
public enum DockerState: Codable, Equatable, Sendable {
    /// No `docker` command on this machine.
    case not_Installed
    /// The command exists but no daemon (Docker Desktop, Colima,
    /// OrbStack...) answers.
    case not_Running
    case available(containers: [ContainerUsage])
}

extension DockerState {
    public var running_Containers: [ContainerUsage] {
        guard case .available(let containers) = self else {
            return []
        }
        return containers.filter(\.is_Running)
    }

    /// Running containers, busiest first, as the widgets list them.
    public func listBusiest(limit: Int) -> [ContainerUsage] {
        let sorted_Containers = running_Containers.sorted {
            ($0.cpu_Fraction ?? 0) > ($1.cpu_Fraction ?? 0)
        }
        return Array(sorted_Containers.prefix(limit))
    }
}
