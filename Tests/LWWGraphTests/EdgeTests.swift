import Foundation
import XCTest
@testable import LWWGraph

class EdgeTests: XCTestCase {

    func testEdgePrintWithInversion() {
        let e = LWWGraph<String>.Edge(from: .init("A"), to: .init("B"))
        XCTAssertEqual(e.debugDescription, "A -> B")
        XCTAssertEqual(e.inverted().debugDescription, "B -> A")
    }

}
