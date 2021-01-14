
import Foundation
import Syntax

class PatternParserStorage {
    var parsers: [UUID : AnyParser<Void>] = [:]

    func parser(for pattern: Pattern) -> AnyParser<Void> {
        if let parser = parsers[pattern.id] {
            return parser
        }

        let parser = _parser(for: pattern)
        parsers[pattern.id] = parser
        return parser
    }

    func _parser(for pattern: Pattern) -> AnyParser<Void> {
        switch pattern.functionality! {
        case .match(let matched):
            return MatchPattern(matched: matched).kind(pattern.name?.kind, using: .separate)
        case .wrapped(let wrapped):
            return WrappedPattern(storage: self, wrapped: wrapped).kind(pattern.name?.kind, using: .separate)
        case .group(let patterns):
            return GroupPattern(storage: self, patterns: patterns).kind(pattern.name?.kind, using: .separate)
        case .grammar(let language):
            return TextMate(language: language).kind(pattern.name?.kind, using: .separate)
        }
    }
}

private struct MatchPattern: Parser {
    static let kind: Kind? = nil

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
    static let kind: Kind? = nil

    let storage: PatternParserStorage
    let wrapped: PatternFunctionality<Pattern>.Wrapped

    var body: AnyParser<Void> {
        Recursive { _ in
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

            Either {
                Either(wrapped.patterns ?? []) { pattern in
                    storage.parser(for: pattern)
                }

                AnyCharacter()
            }
            .kind(wrapped.contentName?.kind)
            .repeatUntil {
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
    }
}

private struct GroupPattern: Parser {
    static let kind: Kind? = nil

    let storage: PatternParserStorage
    let patterns: [Pattern]

    var body: AnyParser<Void> {
        Recursive { _ in
            Either {
                Either(patterns) { pattern in
                    storage.parser(for: pattern)
                }
            }
        }
    }
}
