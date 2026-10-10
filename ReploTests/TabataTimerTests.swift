import Testing

@testable import Replo

@Suite("TABATA 计时状态机")
struct TabataTimerModelTests {
    private func model(work: Int = 20, rest: Int = 10, rounds: Int = 8) -> TabataTimerModel {
        TabataTimerModel(workSeconds: work, restSeconds: rest, totalRounds: rounds)
    }

    @Test("总时长 = (工作 + 休息) × 轮数")
    func totalSecondsAddsUp() {
        #expect(model().totalSeconds == 240)
    }

    @Test("工作段→休息段→下一轮，段边界给提示")
    func segmentTransitions() {
        var timer = model()
        timer.start()

        #expect(timer.segment == .work)
        #expect(timer.currentRound == 1)
        #expect(timer.advance(to: 19) == .finalThree)
        #expect(timer.segmentRemaining == 1)

        #expect(timer.advance(to: 20) == .segment)
        #expect(timer.segment == .rest)
        #expect(timer.segmentRemaining == 10)

        #expect(timer.advance(to: 30) == .segment)
        #expect(timer.segment == .work)
        #expect(timer.currentRound == 2)
    }

    @Test("进入段末 3 秒给提示")
    func finalThreeCue() {
        var timer = model()
        timer.start()

        #expect(timer.advance(to: 16) == .none)
        #expect(timer.advance(to: 17) == .finalThree)
        #expect(timer.advance(to: 18) == .none)
    }

    @Test("跑满 8 轮自动结束，成绩记完整工作段数")
    func finishAtEnd() {
        var timer = model()
        timer.start()

        #expect(timer.advance(to: 240) == .end)
        #expect(timer.phase == .finished)
        #expect(timer.scoreText == "完成 8/8 轮")
    }

    @Test("中途停下：成绩只记已完成的工作段")
    func partialScore() {
        var timer = model()
        timer.start()
        timer.advance(to: 65)  // 第 3 轮工作段中（60-80）

        #expect(timer.completedRounds == 2)
        #expect(timer.scoreText == "完成 2/8 轮")
    }

    @Test("暂停后喂时间不推进，恢复后继续")
    func pauseFreezes() {
        var timer = model()
        timer.start()
        timer.advance(to: 5)
        timer.pause()

        #expect(timer.advance(to: 10) == .none)
        #expect(timer.elapsed == 5)

        timer.start()
        #expect(timer.advance(to: 10) == .none)
        #expect(timer.elapsed == 10)
    }

    @Test("重置回 ready，归零")
    func resetClears() {
        var timer = model()
        timer.start()
        timer.advance(to: 30)
        timer.reset()

        #expect(timer.phase == .ready)
        #expect(timer.elapsed == 0)
        #expect(timer.scoreText == "完成 0/8 轮")
    }

    @Test("结束后不再推进")
    func finishedLocks() {
        var timer = model()
        timer.start()
        timer.advance(to: 240)

        #expect(timer.advance(to: 300) == .none)
        #expect(timer.elapsed == 240)
    }

    @Test("一大跳跨多段只报一个换段提示")
    func bigJumpReportsOneCue() {
        var timer = model()
        timer.start()

        #expect(timer.advance(to: 95) == .segment)
        #expect(timer.currentRound == 4)
        #expect(timer.segment == .work)
    }
}
