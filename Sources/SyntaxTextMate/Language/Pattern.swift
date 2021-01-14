
import Foundation

public final class Pattern {
    let id = UUID()
	public let name: Name?
    public internal(set) var functionality: PatternFunctionality<Pattern>!
    public internal(set) weak var parent: Pattern? = nil

    init(name: Name?, functionality: PatternFunctionality<Pattern>!, parent: Pattern? = nil) {
        self.name = name
        self.functionality = functionality
        self.parent = parent
    }
}
