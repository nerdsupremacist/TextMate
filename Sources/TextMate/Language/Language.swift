
import Foundation
import SyntaxTree

public final class Language: Decodable {
    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case scopeName
        case repository
        case patterns
    }

	public let uuid: String
	public let name: String
	public let scopeName: String
	public var patterns: [Pattern] = []

    var kind: Kind {
        return Kind(rawValue: "programm.\(name.lowercased())")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(String.self, forKey: .uuid)
        self.name = try container.decode(String.self, forKey: .name)
        self.scopeName = try container.decode(String.self, forKey: .scopeName)

        let patterns = try container.decode([ParsedPattern].self, forKey: .patterns)
        let repository = try container.decodeIfPresent([String : ParsedPattern].self, forKey: .repository) ?? [:]
        let repositoryPatterns = try repository.patterns(using: self)
        self.patterns = try patterns.map { try $0.pattern(using: repositoryPatterns, language: self) }
    }
}

extension Language: SyntaxTreeFactory {
    public func parse(_ text: String) throws -> SyntaxTree {
        let scanner = Scanner(text: text)
        try visit(scanner: scanner)
        scanner.kind(kind)
        scanner.annotate(key: "scopeName", value: scopeName)
        scanner.annotate(key: "language", value: name)
        return scanner.syntaxTree()
    }
}

extension Language {

    func visit(scanner: Scanner) throws {
        guard !scanner.range.isEmpty else { return }
        for pattern in patterns {
            try pattern.visit(scanner: scanner)
        }
    }

}

extension Dictionary where Key == String, Value == ParsedPattern {

    func patterns(using language: Language, previous repository: [String : Pattern] = [:]) throws -> [String : Pattern] {
        var patterns = repository

        for (name, parsed) in self {
            switch parsed {
            case .include(.repository(let includedName)):
                guard let pattern = patterns[includedName] else {
                    throw LanguageError.includedPatternNotFound(includedName)
                }
                patterns[name] = pattern
            case .include(.grammar):
                let pattern = Pattern(name: Name(string: name), functionality: .grammar(language))
                patterns[name] = pattern
            case .concrete(let contrete):
                let pattern = Pattern(name: contrete.name ?? Name(string: name), functionality: nil)
                patterns[name] = pattern
            }
        }

        for (name, pattern) in patterns {
            guard case .some(.concrete(let concrete)) = self[name] else { continue }
            let repository = try concrete.repository.patterns(using: language, previous: patterns)
            pattern.functionality = try concrete.functionality.map { try $0.pattern(using: repository, language: language) }
        }

        return patterns
    }

}

