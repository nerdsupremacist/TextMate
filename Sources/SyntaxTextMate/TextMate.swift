
import Syntax

public struct TextMate: Parser {
    let storage = PatternParserStorage()
    let language: Language

    public init(language: Language) {
        self.language = language
    }

    public var body: AnyParser<Void> {
        Either {
            Either(language.patterns) { pattern in
                storage.parser(for: pattern)
            }

            AnyCharacter()
        }
        .star()
        .kind("programm", using: .separate)
        .annotate {
            return ["language" : language.name]
        }
    }
}
