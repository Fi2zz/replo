import Foundation

/// WOD 种子的一条定义。`rounds` 只对 For Time 有意义，其余格式留 nil。
struct WodSeed {
    var name: String
    var format: WodFormat
    var capSeconds: Int
    var rounds: Int?
    var stations: [Station]
}

/// 附录 B 的 8 个 WOD。动作总量与 12-15 分钟封顶已按《WOD训练手册》四条硬规则核对过。
enum SeedWods {
    static func make() -> [Wod] {
        seeds.map(make)
    }

    private static func make(_ seed: WodSeed) -> Wod {
        Wod(
            name: seed.name,
            format: seed.format,
            timeCapSeconds: seed.capSeconds,
            rounds: seed.rounds,
            stations: seed.stations
        )
    }

    private static let seeds: [WodSeed] = [
        WodSeed(
            name: "WOD 1 · AMRAP 12", format: .amrap, capSeconds: 720, rounds: nil,
            stations: [reps("壶铃摆动", 8), reps("俯卧撑", 10), reps("自重深蹲", 15)]
        ),
        WodSeed(
            name: "WOD 2 · EMOM 12", format: .emom, capSeconds: 720, rounds: nil,
            stations: [reps("壶铃摆动", 15, .odd), seconds("战绳", 30, .even)]
        ),
        WodSeed(
            name: "WOD 3 · For Time 15", format: .forTime, capSeconds: 900, rounds: 5,
            stations: [reps("壶铃摆动", 10), seconds("战绳", 20), reps("俯卧撑", 10)]
        ),
        WodSeed(
            name: "WOD 4 · AMRAP 10", format: .amrap, capSeconds: 600, rounds: nil,
            stations: [reps("俯卧撑", 10), reps("单臂壶铃推举", 10), seconds("战绳", 30)]
        ),
        WodSeed(
            name: "WOD 5 · EMOM 10", format: .emom, capSeconds: 600, rounds: nil,
            stations: [reps("壶铃摆动", 12, .odd), seconds("平板支撑", 40, .even)]
        ),
        WodSeed(
            name: "WOD 6 · For Time 12", format: .forTime, capSeconds: 720, rounds: 3,
            stations: [reps("壶铃摆动", 15), reps("俯卧撑", 12), seconds("战绳", 20)]
        ),
        WodSeed(
            name: "WOD 7 · AMRAP 12", format: .amrap, capSeconds: 720, rounds: nil,
            stations: [reps("高脚杯深蹲", 8), reps("俯卧撑", 10), seconds("登山跑", 30)]
        ),
        WodSeed(
            name: "WOD 8 · Chipper 15", format: .chipper, capSeconds: 900, rounds: nil,
            stations: [reps("壶铃摆动", 40), reps("俯卧撑", 30), reps("高脚杯深蹲", 20), reps("俯卧撑", 10)]
        ),
    ]

    private static func reps(_ title: String, _ count: Int, _ parity: MinuteParity? = nil) -> Station {
        Station(title: title, reps: count, parity: parity)
    }

    private static func seconds(_ title: String, _ value: Int, _ parity: MinuteParity? = nil) -> Station {
        Station(title: title, durationSeconds: value, parity: parity)
    }
}
