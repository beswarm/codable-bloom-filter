// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

public struct BloomFilter<T: DeterministicallyHashable>: Codable {
    enum CodingKeys: String, CodingKey {
        case hashes
        case hashCount
        case bits = "data"
    }
    
    public let hashes: [Hash]
    
    public let hashCount: Int
    
    private var bits: BitArray
    
    public init(hashes: Set<Hash>, byteCount: Int, hashCount:Int? = nil) {
        self.init(hashes: hashes, data: Data(repeating: 0, count: byteCount), hashCount: hashCount )
    }
    
  
    /// Creates an empty `BloomFilter`.
    ///
    /// - Parameters:
    ///   - expectedCardinality: Expected item count.
    ///   - probabilityOfFalsePositives: Probability of false positives when testing whether an element is contained in the filter.
    public init(expectedCardinality: Int, probabilityOfFalsePositives: Double) {
        let params = BloomFilter.idealParameters(expectedCardinality: expectedCardinality, probabilityOfFalsePositives: probabilityOfFalsePositives)
        self.init(hashes: [], byteCount: Int((Double(params.bitWidth)/8).rounded(.up)) , hashCount: params.hashCount)
    }
    
    public init(hashes: Set<Hash>, data: Data, hashCount: Int? = nil ) {
        // Sort the hashes for consistent decoding output
        self.hashes = Array(hashes.sorted { $0.rawValue < $1.rawValue })
        bits = BitArray(data: data)
        self.hashCount = hashCount ?? self.hashes.count
    }
}

public extension BloomFilter {
    var data: Data { bits.data }

    mutating func insert(_ newMember: T) {
        for index in indices(newMember) {
            bits[index] = true
        }
    }

    func contains(_ member: T) -> Bool {
        indices(member).allSatisfy { bits[$0] }
    }
}

private extension BloomFilter {
    func indices(_ member: T) -> [Int] {
        
    /// Hashes an element by mapping its sequence of bytes to an integer hash value.
    /// - Parameter value: string to hash.
    /// - Returns: Integer hash value.
        if hashes.isEmpty && self.hashCount > 0   {
            return (0..<self.hashCount).map({ seed -> Int in
                var hasher = Hasher()
                hasher.combine(member)
                hasher.combine(seed)
                let hashValue = abs(hasher.finalize())
                return hashValue
            })
        }
        return hashes.map { abs($0.apply(member)) % bits.bitCount }
    }
}

extension BloomFilter {

    /// Approximates the `bitWidth` and `hashCount` for a filter that is expected to contain `expectedCardinality` items
    /// and have a `p` probability of false positives.
    ///
    /// - Parameters:
    ///   - expectedCardinality: Number of items that the filter is exptected to contain.
    ///   - p: Probability of false positives.
    /// - Returns: Pair of (`bitWidth`, `hashCount`) to use with the `init(bitWidth:hashCount:)` initializer.
    public static func idealParameters(expectedCardinality: Int,
                                       probabilityOfFalsePositives p: Double) -> (bitWidth: Int, hashCount: Int) {

        let n = Double(expectedCardinality)
        let m = -1 * n * log(p) / pow(log(2), 2)
        let k = m / n * log(2)
        return (Int(m.rounded(.up)), Int(k.rounded(.up)))

    }

}
