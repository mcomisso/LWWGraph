import Foundation

class LWWSet<T>: Hashable, Equatable, Sequence where T: Hashable {

    func makeIterator() -> some IteratorProtocol {
        creations.filter(contains)
            .makeIterator()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(creations)
        hasher.combine(tombstones)
    }

    static func == (lhs: LWWSet<T>, rhs: LWWSet<T>) -> Bool {
        lhs.creations == rhs.creations &&
        lhs.tombstones == rhs.tombstones
    }

    private var creations: [T: TimeInterval] = [:]
    private var tombstones: [T: TimeInterval] = [:]

    fileprivate convenience init(_ creations: [T: TimeInterval], _ tombstones: [T: TimeInterval]) {
        self.init()
        self.creations = creations
        self.tombstones = tombstones
    }

    // Returns the state of the set
    func snapshot(at timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Set<T> {
        Set(creations.keys.filter { contains($0, at: timestamp) })
    }

    private func wasRemovedAfterAddition(_ atom: T,
                                         additionTimestamp: TimeInterval) -> Bool {
        guard let removalTimestamp = tombstones[atom] else {
            return false
        }
        return removalTimestamp >= additionTimestamp
    }

    private func wasAddedAfterRemoval(_ atom: T,
                                      removalTimestamp: TimeInterval) -> Bool {
        guard let additionTimestamp = creations[atom] else {
            return false
        }
        return additionTimestamp > removalTimestamp
    }

    // This method always update the creations, IF there was no removal after the addition
    @discardableResult
    func add(_ value: T, timeinterval: TimeInterval) -> T? {
        // Updates the previous add date interval, if present
        if let previousTimeInterval = creations[value] {
            if previousTimeInterval < timeinterval {
                creations[value] = timeinterval
            }
        } else {
            creations[value] = timeinterval
        }

        guard !wasRemovedAfterAddition(value, additionTimestamp: timeinterval) else {
            return nil
        }

        return value
    }

    // This method always update the tombstones, IF there was no addition after the removal
    @discardableResult
    func remove(_ value: T, timeinterval: TimeInterval) -> T? {
        // If it has an older value, update it
        if let previousTimeInterval = tombstones[value] {
            if previousTimeInterval < timeinterval {
                tombstones[value] = timeinterval
            }
        } else {
            tombstones[value] = timeinterval
        }

        guard !wasAddedAfterRemoval(value, removalTimestamp: timeinterval) else {
            return nil
        }
        return value
    }

    func contains(_ value: T, at timestamp: TimeInterval) -> Bool {
        // value is in created set, but not in tombstones set
        if creations[value] != nil && tombstones[value] == nil {
            return true
        }

        if let tombTimeInterval = tombstones[value],
           let creationTimeInterval = creations[value] {

            // The value is in both creations and tombstones
            // To be present at timestamp, it means ignoring everything that is above timestamp
            // and only focus on the max values of
            if creationTimeInterval <= timestamp,
               tombTimeInterval <= timestamp {
                return tombTimeInterval < creationTimeInterval
            } else {
                return tombTimeInterval < timestamp && creationTimeInterval > timestamp
            }
        }

        return false
    }

    // Lookups O(1)
    func contains(_ value: T) -> Bool {
        // value is in created set, but not in tombstones set
        if creations[value] != nil && tombstones[value] == nil {
            return true
        }

        // Value is in tombstones, but was successively added
        if let tombTimeInterval = tombstones[value],
           let creationTimeInterval = creations[value],
           tombTimeInterval < creationTimeInterval {
            return true
        }

        return false
    }

    // MARK: - Merge of two sets

    /// Merges another LWWSet by uniquing the keys and respecting the most recent change
    /// - Parameter other: The set to merge
    func merge(_ other: LWWSet<T>) {
        self.creations.merge(other.creations, uniquingKeysWith: Swift.max)
        self.tombstones.merge(other.tombstones, uniquingKeysWith: Swift.max)
    }

    /// Returns a new LWWSet, resulting merge of creations/tombstones of `other`
    /// - Parameter other: The set to merge
    func merging(_ other: LWWSet<T>) -> LWWSet<T> {
        let newCreations = self.creations
            .merging(other.creations, uniquingKeysWith: Swift.max)
        let newTombstones = self.tombstones
            .merging(other.tombstones, uniquingKeysWith: Swift.max)

        return LWWSet<T>(newCreations, newTombstones)
    }
}


extension LWWSet: CustomDebugStringConvertible {
    var debugDescription: String {
        return snapshot().debugDescription
    }
}
