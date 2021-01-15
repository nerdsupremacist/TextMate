
import Foundation

public struct CaptureCollection: Decodable, Sequence {
    struct CodingKeys: CodingKey {
        let value: UInt

        var stringValue: String {
            return String(value)
        }

        var intValue: Int? {
            return Int(value)
        }

        init?(intValue: Int) {
            guard intValue >= 0 else { return nil }
            self.value = UInt(intValue)
        }

        init?(stringValue: String) {
            guard let int = UInt(stringValue) else { return nil }
            self.value = int
        }
    }

    private let captures: [UInt: Capture]

    var captureIndexes: [UInt] {
        return Array(captures.keys).sorted()
    }

    public init(from decoder: Decoder) throws {
        let decoder = try decoder.container(keyedBy: CodingKeys.self)
        var captures = [UInt : Capture]()

        for key in decoder.allKeys {
            do {
                captures[key.value] = try decoder.decode(Capture.self, forKey: key)
            } catch {
                captures[key.value] = Capture(name: Name(string: String(key.value)))
            }
        }

        self.captures = captures
    }

    subscript(index: UInt) -> Capture? {
        return captures[index]
    }

    public func makeIterator() -> Dictionary<UInt, Capture>.Iterator {
        return captures.makeIterator()
    }
}
