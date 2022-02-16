import Foundation

extension LWWGraph {
    // MARK: - Vertex
    class Vertex: CustomDebugStringConvertible, Hashable, Equatable {
        let value: T

        static func ==(lhs: Vertex, rhs: Vertex) -> Bool {
            lhs.value == rhs.value
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(value)
        }

        init(_ value: T) {
            self.value = value
        }

        var debugDescription: String {
            "\(value)"
        }
    }

}
