import Foundation
import XCTest

extension Int {
    var seconds: Double { Double(self) }

    var minutes: Double { seconds * 60 }
    var hours: Double { minutes * 60 }
    var days: Double { hours * 24 }
}

final class IntTests: XCTestCase {

    func testSeconds() {
        XCTAssertEqual(10.seconds, 10)
    }

    func testMinutes() {
        XCTAssertEqual(10.minutes, 600)
    }

    func testHours() {
        XCTAssertEqual(10.hours, 36000)
    }

    func testDays() {
        XCTAssertEqual(10.days, 864000)
    }
}

extension TimeInterval {
    func minus(_ value: Double) -> TimeInterval {
        return TimeInterval(self - value)
    }
}

func now() -> TimeInterval {
    Date().timeIntervalSinceReferenceDate
}

