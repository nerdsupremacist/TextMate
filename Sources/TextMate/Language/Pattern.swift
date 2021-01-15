
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
                        if let captured = match[Int(index)] {
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
                if let next = next {
                    let nextStart = beginMatches[next]
                    scanner.begin(in: start.range.upperBound..<nextStart.range.lowerBound)
                } else {
                    scanner.begin(from: start.range.upperBound)
                }

                guard let end = try scanner.first(pattern: wrapped.end) else {
                    scanner.rollback()

                    if let actualNext = next, actualNext < beginMatches.count - 1 {
                        next = actualNext + 1
                    } else {
                        current += 1
                        next = beginMatches.count > (current + 1) ? current + 1 : nil
                    }

                    continue
                }

                scanner.rollback()
                if let kind = name?.kind {
                    scanner.kind(kind)
                }

                if let beginCaptures = wrapped.beginCaptures {
                    for (index, capture) in beginCaptures {
                        if let captured = start[Int(index)] {
                            scanner.begin(in: captured.range)
                            scanner.kind(capture.name.kind)
                            scanner.annotate(key: "value", value: String(captured.text))
                            scanner.commit()
                        }
                    }
                }

                scanner.begin(in: start.range.upperBound..<end.range.lowerBound)
                if let contentName = wrapped.contentName {
                    scanner.kind(contentName.kind)
                }

                for pattern in wrapped.patterns ?? [] {
                    try pattern.visit(scanner: scanner)
                }
                scanner.commit()


                if let endCaptures = wrapped.endCaptures {
                    for (index, capture) in endCaptures {
                        if let captured = end[Int(index)] {
                            scanner.begin(in: captured.range)
                            scanner.kind(capture.name.kind)
                            scanner.annotate(key: "value", value: String(captured.text))
                            scanner.commit()
                        }
                    }
                }

                scanner.commit()
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
