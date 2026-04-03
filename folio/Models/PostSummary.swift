import Foundation

struct PostSummary: Identifiable {
    let id: UUID = UUID()
    let fileURL: URL
    let title: String
    let date: Date
    let slug: String
    let categories: [String]
    let tags: [String]
    let series: String
    let isDraft: Bool
    let bodyText: String
}
