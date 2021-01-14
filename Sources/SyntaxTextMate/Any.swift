
import Foundation
import Syntax

struct AnyCharacter: Parser {
    var body: AnyParser<Void> {
        Leaf {
            RegularExpression(".|\\n")
                .ignoreOutput()
        }
    }
}
