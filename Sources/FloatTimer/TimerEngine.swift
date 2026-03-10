import Foundation

protocol TimerEngineDelegate: AnyObject {
    func timerDidTick(remaining: TimeInterval)
    func timerDidFinish()
    func timerDidChangeState(_ state: TimerEngine.State)
}

class TimerEngine {
    enum State {
        case idle
        case running
        case paused
    }

    weak var delegate: TimerEngineDelegate?

    private(set) var state: State = .idle
    private(set) var totalDuration: TimeInterval = 0
    private(set) var remaining: TimeInterval = 0

    private var timer: DispatchSourceTimer?
    private var lastTickDate: Date?

    var formattedTime: String {
        let total = max(0, Int(remaining.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func start(duration: TimeInterval) {
        stop()
        totalDuration = duration
        remaining = duration
        Preferences.shared.lastDuration = duration
        state = .running
        delegate?.timerDidChangeState(state)
        delegate?.timerDidTick(remaining: remaining)
        startTicking()
    }

    func togglePauseResume() {
        switch state {
        case .running: pause()
        case .paused: resume()
        case .idle: break
        }
    }

    func pause() {
        guard state == .running else { return }
        timer?.cancel()
        timer = nil
        state = .paused
        delegate?.timerDidChangeState(state)
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        delegate?.timerDidChangeState(state)
        startTicking()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        remaining = 0
        state = .idle
        delegate?.timerDidChangeState(state)
    }

    private func startTicking() {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(100))
        lastTickDate = Date()

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastTickDate ?? now)
            self.lastTickDate = now
            self.remaining -= elapsed

            if self.remaining <= 0 {
                self.remaining = 0
                self.timer?.cancel()
                self.timer = nil
                self.state = .idle
                self.delegate?.timerDidFinish()
                self.delegate?.timerDidChangeState(self.state)
            } else {
                self.delegate?.timerDidTick(remaining: self.remaining)
            }
        }

        source.resume()
        timer = source
    }
}
