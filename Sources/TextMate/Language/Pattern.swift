
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
                        if let value = match[Int(index)]?.text {
                            scanner.annotate(key: capture.name, value: String(value))
                        }
                    }
                }

                scanner.commit()
            }

        case .wrapped(let wrapped):
            let beginMatches = try scanner.all(pattern: wrapped.begin)
            for start in beginMatches {
                scanner.begin(from: start.range.upperBound)

                guard let end = try scanner.first(pattern: wrapped.end) else {
                    scanner.rollback()
                    continue
                }

                scanner.rollback()
                scanner.begin(in: start.range.lowerBound..<end.range.upperBound)
                if let kind = name?.kind {
                    scanner.kind(kind)
                }

                if let beginCaptures = wrapped.beginCaptures {
                    for (index, capture) in beginCaptures {
                        if let value = start[Int(index)]?.text {
                            scanner.annotate(key: capture.name, value: String(value))
                        }
                    }
                }

                if let endCaptures = wrapped.endCaptures {
                    for (index, capture) in endCaptures {
                        if let value = end[Int(index)]?.text {
                            scanner.annotate(key: capture.name, value: String(value))
                        }
                    }
                }

                if let contentName = wrapped.contentName {
                    scanner.begin(in: start.range.upperBound..<end.range.lowerBound)
                    scanner.kind(contentName.kind)
                    scanner.commit()

                    for pattern in wrapped.patterns ?? [] {
                        try pattern.visit(scanner: scanner)
                    }
                    scanner.commit()
                } else {
                    for pattern in wrapped.patterns ?? [] {
                        try pattern.visit(scanner: scanner)
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
