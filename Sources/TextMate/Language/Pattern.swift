
import Foundation
import SyntaxTree

public final class Pattern {
    let id = UUID()
	public let name: Name?
    public internal(set) var functionality: PatternFunctionality<Pattern>!
    public internal(set) weak var parent: Pattern? = nil

    init(name: Name?, functionality: PatternFunctionality<Pattern>!, parent: Pattern? = nil) {
        self.name = name
        self.functionality = functionality
        self.parent = parent
    }
}

extension Pattern {

    func visit(scanner: Scanner) throws {
        guard !scanner.range.isEmpty else { return }
        switch functionality! {
        case .match(let matched):
            let matches = try scanner.all(pattern: matched.match)
            for match in matches {
                scanner.begin(in: match.range)

                if let kind = name?.kind {
                    scanner.kind(kind)
                }

                if let captures = matched.captures {
                    for (index, capture) in captures {
                        if let captured = match[Int(index)], !captured.range.isEmpty {
                            scanner.begin(in: captured.range)
                            scanner.kind(capture.name.kind)
                            scanner.annotate(key: "value", value: String(captured.text))
                            scanner.commit()
                        }
                    }
                }

                scanner.commit()
            }

        case .wrapped(let wrapped):
            let beginMatches = try scanner.all(pattern: wrapped.begin)
            guard !beginMatches.isEmpty else { return }
            
            var current = 0
            var next: Int? = beginMatches.count > (current + 1) ? 1 : nil

            while current < beginMatches.count {
                let start = beginMatches[current]
                let nextStart: ExpressionMatch?

                if let next = next {
                    nextStart = beginMatches[next]
                    scanner.begin(in: start.range.upperBound..<nextStart!.range.upperBound)
                } else {
                    nextStart = nil
                    scanner.begin(from: start.range.upperBound)
                }

                let offset = (next ?? beginMatches.count) - current - 1
                guard let end = try scanner.first(pattern: wrapped.end, offsetBy: offset) else {
                    scanner.rollback()

                    if let actualNext = next {
                        if actualNext < beginMatches.count - 1 {
                            next = actualNext + 1
                        } else {
                            next = nil
                        }
                    } else {
                        current += 1
                        next = beginMatches.count > (current + 1) ? current + 1 : nil
                    }

                    continue
                }

                scanner.rollback()
                scanner.begin(in: start.range.lowerBound..<end.range.upperBound)

                if let kind = name?.kind {
                    scanner.kind(kind)
                }

                if let beginCaptures = wrapped.beginCaptures {
                    for (index, capture) in beginCaptures {
                        if let captured = start[Int(index)], !captured.range.isEmpty {
                            scanner.begin(in: captured.range)
                            scanner.kind(capture.name.kind)
                            scanner.annotate(key: "value", value: String(captured.text))
                            scanner.commit()
                        }
                    }
                }

                scanner.begin(in: start.range.upperBound..<end.range.lowerBound)
                let contentKind = wrapped.contentName?.kind ?? name.map { Kind(rawValue: "\($0.description).content") }
                if let contentKind = contentKind {
                    scanner.kind(contentKind)
                }

                for pattern in wrapped.patterns ?? [] {
                    try pattern.visit(scanner: scanner)
                }
                scanner.commit()

                if let endCaptures = wrapped.endCaptures {
                    for (index, capture) in endCaptures {
                        if let captured = end[Int(index)], !captured.range.isEmpty {
                            scanner.begin(in: captured.range)
                            scanner.kind(capture.name.kind)
                            scanner.annotate(key: "value", value: String(captured.text))
                            scanner.commit()
                        }
                    }
                }

                scanner.commit()
                if let nextStart = nextStart, end.range.overlaps(nextStart.range) {
                    current = next! + 1
                } else {
                    current = next ?? max(current + 1, beginMatches.count - 1)
                }
                next = beginMatches.count > (current + 1) ? current + 1 : nil
            }

        case .group(let patterns):
            for pattern in patterns {
                try pattern.visit(scanner: scanner)
            }

        case .grammar(let language):
            try language.visit(scanner: scanner)

        }
    }

}
