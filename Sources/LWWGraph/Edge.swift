import Foundation

extension LWWGraph {
    // MARK: - Edge
    class Edge: CustomDebugStringConvertible, Equatable, Hashable {

        // Hashable conformance
        func hash(into hasher: inout Hasher) {
            hasher.combine(from)
            hasher.combine(to)
        }

        // Equatable conformance
        static func ==(lhs: Edge, rhs: Edge) -> Bool {
            lhs.from == rhs.from && lhs.to == rhs.to
        }

        var from: Vertex
        var to: Vertex

        init(from: Vertex, to: Vertex) {
            self.from = from
            self.to = to
        }

        func inverted() -> Edge {
            Edge(from: to, to: from)
        }

        var debugDescription: String {
            "\(from.value) -> \(to.value)"
        }
    }

}
