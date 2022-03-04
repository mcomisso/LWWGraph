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

class LWWGraph<T>: GraphFunctionalities where T: Hashable {

    typealias T = T
    typealias Replica = LWWGraph<T>

    private var verticesSet: LWWSet<LWWGraph<T>.Vertex> = .init()
    private var edgesSet: LWWSet<LWWGraph<T>.Edge> = .init()

    private var adjacencyList: [Vertex: [Vertex]] = [:]

    // MARK: - Additions

    @discardableResult
    func addVertex(_ vertex: Vertex, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Vertex? {

        guard let addedVertex = verticesSet.add(vertex, timeinterval: timestamp) else {
            return nil
        }

        createVertexInAdjacencyList(vertex)

        return addedVertex
    }

    private func createVertexInAdjacencyList(_ v: Vertex) {
        if adjacencyList[v] == nil {
            adjacencyList[v] = []
        }
    }

    @discardableResult
    func addEdge(from: Vertex, to: Vertex,
                 timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Edge? {

        // Do not operate on same nodes
        guard from != to else {
            return nil
        }

        var addedFrom: Vertex?
        var addedTo: Vertex?

        if !verticesSet.contains(from, at: timestamp) {
            addedFrom = addVertex(from, timestamp: timestamp)
        } else {
            addedFrom = from
        }

        if !verticesSet.contains(to, at: timestamp) {
            addedTo = addVertex(to, timestamp: timestamp)
        } else {
            addedTo = to
        }

        // Check if previous operations were successful, otherwise return
        guard let addedFrom = addedFrom,
              let addedTo = addedTo else {
                  return nil
              }

        if let edge = edgesSet.add(.init(from: addedFrom, to: addedTo), timeinterval: timestamp) {
            connectVertices(edge)
            return edge
        }

        return nil
    }

    private func connectVertices(_ edge: Edge) {
        adjacencyList[edge.from]?.append(edge.to)
        adjacencyList[edge.to]?.append(edge.from)
    }

    // MARK: - Removals
    func removeVertex(_ vertex: Vertex, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        if let removedVertex = verticesSet.remove(vertex, timeinterval: timestamp) {
            // Remove the node from all the neighbours relations

            // Generates the list of edges
            adjacencyList[removedVertex]?
                .compactMap { Edge(from: removedVertex, to: $0) }
                .forEach { edge in
                    // Use the defined function to remove A - B (and B - A)
                    removeEdge(edge: edge, timestamp: timestamp)
                    removeEdge(edge: edge.inverted(), timestamp: timestamp)
                }

            // Remove the node itself
            adjacencyList[removedVertex] = nil
        } else {
            // If the vertex is not removed from the storage, we might still want to find relevant edges at a certain timestamp.
            // TODO: This function is not the fastest, but priority was given to passing the tests
            edgesSet.snapshot()
                .forEach { edge in

                    if edge.from == vertex ||
                        edge.to == vertex {
                        // Vertex included in edge

                        removeEdge(edge: edge, timestamp: timestamp)
                        removeEdge(edge: edge.inverted(), timestamp: timestamp)

                    }
                }
//            self.adjacencyList = generateAdjacencyList()
        }
    }

    func removeEdge(edge: Edge, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        if let removedEdge = edgesSet.remove(edge, timeinterval: timestamp) {
            adjacencyList[removedEdge.from, default: []].removeAll(where: { $0 == removedEdge.to })
            adjacencyList[removedEdge.to, default: []].removeAll(where: { $0 == removedEdge.from })
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
extension LWWGraph: CustomDebugStringConvertible {
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
            retVal.append(": \($0.value.compactMap { $0.debugDescription }.joined(separator: " -> "))\n")
        }
        return retVal
    }
}

// MARK: - Search utils
extension LWWGraph {

    func verticesConnected(to vertex: Vertex) -> [Vertex] {
        adjacencyList[vertex, default: []]
    }

    private func generateAdjacencyList() -> [Vertex: [Vertex]] {
        var a: [Vertex: [Vertex]] = [:]

        verticesSet.snapshot()
            .forEach { a[$0] = [] }

        edgesSet.snapshot()
            .forEach {
                a[$0.from]!.append($0.to)
                a[$0.to]!.append($0.from)
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

            for edge in adjacencyList[currentVertex, default: []] {
                if distance[edge] == nil {
                    queue.append(edge)
                    distance[edge] = distance[currentVertex]! + 1
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

            for to in adjacencyList[currentVertex, default: []] {

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
