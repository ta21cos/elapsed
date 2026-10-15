import XCTest
@testable import Elapsed

final class PerfCSVWriterTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("perf-csv-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeWriter(maxBytes: Int = 1_048_576) -> PerfCSVWriter {
        PerfCSVWriter(fileURL: directory.appendingPathComponent("perf.csv"), maxBytes: maxBytes)
    }

    private func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func testFirstAppendCreatesTheDirectoryAndWritesTheHeader() throws {
        let writer = makeWriter()

        try writer.append(header: "a,b", row: "1,2")

        XCTAssertEqual(try contents(of: writer.fileURL), "a,b\n1,2\n")
    }

    func testLaterAppendsAddOnlyTheRow() throws {
        let writer = makeWriter()

        try writer.append(header: "a,b", row: "1,2")
        try writer.append(header: "a,b", row: "3,4")

        XCTAssertEqual(try contents(of: writer.fileURL), "a,b\n1,2\n3,4\n")
    }

    func testChangedColumnsMoveTheOldFileAsidePreviousAndStartANewOne() throws {
        let writer = makeWriter()

        try writer.append(header: "a,b", row: "1,2")
        try writer.append(header: "a,b,c", row: "3,4,5")

        XCTAssertEqual(try contents(of: writer.fileURL), "a,b,c\n3,4,5\n")
        XCTAssertEqual(try contents(of: writer.previousFileURL), "a,b\n1,2\n")
    }

    func testFileOverTheSizeLimitIsRotatedReplacingTheOlderPreviousFile() throws {
        // ヘッダーと 2 行で 12 バイトに達するため、3 行目と 5 行目の書き込みの前に退避が起きる
        let writer = makeWriter(maxBytes: 12)

        for row in ["1,2", "3,4", "5,6", "7,8", "9,0"] {
            try writer.append(header: "a,b", row: row)
        }

        XCTAssertEqual(try contents(of: writer.fileURL), "a,b\n9,0\n")
        XCTAssertEqual(try contents(of: writer.previousFileURL), "a,b\n5,6\n7,8\n")
    }
}
