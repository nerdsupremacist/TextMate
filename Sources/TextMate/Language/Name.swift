
import SyntaxTree

public struct Name: Decodable, Hashable {
    public let sections: [String]

    public var description: String {
        return sections.joined(separator: ".")
    }

    public var kind: Kind {
        return Kind(rawValue: description)
    }

    init(string: String) {
        self.sections = string.components(separatedBy: ".")
    }

    public init(from decoder: Decoder) throws {
        let string = try String(from: decoder)
        self.init(string: string)
    }
}
