
import Foundation
import SyntaxTree

class Scanner {
    private class Storage {
        var kind: Kind? = nil
        var range: Range<String.Index>
        var searchableRange: Range<String.Index>
        let parent: Storage?

        var children: [MutableSyntaxTree] = []
        var annotations: [String : Encodable] = [:]

        init(range: Range<String.Index>, searchableRange: Range<String.Index>, parent: Storage?) {
            self.range = range
            self.searchableRange = searchableRange
            self.parent = parent
        }

        init(range: Range<String.Index>, parent: Storage?) {
            self.range = range
            self.searchableRange = range
            self.parent = parent
        }

        func syntaxTree(in text: String, with lineColumnIndex: LineColumnIndex) -> MutableSyntaxTree {
            let startIndex = range.lowerBound
            let endIndex = range.upperBound
            let startOffset = text.distance(from: text.startIndex, to: startIndex)
            let endOffset = text.distance(from: text.startIndex, to: endIndex)

            return MutableSyntaxTree(kind: kind,
                                     range: startOffset..<endOffset,
                                     location: lineColumnIndex[startOffset]!..<lineColumnIndex[endOffset]!,
                                     annotations: annotations,
                                     children: children.cleanUp())
        }
    }

    private let text: String
    private let lineColumnIndex: LineColumnIndex
    private var storage: Storage
    private var regularExpressions: [String : NSRegularExpression] = [:]

    var range: Range<String.Index> {
        return storage.range
    }

    init(text: String) {
        self.text = text
        self.lineColumnIndex = LineColumnIndex(string: text)
        self.storage = Storage(range: text.startIndex..<text.endIndex, parent: nil)
    }

    func kind(_ kind: Kind) {
        storage.kind = kind
    }

    func annotate(key: String, value: Encodable) {
        storage.annotations[key] = value
    }

    func begin(from start: String.Index) {
        storage = Storage(range: start..<storage.range.upperBound, searchableRange: start..<text.endIndex, parent: storage)
    }

    func begin(in range: Range<String.Index>) {
        storage = Storage(range: range, parent: storage)
    }

    func rollback() {
        guard let parent = storage.parent else { return }
        storage = parent
    }

    func commit() {
        guard let parent = storage.parent else { return }
        parent.children.append(storage.syntaxTree(in: text, with: lineColumnIndex))
        storage = parent
    }

    func all(pattern: String) throws -> [ExpressionMatch] {
        let expression = try self.expression(for: pattern)
        return try take(expression: expression)
    }

    func first(pattern: String, offsetBy index: Int) throws -> ExpressionMatch? {
        let expression = try self.expression(for: pattern)
        return try take(expression: expression, index: index)
    }

    func syntaxTree() -> SyntaxTree {
        return storage.syntaxTree(in: text, with: lineColumnIndex).build()
    }

    private func expression(for pattern: String) throws -> NSRegularExpression {
        if let stored = regularExpressions[pattern] {
            return stored
        }

        let expression: NSRegularExpression
        do {
            expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .allowCommentsAndWhitespace])
        } catch {
            do {
                expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            } catch {
                expression = try NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: pattern),
                                                     options: [.anchorsMatchLines])
            }
        }

        regularExpressions[pattern] = expression
        return expression
    }

    private func take(expression: NSRegularExpression) throws -> [ExpressionMatch] {
        let rangeToLookAt = NSRange(storage.searchableRange, in: text)
        let matches = expression.matches(in: text, range: rangeToLookAt)
        return matches
            .map { ExpressionMatch(source: text, match: $0) }
            .filter { storage.range.contains($0.range) }
    }

    private func take(expression: NSRegularExpression, index: Int) throws -> ExpressionMatch? {
        let matches = try take(expression: expression)
        guard matches.indices.contains(index) else { return nil }
        return matches[index]
    }

}

extension Sequence where Element == MutableSyntaxTree {

    func cleanUp() -> [MutableSyntaxTree] {
        var results = [MutableSyntaxTree]()

        for tree in self {
            guard let tree = tree.cleanUp() else { continue }
            let conflicts = results.filter { $0.range.overlaps(tree.range) }
            guard !conflicts.isEmpty else {
                results.append(tree)
                continue
            }

            // check that the net gain in characters is worth changing it
            let sumOfCharactersInConflicts = conflicts.reduce(0) { $0 + $1.matchedCharacters() }
            if sumOfCharactersInConflicts < tree.matchedCharacters() {
                results.removeAll { $0.range.overlaps(tree.range) }
                for conflict in conflicts {
                    tree.tryInserting(conflict)
                }
                results.append(tree)
            } else {
                for conflict in conflicts {
                    if conflict.tryInserting(tree) {
                        break
                    }
                }
            }
        }

        return results
            .filter { !$0.range.isEmpty }
            .filter { $0.kind != nil || !$0.annotations.isEmpty || !$0.children.isEmpty }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

}

extension MutableSyntaxTree {

    @discardableResult
    func tryInserting(_ other: MutableSyntaxTree) -> Bool {
        guard range.contains(other.range) else { return false }

        guard other.kind != nil else {
            var worked = false
            for child in other.children {
                worked = worked || tryInserting(child)
            }
            return worked
        }

        if kind == nil, range == other.range {
            kind = other.kind
            annotations.merge(other.annotations) { $1 }
            return true
        }

        if kind == other.kind, range == other.range, children.count == other.children.count {
            return false
        }

        for child in children {
            if child.range.contains(other.range) {
                return child.tryInserting(other)
            }
        }

        var worked = false
        for child in other.children {
            worked = worked || tryInserting(child)
        }
        return worked
    }

}

extension Range {

    func contains(_ other: Range<Bound>) -> Bool {
        return lowerBound <= other.lowerBound && upperBound >= other.upperBound
    }

}


extension MutableSyntaxTree {

    func cleanUp() -> MutableSyntaxTree? {
        guard !range.isEmpty else { return nil }
        guard kind == nil, annotations.isEmpty else { return self }
        guard !children.isEmpty else { return nil }

        if children.count == 1 {
            return children[0]
        } else {
            return self
        }
    }

    func matchedCharacters() -> Int {
        if let kind = kind, kind.rawValue.contains("invalid") {
            return 0
        }

        if children.isEmpty {
            return range.count
        }

        return children.reduce(0) { $0 + $1.matchedCharacters() }
    }

}
