import Foundation

// Last write wins
// A Set that handles ordering by letting the most recent insert win the conflict.

// LWWGraph

/* Description of functionalities
 The graph must contain functionalities to:
- add a vertex/edge,
- remove a vertex/edge,
- check if a vertex is in the graph,
- query for all vertices connected to a vertex,
- find any path between two vertices,
- and merge with concurrent changes from other graph/replica.
 */


// associative property is missing

protocol GraphFunctionalities {
    associatedtype V
    associatedtype E
    associatedtype Replica

    // Vertex management
    func addVertex(_ vertex: V, timestamp: TimeInterval) -> V?
    func removeVertex(_ vertex: V, timestamp: TimeInterval)

    // Edges
    func addEdge(from: V, to: V, timestamp: TimeInterval) -> E?
    func removeEdge(edge: E, timestamp: TimeInterval)

    func lookup(_ vertex: V) -> Bool
    func verticesConnected(to: V) -> [V]
    func findPath(from: V, to: V) -> [V]

    func merge(_ replica: Replica)
}

class LWWGraph<T>: GraphFunctionalities, CustomDebugStringConvertible where T: Hashable {

    typealias T = T
    typealias Replica = LWWGraph<T>

    private var verticesSet: LWWSet<LWWGraph<T>.Vertex> = .init()
    private var edgesSet: LWWSet<LWWGraph<T>.Edge> = .init()
    private var adjacencyList: [Vertex: [Edge]] = [:]

    // MARK: - Additions

    @discardableResult
    func addVertex(_ vertex: Vertex, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Vertex? {
        if let v = verticesSet.add(vertex, timeinterval: timestamp) {
            guard adjacencyList[v] == nil else {
                return nil
            }
            adjacencyList[v] = []
            return v
        }
        return nil
    }

    @discardableResult
    func addEdge(from: Vertex, to: Vertex,
                 timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Edge? {

        // Returns the vertex if it's in the adjacency list, otherwise adds it to it with the timestamp of the current operation
        func optimisticAddition(of vertex: Vertex) -> Vertex? {
            if adjacencyList[vertex] == nil {
                return addVertex(from, timestamp: timestamp)
            } else {
                return vertex
            }
        }

        guard from != to else { return nil }

        // Optimistically adds the vertices.
        // If a node will be removed in the future, the addVertex function will prevent addition in the first place
        guard let validFrom = optimisticAddition(of: from),
           let validTo = optimisticAddition(of: to) else {
               return nil
        }

        let edge = Edge(from: validFrom, to: validTo)

        guard let e = edgesSet.add(edge, timeinterval: timestamp) else {
            return nil
        }

        // This section happens only if there are no future removals of the edge

        // Gets the from vertex and all the connected vertices to it.
        // if it does not contain the current edge to
//        guard adjacencyList[e.from]?
//                .map({ $0.to })
//                .contains(e.to) == false else {
//            return nil
//        }

        adjacencyList[e.from]?.append(e)
        adjacencyList[e.to]?.append(e.inverted())

        return e
    }

    // MARK: - Removals
    func removeVertex(_ vertex: Vertex, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        // Check if the removal is a valid operation, or if and addition happened after it
        if let removedVertex = verticesSet.remove(vertex, timeinterval: timestamp) {

            // If valid, get all the vertices that are connected to the removal vertex

            if let targetEdges = adjacencyList[removedVertex] {
                for edge in targetEdges {
                    removeEdge(edge: edge, timestamp: timestamp)
                    removeEdge(edge: edge.inverted(), timestamp: timestamp)
                    adjacencyList[edge.to]?.removeAll(where: { $0.to == removedVertex })
                }
            }

//            if let targetVertices = adjacencyList[removedVertex]?.map({ $0.to }) {
//
//                // Remove all the edges that connect connecting vertices to our removal vertex
//                targetVertices.forEach {
//                    adjacencyList[$0]?.removeAll(where: { $0.to == removedVertex })
//                }
//            }
            adjacencyList[removedVertex] = nil
        }
    }

    func removeEdge(edge: Edge, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        if let removedEdge = edgesSet.remove(edge, timeinterval: timestamp) {
            let removedFrom = removedEdge.from
            let removedTo = removedEdge.to

            adjacencyList[removedFrom]!.removeAll(where: { $0.from == removedFrom && $0.to == removedTo })
            adjacencyList[removedTo]!.removeAll(where: { $0.from == removedTo && $0.to == removedFrom })
        }
    }

    // MARK: - Lookups and connections
    func lookup(_ vertex: Vertex) -> Bool {
        adjacencyList.keys.contains(vertex)
    }

    func findPath(from: Vertex, to: Vertex) -> [Vertex] {
        self.bfs(from: from, to: to)
    }

    // MARK: - Merge of graphs
    func merge(_ replica: LWWGraph<T>) {
        let newVSet = verticesSet.merging(replica.verticesSet)
        let newESet = edgesSet.merging(replica.edgesSet)
        self.verticesSet = newVSet
        self.edgesSet = newESet
        self.adjacencyList = generateAdjacencyList()
    }
}

// MARK: - Computed properties
extension LWWGraph {
    var isEmpty: Bool {
        count == 0
    }

    var count: Int {
        adjacencyList.count
    }

    var debugDescription: String {
        var retVal = ""
        adjacencyList.forEach {
            retVal.append($0.key.debugDescription)
            retVal.append(": \($0.value.compactMap { $0.to.debugDescription }.joined(separator: " -> "))\n")
        }
        return retVal
    }
}

// MARK: - Search utils
extension LWWGraph {

    func verticesConnected(to vertex: Vertex) -> [Vertex] {
        adjacencyList[vertex]?.compactMap { $0.to } ?? []
    }

    private func generateAdjacencyList() -> [Vertex: [Edge]] {
        var a: [Vertex: [Edge]] = [:]

        verticesSet.status().forEach { a[$0] = [] }
        edgesSet.status().forEach {
            a[$0.from]!.append($0)
            a[$0.to]!.append($0.inverted())
        }

        return a
    }

    /// Returns a map with all vertices attached to the `from` vertex, and their distance from it
    public func connectedVerticesBFS(from: Vertex) -> [Vertex: Int] {
        var queue: [Vertex] = []
        queue.append(from)

        var distance: [Vertex: Int] = [from: 0]

        while !queue.isEmpty {
            let currentVertex = queue.removeFirst()

            for edge in adjacencyList[currentVertex]! {
                let to = edge.to

                if distance[to] == nil {
                    queue.append(to)
                    distance[to] = distance[currentVertex]! + 1
                }
            }
        }

        return distance
    }

    private func bfs(from source: Vertex, to destination: Vertex) -> [Vertex] {
        var path: [Vertex] = []
        var queue: [Vertex] = []

        queue.append(source)

        var distance: [Vertex: Int] = [source: 0]
        var predecessors: [Vertex: Vertex] = [source: source]

        while !queue.isEmpty {
            let currentVertex = queue.removeFirst()

            for edge in adjacencyList[currentVertex]! {
                let to = edge.to

                if distance[to] == nil {
                    distance[to] = distance[currentVertex]! + 1
                    predecessors[to] = currentVertex

                    if to == destination {
                        break
                    }
                    queue.append(to)
                }
            }
        }

        if var tail = predecessors[destination] {
            path.append(destination)
            while tail != source {
                path.insert(tail, at: 0)
                tail = predecessors[tail]!
            }
            path.insert(source, at: 0)
        }
        return path
    }
}
