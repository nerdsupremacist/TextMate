
import Foundation

public struct Name: Decodable, Hashable {
    public let sections: [String]

    public var description: String {
        return sections.joined(separator: ".")
    }

    init(string: String) {
        self.sections = string.components(separatedBy: ".")
    }

    public init(from decoder: Decoder) throws {
        let string = try String(from: decoder)
        self.init(string: string)
    }
}
