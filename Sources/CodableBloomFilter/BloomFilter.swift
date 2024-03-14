// Copyright © 2020 Metabolist. All rights reserved.

import Foundation

public struct BloomFilter<T: DeterministicallyHashable>: Codable {
    enum CodingKeys: String, CodingKey {
        case hashes
        case hashSeeds
        case bits = "data"
    }
    
    public let hashes: [Hash]
    
    public let hashSeeds: [String]
    
    private var bits: BitArray
    
    public init(hashes: Set<Hash>, byteCount: Int, hashSeeds: [String] = []) {
        self.init(hashes: hashes, data: Data(repeating: 0, count: byteCount), hashSeeds: hashSeeds )
    }
    
  
    public init(hashes: Set<Hash>, data: Data, hashSeeds: [String] = [] ) {
        // Sort the hashes for consistent decoding output
        self.hashes = Array(hashes.sorted { $0.rawValue < $1.rawValue })
        bits = BitArray(data: data)
        self.hashSeeds = hashSeeds
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
        if self.hashSeeds.isEmpty {
            return hashes.map { abs($0.apply(member)) % bits.bitCount }
        }
        
        return self.hashSeeds.enumerated().map( { index, seed in
            abs(self.hashes[index%self.hashes.count].apply(member, seed)) % bits.bitCount
        })
    }
}

extension BloomFilter {

    /// Approximates the `bitWidth` and `hashCount` for a filter that is expected to contain `expectedCardinality` items
    /// and have a `p` probability of false positives.
    ///
    /// - Parameters:
    ///   - expectedCardinality: Number of items that the filter is exptected to contain.
    ///   - p: Probability of false positives.
    /// - Returns: a filter with Pair of (`bitWidth`, `hashSeeds`) and
    public static func idealBloomFilter(expectedCardinality: Int,
                                       probabilityOfFalsePositives p: Double,
                                        hashes: Set<Hash>) -> BloomFilter {

        let n = Double(expectedCardinality)
        let m = -1 * n * log(p) / pow(log(2), 2)
        let k = m / n * log(2)
//        return (Int(m.rounded(.up)), Int(k.rounded(.up)))
        let bitWidth = Int(m.rounded(.up))
        
        let byteCount = Int((Double(bitWidth)/8).rounded(.up))
        let hashCount = Int(k.rounded(.up))
        let hashSeeds = (0..<hashCount).map({_ in String(Int.random(in: 0..<expectedCardinality))})
                           
        return BloomFilter(hashes: hashes, byteCount: byteCount, hashSeeds: hashSeeds)

    }

}
