
import Foundation

enum LanguageError: Error {
    case includedPatternNotFound(String)
    case includingEntireGrammarNotSupportedYet
}
