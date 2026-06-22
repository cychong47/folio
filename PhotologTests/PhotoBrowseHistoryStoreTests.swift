import XCTest
@testable import Photolog

final class PhotoBrowseHistoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PhotoBrowseHistoryStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordStoresMostRecentRangeFirst() {
        let store = PhotoBrowseHistoryStore(defaults: defaults)
        let first = date("2026-03-15")
        let second = date("2026-03-20")

        store.record(startDate: first, endDate: first, noLocationTimeZone: nil)
        store.record(startDate: second, endDate: second, noLocationTimeZone: TimeZone(secondsFromGMT: 9 * 3600))

        let ranges = store.recentRanges()
        XCTAssertEqual(ranges.map(\.startDate), [second, first])
        XCTAssertEqual(ranges.first?.noLocationOffsetSeconds, 9 * 3600)
    }

    func testRecordDeduplicatesEquivalentRangesAndLimitsHistory() {
        let store = PhotoBrowseHistoryStore(defaults: defaults, limit: 3)
        let day1 = date("2026-03-01")
        let day2 = date("2026-03-02")
        let day3 = date("2026-03-03")
        let day4 = date("2026-03-04")

        store.record(startDate: day1, endDate: day1, noLocationTimeZone: nil)
        store.record(startDate: day2, endDate: day2, noLocationTimeZone: nil)
        store.record(startDate: day3, endDate: day3, noLocationTimeZone: nil)
        store.record(startDate: day2, endDate: day2, noLocationTimeZone: nil)
        store.record(startDate: day4, endDate: day4, noLocationTimeZone: nil)

        XCTAssertEqual(store.recentRanges().map(\.startDate), [day4, day2, day3])
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)!
    }
}
