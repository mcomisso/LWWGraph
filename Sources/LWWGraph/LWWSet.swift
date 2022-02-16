import Foundation

class LWWSet<T>: Hashable, Equatable where T: Hashable {

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
    func status() -> Set<T> {
        var retVal: Set<T> = []
        for key in creations.keys {
            if contains(key) {
                retVal.insert(key)
            }
        }
        return retVal
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
        if let previousTimeInterval = creations[value],
           previousTimeInterval < timeinterval {
            creations[value] = timeinterval
        } else {
            creations[value] = timeinterval
        }

        guard !wasRemovedAfterAddition(value, additionTimestamp: timeinterval) else {
            return nil
        }

        creations[value] = timeinterval
        return value
    }

    // This method always update the tombstones, IF there was no addition after the removal
    @discardableResult
    func remove(_ value: T, timeinterval: TimeInterval) -> T? {
        // If it has an older value, update it
        if let previousTimeInterval = tombstones[value],
           previousTimeInterval < timeinterval {
            tombstones[value] = timeinterval
        } else {
            tombstones[value] = timeinterval
        }

        guard !wasAddedAfterRemoval(value, removalTimestamp: timeinterval) else {
            return nil
        }
        return value
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
        self.creations.merge(other.creations, uniquingKeysWith: max)
        self.tombstones.merge(other.tombstones, uniquingKeysWith: max)
    }

    /// Returns a new LWWSet, resulting merge of creations/tombstones of `other`
    /// - Parameter other: The set to merge
    func merging(_ other: LWWSet<T>) -> LWWSet<T> {
        let newCreations = self.creations
            .merging(other.creations, uniquingKeysWith: max)
        let newTombstones = self.tombstones
            .merging(other.tombstones, uniquingKeysWith: max)

        return LWWSet<T>(newCreations, newTombstones)
    }
}
