import XCTest
@testable import LWWGraph

final class LWWGraphTests: XCTestCase {
    typealias G = LWWGraph<String>

    func testAssociativeProperty() {
        // To test the associative property of the graph,
        // we take a few examples in which we "randomise" the operations.
        // The associative test passes if the outcome in the same in all the scenarios

        // The correct scenario is a disjoint graph as in: [A] [B] - [C],
        // and the connected vertices from [B] is only [C].

        // Given
        let graph = G()
        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")

        // When
        // Ideal timeline
        graph.addVertex(b, timestamp: 1)
        graph.addVertex(a, timestamp: 2)
        graph.addEdge(from: a, to: b, timestamp: 3)
        graph.addEdge(from: b, to: c, timestamp: 4)
        graph.removeVertex(a, timestamp: 5)
        graph.addVertex(a, timestamp: 6)
        let g1connectedVertices = graph.connectedVerticesBFS(from: b)

        // Altered timeline
        let graph2 = G()
        graph2.addVertex(a, timestamp: 6)
        graph2.removeVertex(a, timestamp: 5)
        graph2.addVertex(a, timestamp: 2)
        graph2.addEdge(from: b, to: c, timestamp: 4)
        graph2.addVertex(b, timestamp: 1)
        graph2.addEdge(from: a, to: b, timestamp: 3)
        let g2connectedVertices = graph2.connectedVerticesBFS(from: b)

        // Altered timeline
        let graph3 = G()
        graph3.addEdge(from: a, to: b, timestamp: 3)
        graph3.addVertex(b, timestamp: 1)
        graph3.addEdge(from: b, to: c, timestamp: 4)
        graph3.addVertex(a, timestamp: 2)
        graph3.addVertex(a, timestamp: 6)
        graph3.removeVertex(a, timestamp: 5)
        let g3connectedVertices = graph3.connectedVerticesBFS(from: b)

        XCTAssertEqual(g1connectedVertices[b], 0)
        XCTAssertEqual(g1connectedVertices[c], 1)
        XCTAssertEqual(g1connectedVertices.count, 2)

        XCTAssertEqual(g2connectedVertices[b], 0)
        XCTAssertEqual(g2connectedVertices[c], 1)
        XCTAssertEqual(g2connectedVertices.count, 2)

        XCTAssertEqual(g3connectedVertices[b], 0)
        XCTAssertEqual(g3connectedVertices[c], 1)
        XCTAssertEqual(g3connectedVertices.count, 2)
    }

    func testSequentialAdditionAndDeletion() {
        // Given
        let graph = G()
        let a = G.Vertex("A")
        let b = G.Vertex("B")

        // When
        graph.addVertex(a, timestamp: now())
        graph.addVertex(b, timestamp: now())
        graph.removeVertex(a, timestamp: now())

        // Then
        print(graph.debugDescription)
    }

    func testSequentialAdditionWithEdgeCreation() {
        // Given
        let graph = G()
        let a = G.Vertex("A")
        let b = G.Vertex("B")

        // When

        graph.addVertex(a, timestamp: now())
        graph.addVertex(b, timestamp: now())

        graph.addEdge(from: a, to: b, timestamp: now())

        // Then
        print(graph.debugDescription)
        XCTAssertEqual(graph.verticesConnected(to: a).count, 1)
        XCTAssertEqual(graph.verticesConnected(to: b).count, 1)
    }

    func testBFSOnNotConnectedGraph() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")

        graph.addVertex(a, timestamp: now())
        graph.addVertex(b, timestamp: now())
        graph.addVertex(c, timestamp: now())

        graph.addEdge(from: a, to: b, timestamp: now())

        let result = graph.findPath(from: a, to: c)

        XCTAssertEqual(result.count, 0)
    }

    func testDistanceFromNodeViaBFS() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")

        graph.addVertex(a, timestamp: now())
        graph.addVertex(b, timestamp: now())
        graph.addVertex(c, timestamp: now())

        graph.addEdge(from: a, to: b, timestamp: now())
        graph.addEdge(from: b, to: c, timestamp: now())

        let result = graph.connectedVerticesBFS(from: a)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[a], 0)
        XCTAssertEqual(result[b], 1)
        XCTAssertEqual(result[c], 2)
    }

    func testVerticesConnected() {
        let a = G.Vertex("a")

        let graph1 = G()
        graph1.addVertex(a, timestamp: 1)
        graph1.removeVertex(a, timestamp: 1)

        let graph2 = G()
        graph2.removeVertex(a, timestamp: 1)
        graph2.addVertex(a, timestamp: 1)

        XCTAssertTrue(graph1.isEmpty)
        XCTAssertTrue(graph2.isEmpty)
    }

    func testVertexAdditionWithSameElement() {
        let graph = G()
        let a = G.Vertex("A")
        let b = G.Vertex("A")
        let c = G.Vertex("A")

        graph.addVertex(a)
        graph.addVertex(b)
        graph.addVertex(c)

        graph.addEdge(from: b, to: c)

        XCTAssertEqual(graph.verticesConnected(to: a), [])
    }

    func testIsolatedVertexConnections() {
        let graph = G()
        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")

        graph.addVertex(a)
        graph.addVertex(b)
        graph.addVertex(c)

        graph.addEdge(from: b, to: c)

        XCTAssertEqual(graph.verticesConnected(to: a), [])
    }

    func testConnectedGraphEdgeRemoval() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")
        let d = G.Vertex("D")
        let e = G.Vertex("E")
        let f = G.Vertex("F")

        graph.addVertex(a)
        graph.addVertex(b)
        graph.addVertex(c)
        graph.addVertex(d)
        graph.addVertex(e)
        graph.addVertex(f)

        // A - B - D
        // | \ | /
        // C   E - F
        let ab = graph.addEdge(from: a, to: b)!
        graph.addEdge(from: a, to: c)
        graph.addEdge(from: a, to: b)
        graph.addEdge(from: a, to: e)
        graph.addEdge(from: b, to: e)
        graph.addEdge(from: d, to: e)
        graph.addEdge(from: e, to: f)

        // A   B - D
        // | \ | /
        // C   E - F
        graph.removeEdge(edge: ab)

        XCTAssertEqual(graph.count, 6)
        XCTAssertEqual(graph.verticesConnected(to: a).map { $0.debugDescription }, ["C", "E"])
        XCTAssertEqual(graph.verticesConnected(to: b).map { $0.debugDescription }, ["E"])
        XCTAssertEqual(graph.verticesConnected(to: c).map { $0.debugDescription }, ["A"])
        XCTAssertEqual(graph.verticesConnected(to: d).map { $0.debugDescription }, ["E"])
        XCTAssertEqual(graph.verticesConnected(to: e).map { $0.debugDescription }, ["A", "B", "D", "F"])
        XCTAssertEqual(graph.verticesConnected(to: f).map { $0.debugDescription }, ["E"])
    }

    // MARK: - Vertices operations
    func testConnectedGraphVertexRemoval() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")
        let d = G.Vertex("D")

        graph.addVertex(a)
        graph.addVertex(b)
        graph.addVertex(c)
        graph.addVertex(d)

        // A - B - D
        // |
        // C
        graph.addEdge(from: a, to: b)
        graph.addEdge(from: a, to: c)
        graph.addEdge(from: b, to: d)

        // A  D
        // |
        // C
        graph.removeVertex(b)

        XCTAssertEqual(graph.count, 3)
        XCTAssertFalse(graph.lookup(b))

        XCTAssertEqual(graph.verticesConnected(to: a).map { $0.debugDescription }, ["C"])
        XCTAssertEqual(graph.verticesConnected(to: c).map { $0.debugDescription }, ["A"])
        XCTAssertTrue(graph.verticesConnected(to: d).isEmpty)
    }

    func testDisjointGraphUnreachableVertexDistance() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")
        let d = G.Vertex("D")
        let e = G.Vertex("E")
        let f = G.Vertex("F")

        graph.addVertex(a)
        graph.addVertex(b)
        graph.addVertex(c)
        graph.addVertex(d)
        graph.addVertex(e)
        graph.addVertex(f)

        // A   B - D
        // |   | /
        // C   E - F
        graph.addEdge(from: a, to: c)

        graph.addEdge(from: b, to: d)
        graph.addEdge(from: b, to: e)
        graph.addEdge(from: d, to: e)
        graph.addEdge(from: e, to: f)

        let path = graph.findPath(from: a, to: e)

        XCTAssertEqual(path.count, 0)
        XCTAssertEqual(path, [])
    }

    func testVerticesConnectedToUnrelatedNode() {
        let graph = G()
        let a = G.Vertex("A")
        let b = G.Vertex("B")

        graph.addVertex(a)

        XCTAssertEqual(graph.verticesConnected(to: b), [])
    }

    func testEdgeAdditionWithPreviousRemoval() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")

        graph.addVertex(a)
        graph.addVertex(b)

        graph.removeEdge(edge: .init(from: a, to: b),
                         timestamp: now().advanced(by: 10.minutes))
        graph.addEdge(from: a, to: b)

        XCTAssertEqual(graph.verticesConnected(to: a), [])
        XCTAssertEqual(graph.verticesConnected(to: b), [])
    }

    func testVertexDistance() {
        let graph = G()

        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")
        let d = G.Vertex("D")
        let e = G.Vertex("E")
        let f = G.Vertex("F")

        graph.addVertex(a)
        graph.addVertex(b)
        graph.addVertex(c)
        graph.addVertex(d)
        graph.addVertex(e)
        graph.addVertex(f)

        // A - B - D
        // | \ | /
        // C   E - F
        graph.addEdge(from: a, to: b)
        graph.addEdge(from: a, to: c)
        graph.addEdge(from: a, to: b)
        graph.addEdge(from: a, to: e)
        graph.addEdge(from: b, to: e)
        graph.addEdge(from: d, to: e)
        graph.addEdge(from: e, to: f)

        let path = graph.findPath(from: c, to: f)

        XCTAssertEqual(path.count, 4)
        XCTAssertEqual(path, [c, a, e, f])
    }

    func testVertexRemovalWithoutAddition() {
        let graph = G()

        let a = G.Vertex("A")

        graph.removeVertex(a, timestamp: now())

        XCTAssertFalse(graph.lookup(a))
    }

    func testVertexAdditionAndRemoval() {
        let graph = G()

        let a = G.Vertex("A")

        graph.addVertex(a, timestamp: now())
        graph.removeVertex(a, timestamp: now())

        XCTAssertFalse(graph.lookup(a))
    }

    // MARK: - Graph merge

    func testMergeGraphs() {
        let a = G.Vertex("A")
        let b = G.Vertex("B")
        let c = G.Vertex("C")
        let d = G.Vertex("D")
        let e = G.Vertex("E")
        let f = G.Vertex("F")

        let source = G()
        let remote = G()

        source.addVertex(a)
        source.addVertex(b)
        source.addVertex(c)
        source.addVertex(e)

        // A - B
        // | \ |
        // C   E
        source.addEdge(from: a, to: b)
        source.addEdge(from: a, to: c)
        source.addEdge(from: a, to: e)
        source.addEdge(from: b, to: e)


        remote.addVertex(b)
        remote.addVertex(e)
        remote.addVertex(d)
        remote.addVertex(f)

        // B - D
        // | /
        // E - F
        remote.addEdge(from: b, to: d)
        remote.addEdge(from: b, to: e)
        remote.addEdge(from: e, to: d)
        remote.addEdge(from: e, to: f)

        // A - B - D
        // | \ | /
        // C   E - F

        source.merge(remote)

        let verticesConnectedToE = source.verticesConnected(to: e)
        XCTAssertEqual(verticesConnectedToE.count, 4)
        XCTAssertTrue(verticesConnectedToE.contains(a))
        XCTAssertTrue(verticesConnectedToE.contains(b))
        XCTAssertTrue(verticesConnectedToE.contains(d))
        XCTAssertTrue(verticesConnectedToE.contains(f))
    }

    // MARK: - Lookups
    func testLookupAfterAddition() {
        let graph = G()
        let a = G.Vertex("A")

        graph.addVertex(a, timestamp: now())

        XCTAssertTrue(graph.lookup(a))
    }

    func testLookupAfterAdditionAndRemoval() {
        let graph = G()
        let a = G.Vertex("A")

        graph.addVertex(a, timestamp: 1)
        graph.removeVertex(a, timestamp: 2)

        XCTAssertFalse(graph.lookup(a))
    }

    func testLookupOfNonExistingNode() {
        let graph = G()
        let a = G.Vertex("A")

        XCTAssertFalse(graph.lookup(a))
    }

    // MARK: - Performance

    override class var defaultPerformanceMetrics: [XCTPerformanceMetric] {
        [XCTPerformanceMetric.wallClockTime,
//         .init("com.apple.XCTPerformanceMetric_PersistentVMAllocations"),
         .init("com.apple.XCTPerformanceMetric_TransientHeapAllocationsKilobytes"),
         .init("com.apple.XCTPerformanceMetric_TransientVMAllocationsKilobytes"),
         .init("com.apple.XCTPerformanceMetric_HighWaterMarkForVMAllocations"),
         .init("com.apple.XCTPerformanceMetric_TotalHeapAllocationsKilobytes")]
    }

    func testPerformance() {
        typealias IG = LWWGraph<Int>
        let g = IG()

        var vertices: [IG.Vertex] = []
        for i in 0...1_000_000 {
            vertices.append(IG.Vertex(i))
        }

        measure {
            vertices.forEach { v in

                g.addVertex(v, timestamp: now())

                if Int.random(in: 0...2) % 2 == 0 {
                    g.removeVertex(v, timestamp: now()
                                    .minus(Double.random(in: -10..<10)))
                }
            }
        }

    }
}
