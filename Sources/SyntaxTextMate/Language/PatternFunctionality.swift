
import Foundation

public enum PatternFunctionality<Pattern> {
    public struct Matched: Decodable {
        public let match: String
        public let captures: CaptureCollection?
    }

    public struct Wrapped {
        public let begin: String
        public let beginCaptures: CaptureCollection?
        public let end: String
        public let endCaptures: CaptureCollection?

        public let contentName: String?
        public let patterns: [Pattern]?
    }

    case match(Matched)
    case wrapped(Wrapped)
    case group([Pattern])
    case grammar(Language)
}

extension PatternFunctionality {

    func map<T>(_ transform: (Pattern) throws -> T) rethrows -> PatternFunctionality<T> {
        switch self {
        case .match(let match):
            return .match(PatternFunctionality<T>.Matched(match: match.match, captures: match.captures))
        case .wrapped(let wrapped):
            return .wrapped(PatternFunctionality<T>.Wrapped(begin: wrapped.begin,
                                                            beginCaptures: wrapped.beginCaptures,
                                                            end: wrapped.end,
                                                            endCaptures: wrapped.endCaptures,
                                                            contentName: wrapped.contentName,
                                                            patterns: try wrapped.patterns?.map(transform)))
        case .group(let group):
            return .group(try group.map(transform))
        case .grammar(let grammar):
            return .grammar(grammar)
        }
    }

}

extension PatternFunctionality.Wrapped: Decodable where Pattern: Decodable { }

extension PatternFunctionality: Decodable where Pattern: Decodable {

    enum CodingKeys: String, CodingKey {
        case match
        case begin
        case patterns
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.match) {
            self = .match(try Matched(from: decoder))
        } else if container.contains(.begin) {
            self = .wrapped(try Wrapped(from: decoder))
        } else {
            self = .group(try container.decode([Pattern].self, forKey: .patterns))
        }
    }

}
