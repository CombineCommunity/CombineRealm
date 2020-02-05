import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CombineRealmTests.allTests),
    ]
}
#endif
