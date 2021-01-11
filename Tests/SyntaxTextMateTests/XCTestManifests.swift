import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(syntax_text_mateTests.allTests),
    ]
}
#endif
