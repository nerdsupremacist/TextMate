
import Foundation
import SyntaxTree

class Scanner {
    private class Storage {
        var kind: Kind? = nil
        var range: Range<String.Index>
        let parent: Storage?

        var children: [MutableSyntaxTree] = []
        var annotations: [String : Encodable] = [:]

        init(range: Range<String.Index>, parent: Storage?) {
            self.range = range
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

    func annotate(key: String, value: String) {
        storage.annotations[key] = value
    }

    func begin(from range: String.Index) {
        storage = Storage(range: range..<text.endIndex, parent: storage)
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
            expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        }

        regularExpressions[pattern] = expression
        return expression
    }

    private func take(expression: NSRegularExpression) throws -> [ExpressionMatch] {
        let rangeToLookAt = NSRange(storage.range, in: text)
        let matches = expression.matches(in: text, range: rangeToLookAt)
        return matches
            .map { ExpressionMatch(source: text, match: $0) }
            .filter { !$0.range.isEmpty }
    }

    private func take(expression: NSRegularExpression, index: Int) throws -> ExpressionMatch? {
        let matches = try take(expression: expression)
        guard matches.count > index else { return matches.last }
        return matches[index]
    }

}

extension Sequence where Element == MutableSyntaxTree {

    func cleanUp() -> [MutableSyntaxTree] {
        var results = [MutableSyntaxTree]()

        for tree in self {
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
                    if tree.tryInserting(conflict) {
                        break
                    }
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

        return results.sorted { $0.range.lowerBound < $1.range.lowerBound }
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

        var lastIndex = other.range.lowerBound
        for childIndex in children.indices {
            let child = children[childIndex]
            if (lastIndex..<child.range.lowerBound).contains(other.range) {
                children.insert(other, at: lastIndex)
                return true
            }

            if child.range.contains(other.range) {
                return child.tryInserting(other)
            }

            lastIndex = child.range.upperBound
        }

        return false
    }

}

extension Range {

    func contains(_ other: Range<Bound>) -> Bool {
        return lowerBound <= other.lowerBound && upperBound >= other.upperBound
    }

}


extension MutableSyntaxTree {

    func matchedCharacters() -> Int {
        if children.isEmpty {
            return range.count
        }

        return children.reduce(0) { $0 + $1.matchedCharacters() }
    }

}

