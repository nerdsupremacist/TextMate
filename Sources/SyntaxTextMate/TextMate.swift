
import Syntax

public struct TextMate: Parser {
    let language: Language

    public init(language: Language) {
        self.language = language
    }

    public var body: AnyParser<Void> {
        Either(language.patterns) { pattern in
            TextMatePattern(pattern: pattern)
        }
        .kind("programm")
        .annotate {
            return ["language" : language.name]
        }
    }
}

private struct TextMatePattern: Parser {
    let pattern: Pattern

    var body: AnyParser<Void> {
        Group { () -> AnyParser<Void> in
            switch pattern.functionality! {
            case .match(let matched):
                return MatchPattern(matched: matched).eraseToAnyParser()
            case .wrapped(let wrapped):
                return WrappedPattern(wrapped: wrapped).eraseToAnyParser()
            case .group(let patterns):
                return GroupPattern(patterns: patterns).eraseToAnyParser()
            case .grammar(let language):
                return TextMate(language: language).eraseToAnyParser()
            }
        }
        .kind(pattern.name?.description)
    }
}

private struct MatchPattern: Parser {
    let matched: PatternFunctionality<Pattern>.Matched

    var body: AnyParser<Void> {
        Leaf {
            RegularExpression(matched.match)
        }
        .annotate { match in
            if let captures = matched.captures {
                let matchedGroups = captures.map { (index, capture) in
                    return (capture.name.description, match[Int(index)])
                }

                return Dictionary(uniqueKeysWithValues: matchedGroups).compactMapValues { $0.map { String($0.text) } }
            } else {
                return ["value" : String(match.text)]
            }
        }
        .ignoreOutput()
    }
}

private struct WrappedPattern: Parser {
    let wrapped: PatternFunctionality<Pattern>.Wrapped

    var body: AnyParser<Void> {
        Leaf {
            RegularExpression(wrapped.begin)
        }
        .annotate { match in
            let matchedGroups = wrapped.beginCaptures?.map { (index, capture) in
                return (capture.name.description, match[Int(index)])
            } ?? []

            return Dictionary(matchedGroups) { $1 ?? $0 }
                .compactMapValues { $0.map { String($0.text) } }
        }
        .ignoreOutput()

        Either(wrapped.patterns ?? []) { pattern in
            TextMatePattern(pattern: pattern)
        }

        Leaf {
            RegularExpression(wrapped.end)
        }
        .annotate { match in
            let matchedGroups = wrapped.endCaptures?.map { (index, capture) in
                return (capture.name.description, match[Int(index)])
            } ?? []

            return Dictionary(uniqueKeysWithValues: matchedGroups).compactMapValues { $0.map { String($0.text) } }
        }
        .ignoreOutput()
    }
}

private struct GroupPattern: Parser {
    let patterns: [Pattern]

    var body: AnyParser<Void> {
        Either(patterns) { pattern in
            TextMatePattern(pattern: pattern)
        }
    }
}
