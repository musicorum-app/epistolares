/// Maps `items` concurrently, `maxConcurrent` at a time, preserving input order in the result
func mapConcurrently<Item: Sendable, Result: Sendable>(
    _ items: [Item],
    maxConcurrent: Int = 5,
    _ transform: @escaping @Sendable (Item) async throws -> Result
) async throws -> [Result] {
    var results = [Result?](repeating: nil, count: items.count)
    var index = items.startIndex

    while index < items.endIndex {
        let batchEnd = items.index(index, offsetBy: maxConcurrent, limitedBy: items.endIndex) ?? items.endIndex
        try await withThrowingTaskGroup(of: (Int, Result).self) { group in
            for i in index..<batchEnd {
                let item = items[i]
                group.addTask { (i, try await transform(item)) }
            }
            for try await (i, result) in group {
                results[i] = result
            }
        }
        index = batchEnd
    }

    return results.map { $0! }
}
