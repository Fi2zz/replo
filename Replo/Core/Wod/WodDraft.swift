import Foundation

/// 站点编辑草稿。`kind` 决定读 `repsText` 还是 `secondsText`；`parity` 只对 EMOM 有意义。
struct StationDraft: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Sendable {
        case reps
        case seconds

        var title: String {
            self == .reps ? "次数" : "秒数"
        }
    }

    var id: UUID = UUID()
    var title: String = ""
    var kind: Kind = .reps
    var repsText: String = ""
    var secondsText: String = ""
    var parity: MinuteParity = .odd

    init() {}

    init(station: Station) {
        title = station.title
        parity = station.parity ?? .odd
        if let reps = station.reps {
            kind = .reps
            repsText = "\(reps)"
        } else {
            kind = .seconds
            secondsText = station.durationSeconds.map { "\($0)" } ?? ""
        }
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespaces)
    }

    var parsedValue: Int? {
        let text = kind == .reps ? repsText : secondsText
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    var failureReason: String? {
        if trimmedTitle.isEmpty { return "站点名称不能为空" }
        if parsedValue == nil { return kind == .reps ? "「次数」需为正整数" : "「秒数」需为正整数" }
        return nil
    }

    /// 非 EMOM 的站点不存 parity，与种子数据保持一致。
    func makeStation(emom: Bool) -> Station? {
        guard let value = parsedValue else { return nil }
        let minuteParity: MinuteParity? = emom ? parity : nil
        switch kind {
        case .reps:
            return Station(title: trimmedTitle, reps: value, parity: minuteParity)
        case .seconds:
            return Station(title: trimmedTitle, durationSeconds: value, parity: minuteParity)
        }
    }
}

/// WOD 编辑草稿。表单只编辑这份纯值拷贝，保存时才落成或写回 `Wod`，取消不留痕。
struct WodDraft: Equatable {
    var name: String = ""
    var format: WodFormat = .amrap
    var capMinutes: Int = 12
    var rounds: Int = 5
    var stations: [StationDraft] = [StationDraft(), StationDraft(), StationDraft()]

    init() {}

    init(wod: Wod) {
        name = wod.name
        format = wod.format
        capMinutes = wod.timeCapSeconds / 60
        rounds = wod.rounds ?? 5
        stations = wod.stations.map { StationDraft(station: $0) }
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var failureReasons: [String] {
        nameReasons + capReasons + stationReasons + formatReasons
    }

    /// 追加一个空站点，EMOM 的奇偶分钟按序交替填好。
    mutating func appendStation() {
        var station = StationDraft()
        station.parity = stations.count % 2 == 0 ? .odd : .even
        stations.append(station)
    }

    /// 调用前先确认 `failureReasons` 为空。
    func makeWod() -> Wod {
        precondition(failureReasons.isEmpty, "草稿未通过校验：\(failureReasons)")
        return Wod(
            name: trimmedName,
            format: format,
            timeCapSeconds: capMinutes * 60,
            rounds: format == .forTime ? rounds : nil,
            stations: stations.compactMap { $0.makeStation(emom: format == .emom) },
            isCustom: true
        )
    }

    /// 编辑保存路径：写回现有实例，不动 `id` 与 `isCustom`。
    func applyTo(_ wod: Wod) {
        wod.name = trimmedName
        wod.format = format
        wod.timeCapSeconds = capMinutes * 60
        wod.rounds = format == .forTime ? rounds : nil
        wod.stations = stations.compactMap { $0.makeStation(emom: format == .emom) }
    }

    private var nameReasons: [String] {
        trimmedName.isEmpty ? ["名称不能为空"] : []
    }

    private var capReasons: [String] {
        (5...30).contains(capMinutes) ? [] : ["时间封顶需在 5-30 分钟之间"]
    }

    private var stationReasons: [String] {
        if stations.isEmpty { return ["至少添加一个站点"] }
        return stations.lazy.compactMap(\.failureReason).first.map { [$0] } ?? []
    }

    private var formatReasons: [String] {
        format == .forTime && rounds < 1 ? ["For Time 至少 1 轮"] : []
    }
}
