public enum IconState: Sendable, Equatable {
    case normal, attention, critical

    public static func compute(pressure: MemoryPressure, hasForgotten: Bool) -> IconState {
        if pressure == .critical { return .critical }
        if pressure == .warning || hasForgotten { return .attention }
        return .normal
    }
}
