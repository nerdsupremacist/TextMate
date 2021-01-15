
import Foundation
import SyntaxTree

class Scanner {
    private class Storage {
        var kind: Kind? = nil
        var range: Range<String.Index>
        let parent: Storage?

        var children: [MutableSyntaxTree] = []
        var occupied: [Range<String.Index>] = []
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

            return MutableSyntaxTree(range: startOffset..<endOffset,
                                     location: lineColumnIndex[startOffset]!..<lineColumnIndex[endOffset]!,
                                     annotations: annotations,
                                     children: children)
        }
    }

    private let text: String
    private let lineColumnIndex: LineColumnIndex
    private var storage: Storage
    private var regularExpressions: [String : NSRegularExpression] = [:]

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
        let expression: NSRegularExpression
        if let stored = regularExpressions[pattern] {
            expression = stored
        } else {
            do {
                expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .allowCommentsAndWhitespace])
                regularExpressions[pattern] = expression
            } catch {
                return []
            }
        }

        return try take(expression: expression)
    }

    func first(pattern: String) throws -> ExpressionMatch? {
        let expression: NSRegularExpression
        if let stored = regularExpressions[pattern] {
            expression = stored
        } else {
            do {
                expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .allowCommentsAndWhitespace])
                regularExpressions[pattern] = expression
            } catch {
                return nil
            }
        }

        return try take(expression: expression)
    }

    func syntaxTree() -> SyntaxTree {
        return storage.syntaxTree(in: text, with: lineColumnIndex).build()
    }

    private func take(expression: NSRegularExpression) throws -> [ExpressionMatch] {
        let rangeToLookAt = NSRange(storage.range, in: text)
        let matches = expression.matches(in: text, options: .anchored, range: rangeToLookAt)
        return matches.map { ExpressionMatch(source: text, match: $0) }
    }

    private func take(expression: NSRegularExpression) throws -> ExpressionMatch? {
        let rangeToLookAt = NSRange(storage.range, in: text)
        let match = expression.firstMatch(in: text, options: .anchored, range: rangeToLookAt)
        return match.map { ExpressionMatch(source: text, match: $0) }
    }

}
