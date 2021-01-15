
import Foundation
import SyntaxTree

class Scanner {
    private class Storage {
        var kind: Kind? = nil
        var range: Range<String.Index>
        let parent: Storage?

        var children: [MutableSyntaxTree] = []
        var occupied: [Range<String.Index>]
        var annotations: [String : Encodable] = [:]

        init(range: Range<String.Index>, parent: Storage?) {
            self.range = range
            self.occupied = parent?.occupied ?? []
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
                                     children: children.sorted(by: { $0.location.lowerBound < $1.location.lowerBound }))
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
        parent.occupied.append(storage.range)
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

    func visit(patterns: [Pattern]) throws {
        var patterns = patterns
        while let index = try visitLargestStep(from: patterns) {
            patterns.remove(at: index)
        }
    }

    private func visitLargestStep(from patterns: [Pattern]) throws -> Int? {
        var largestSize = 0
        var current: (Storage, Int)? = nil
        for (offset, pattern) in patterns.enumerated() {
            begin(in: storage.range)
            try pattern.visit(scanner: self)
            let size = storage.children.first.map { $0.range.lowerBound..<storage.children.last!.range.upperBound }?.count ?? 0
            if largestSize < size {
                largestSize = size
                current = (storage, offset)
            }
            rollback()
        }

        if let current = current {
            storage = current.0
            commit()
        }
        return current?.1
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

    private func alreadyOccupied(range: Range<String.Index>) -> Bool {
        for occupied in storage.occupied {
            if occupied.overlaps(range) {
                return true
            }
        }

        return false
    }

    private func take(expression: NSRegularExpression) throws -> [ExpressionMatch] {
        let rangeToLookAt = NSRange(storage.range, in: text)
        let matches = expression.matches(in: text, range: rangeToLookAt)
        return matches
            .map { ExpressionMatch(source: text, match: $0) }
            .filter { match in
                !match.range.isEmpty && !alreadyOccupied(range: match.range)
            }
    }

    private func take(expression: NSRegularExpression, index: Int) throws -> ExpressionMatch? {
        let matches = try take(expression: expression)
        guard matches.count > index else { return matches.last }
        return matches[index]
    }

}
