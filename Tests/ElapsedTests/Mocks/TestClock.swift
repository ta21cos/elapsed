import Foundation
@testable import Elapsed

final class TestClock: Clock {
    var now: Date

    init(_ date: Date = Date()) {
        self.now = date
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
