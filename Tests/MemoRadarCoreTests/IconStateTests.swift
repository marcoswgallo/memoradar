import Testing
@testable import MemoRadarCore

@Suite struct IconStateTests {
    @Test("ícone", arguments: [
        (MemoryPressure.critical, false, IconState.critical),
        (.critical, true, .critical),
        (.warning, false, .attention),
        (.warning, true, .attention),
        (.normal, true, .attention),
        (.normal, false, .normal),
        (.unknown, false, .normal),
        (.unknown, true, .attention),
    ] as [(MemoryPressure, Bool, IconState)])
    func compute(pressure: MemoryPressure, forgotten: Bool, expected: IconState) {
        #expect(IconState.compute(pressure: pressure, hasForgotten: forgotten) == expected)
    }
}
