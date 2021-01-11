
import Foundation

enum ParsedPattern: Decodable {
    enum CodingKeys: String, CodingKey {
        case include
    }

    enum Include: Decodable {
        case repository(String)
        case grammar

        init(from decoder: Decoder) throws {
            let string = try String(from: decoder)

            if string.hasPrefix("#") {
                self = .repository(String(string.dropFirst()))
                return
            }

            if string == "$self" {
                self = .grammar
                return
            }

            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalud include \(string)"))
        }
    }

    struct Concrete: Decodable {
        enum CodingKeys: String, CodingKey {
            case name
            case repository
        }

        let name: Name?
        let repository: [String : ParsedPattern]
        let functionality: PatternFunctionality<ParsedPattern>

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(Name.self, forKey: .name)
            self.repository = try container.decodeIfPresent([String : ParsedPattern].self, forKey: .repository) ?? [:]
            self.functionality = try PatternFunctionality(from: decoder)
        }
    }

    case concrete(Concrete)
    case include(Include)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let include = try container.decodeIfPresent(Include.self, forKey: .include) {
            self = .include(include)
        } else {
            self = .concrete(try Concrete(from: decoder))
        }
    }
}

extension ParsedPattern {

    func pattern(using repository: [String : Pattern], language: Language) throws -> Pattern {
        switch self {
        case .include(.repository(let name)):
            guard let pattern = repository[name] else {
                throw LanguageError.includedPatternNotFound(name)
            }
            return pattern
        case .include(.grammar):
            return Pattern(name: nil, functionality: .grammar(language))
        case .concrete(let contrete):
            let repository = try contrete.repository.patterns(using: language, previous: repository)
            let pattern = Pattern(name: contrete.name, functionality: nil)
            pattern.functionality = try contrete.functionality.map { parsed in
                let child = try parsed.pattern(using: repository, language: language)
                child.parent = pattern
                return child
            }
            return pattern
        }
    }

}
