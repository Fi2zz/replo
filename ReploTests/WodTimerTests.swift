import Foundation
import Testing

@testable import Replo

@Suite("WOD 计时状态机")
struct WorkoutTimerModelTests {
    private func model(
        _ format: WodFormat,
        cap: Int = 600,
        stations: Int = 0,
        rounds: Int? = nil
    ) -> WorkoutTimerModel {
        let wod = Wod(
            name: "T",
            format: format,
            timeCapSeconds: cap,
            rounds: rounds,
            stations: (0..<stations).map { Station(title: "S\($0)", reps: 10) }
        )
        return WorkoutTimerModel(wod: wod)
    }

    @Test("AMRAP：倒计时到 cap 结束并锁住轮数")
    func amrapCountsDownAndLocks() {
        var timer = model(.amrap, cap: 720)
        timer.start()

        #expect(timer.remaining == 720)
        timer.advance(to: 719)
        #expect(timer.remaining == 1)
        timer.addRound()
        #expect(timer.rounds == 1)

        #expect(timer.advance(to: 720) == .end)
        #expect(timer.phase == .finished)
        #expect(timer.remaining == 0)

        timer.addRound()
        #expect(timer.rounds == 1, "到点后成绩锁定")
        #expect(timer.cappedOut == false, "AMRAP 自由轮数，不判未完成")
    }

    @Test("EMOM：分钟序号递增，跨整分给提示")
    func emomMinutesAdvance() {
        var timer = model(.emom, cap: 720)
        timer.start()

        #expect(timer.minute == 1)
        #expect(timer.advance(to: 59) == .none)
        #expect(timer.advance(to: 60) == .minute)
        #expect(timer.minute == 2)
        #expect(timer.advance(to: 119) == .none)
        #expect(timer.advance(to: 120) == .minute)
        #expect(timer.minute == 3)
    }

    @Test("EMOM：12 分钟里 11 次分钟提示，最后一次是到点")
    func emomCueCount() {
        var timer = model(.emom, cap: 720)
        timer.start()
        var cues: [WorkoutTimerModel.Cue] = []
        for second in 1...720 {
            cues.append(timer.advance(to: second))
        }

        #expect(cues.filter { $0 == .minute }.count == 11)
        #expect(cues.last == .end)
        #expect(timer.phase == .finished)
    }

    @Test("For Time：正计时，到 cap 没跑够就标记未完成")
    func forTimeMarksCappedOut() {
        var timer = model(.forTime, cap: 900, rounds: 5)
        timer.start()
        timer.addRound()

        #expect(timer.advance(to: 900) == .end)
        #expect(timer.cappedOut == true)
        #expect(timer.scoreText == "15:00")
    }

    @Test("For Time：跑够规定轮数就不算未完成")
    func forTimeCompleteBeforeCap() {
        var timer = model(.forTime, cap: 720, rounds: 3)
        timer.start()
        for _ in 0..<3 { timer.addRound() }
        timer.advance(to: 640)

        #expect(timer.cappedOut == false)
        #expect(timer.phase == .running)
        #expect(timer.isComplete)
    }

    @Test("Chipper：清单逐项勾选，全勾才算做完")
    func chipperChecklist() {
        var timer = model(.chipper, cap: 900, stations: 4)
        timer.start()
        let ids = timer.stationIDs
        #expect(ids.count == 4)

        for id in ids.prefix(3) {
            timer.toggleStation(id)
        }
        #expect(timer.doneStations.count == 3)
        #expect(timer.isComplete == false)

        timer.advance(to: 900)
        #expect(timer.phase == .finished)
        #expect(timer.cappedOut == true)
    }

    @Test("Chipper：到 cap 前勾完就不算未完成")
    func chipperFinishedInTime() {
        var timer = model(.chipper, cap: 900, stations: 2)
        timer.start()
        for id in timer.stationIDs {
            timer.toggleStation(id)
        }

        #expect(timer.stationsComplete)
        #expect(timer.isComplete)
        timer.advance(to: 300)
        #expect(timer.cappedOut == false)
    }

    @Test("最后 10 秒只提示一次")
    func finalTenSecondsCueFiresOnce() {
        var timer = model(.amrap, cap: 600)
        timer.start()
        var cues: [WorkoutTimerModel.Cue] = []
        for second in 1...600 { cues.append(timer.advance(to: second)) }

        #expect(cues.filter { $0 == .finalTenSeconds }.count == 1)
    }

    @Test("没在跑就不走表")
    func doesNotAdvanceWhenNotRunning() {
        var timer = model(.amrap)
        #expect(timer.advance(to: 30) == .none)
        #expect(timer.elapsed == 0)

        timer.start()
        timer.pause()
        #expect(timer.advance(to: 60) == .none)
        #expect(timer.elapsed == 0)
    }

    @Test("时间倒流或重复喂同一秒不产生副作用")
    func ignoresBackwardsTime() {
        var timer = model(.amrap)
        timer.start()
        timer.advance(to: 100)
        #expect(timer.advance(to: 50) == .none)
        #expect(timer.advance(to: 100) == .none)
        #expect(timer.elapsed == 100)
    }

    @Test("reset 把成绩、清单、阶段全清回去")
    func resetClearsEverything() {
        var timer = model(.chipper, cap: 600, stations: 2)
        timer.start()
        timer.addRound()
        timer.advance(to: 600)
        timer.reset()

        #expect(timer.phase == .ready)
        #expect(timer.elapsed == 0)
        #expect(timer.rounds == 0)
        #expect(timer.cappedOut == false)
        #expect(timer.scoreText == "0/2 项")
    }

    @Test("暂停后继续，时间不跳")
    func pauseResumeKeepsTime() {
        var timer = model(.amrap, cap: 600)
        timer.start()
        timer.advance(to: 100)
        timer.pause()
        timer.advance(to: 300)
        #expect(timer.elapsed == 100)

        timer.start()
        timer.advance(to: 200)
        #expect(timer.elapsed == 200)
    }

    @Test("提示点优先级：到 cap 压过跨整分")
    func cuePriority() {
        #expect(WorkoutTimerModel.cue(from: 710, to: 720, capSeconds: 720, isEMOM: true) == .end)
        #expect(WorkoutTimerModel.cue(from: 590, to: 600, capSeconds: 600, isEMOM: true) == .end)
        #expect(WorkoutTimerModel.cue(from: 115, to: 120, capSeconds: 600, isEMOM: true) == .minute)
        #expect(WorkoutTimerModel.cue(from: 115, to: 120, capSeconds: 600, isEMOM: false) == .none)
    }

    @Test("成品 WOD 出来的成绩文案")
    func scoreText() {
        var amrap = model(.amrap, cap: 720)
        amrap.start()
        amrap.addRound()
        amrap.addRound()
        #expect(amrap.scoreText == "2 轮")

        var emom = model(.emom, cap: 600)
        emom.start()
        emom.advance(to: 305)
        #expect(emom.scoreText == "5:05")
    }
}
