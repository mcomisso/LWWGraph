import Foundation
import XCTest
@testable import LWWGraph

final class LWWSetTests: XCTestCase {

    typealias S = LWWSet<String>

    func testAssociativeProperty() {
        let set = S()

        set.add("A", timeinterval: 1)
        set.add("B", timeinterval: 2)
        set.remove("A", timeinterval: 3)
        set.remove("B", timeinterval: 4)

        XCTAssertEqual(set.snapshot(), [])


        set.remove("A", timeinterval: 3)
        set.add("A", timeinterval: 1)
        set.remove("B", timeinterval: 4)
        set.add("B", timeinterval: 2)

        XCTAssertEqual(set.snapshot(), [])
    }

    func testAdditions() {
        let set = S()

        set.add("A", timeinterval: now())
        set.add("B", timeinterval: now())

        XCTAssertEqual(set.snapshot().sorted(), ["A", "B"])
    }

    func testContainsInAdditionOnly() {
        let set = S()

        set.add("A", timeinterval: now())

        XCTAssertTrue(set.contains("A"))
    }

    func testContainsWithRemoval() {
        let set = S()

        set.add("A", timeinterval: now())
        set.remove("A", timeinterval: now())

        XCTAssertFalse(set.contains("A"))
    }

    func testContainsWithPriorRemoval() {
        let set = S()

        set.remove("A", timeinterval: now())
        set.add("A", timeinterval: now())

        XCTAssertTrue(set.contains("A"))
    }

    func testDeletions() {
        let set = S()

        // 1
        set.add("A", timeinterval: now())
        set.add("B", timeinterval: now())

        // 2
        set.remove("A", timeinterval: now())
        set.remove("B", timeinterval: now())

        XCTAssertEqual(set.snapshot().sorted(), [])

        // 3
        set.add("A", timeinterval: now())
        XCTAssertEqual(set.snapshot().sorted(), ["A"])

        // 4
        // Old insert
        set.add("C", timeinterval: now().minus(4.hours))
        XCTAssertEqual(set.snapshot().sorted(), ["A", "C"])

        // 5
        // Old deletion, overwritten by 1, 3
        set.remove("A", timeinterval: now().minus(4.days))
        XCTAssertEqual(set.snapshot().sorted(), ["A", "C"])
    }

    func testRemovalAfterAddition() {
        let set = S()
        set.add("A", timeinterval: now())
        set.remove("A", timeinterval: now())

        XCTAssertFalse(set.snapshot().contains("A"))
    }

    func testMerge() {
        let s1 = S()
        let s2 = S()

        s1.add("A", timeinterval: now())
        s1.remove("A", timeinterval: now())

        s2.add("B", timeinterval: now())
        s2.remove("B", timeinterval: now())
        s2.add("C", timeinterval: now())

        s2.add("A", timeinterval: now().minus(1.hours))
        s2.remove("A", timeinterval: now().minus(1.minutes))

        s1.merge(s2)

        XCTAssertEqual(s1.snapshot().sorted(), ["C"])
    }

    func testMerging() {
        let s1 = S()
        let s2 = S()

        s1.add("A", timeinterval: now())
        s1.remove("A", timeinterval: now())
        s1.remove("C", timeinterval: now().advanced(by: 1.hours))

        s2.add("B", timeinterval: now())
        s2.remove("B", timeinterval: now())
        s2.add("C", timeinterval: now())
        s2.add("A", timeinterval: now())

        let s1and2 = s1.merging(s2)

        XCTAssertEqual(s1and2.snapshot().sorted(), ["A"])
        XCTAssertEqual(s1.snapshot().sorted(), [])
        XCTAssertEqual(s2.snapshot().sorted(), ["A", "C"])
    }
}
