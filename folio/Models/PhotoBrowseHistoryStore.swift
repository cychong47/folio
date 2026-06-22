import Foundation

struct RecentPhotoBrowseRange: Identifiable, Codable, Equatable {
    let startDate: Date
    let endDate: Date
    let noLocationOffsetSeconds: Int?

    var id: String {
        "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)-\(noLocationOffsetSeconds ?? Int.min)"
    }
}

struct PhotoBrowseHistoryStore {
    private let defaults: UserDefaults
    private let limit: Int
    private let key = Constants.UserDefaultsKeys.recentPhotoBrowseRanges

    init(
        defaults: UserDefaults = UserDefaults(suiteName: Constants.appGroupID) ?? .standard,
        limit: Int = 5
    ) {
        self.defaults = defaults
        self.limit = limit
    }

    func recentRanges() -> [RecentPhotoBrowseRange] {
        guard let data = defaults.data(forKey: key),
              let ranges = try? JSONDecoder().decode([RecentPhotoBrowseRange].self, from: data) else {
            return []
        }
        return Array(ranges.prefix(limit))
    }

    func record(startDate: Date, endDate: Date, noLocationTimeZone: TimeZone?) {
        let range = RecentPhotoBrowseRange(
            startDate: startDate,
            endDate: endDate,
            noLocationOffsetSeconds: noLocationTimeZone?.secondsFromGMT()
        )
        var ranges = recentRanges().filter { $0 != range }
        ranges.insert(range, at: 0)
        ranges = Array(ranges.prefix(limit))
        if let data = try? JSONEncoder().encode(ranges) {
            defaults.set(data, forKey: key)
        }
    }
}
