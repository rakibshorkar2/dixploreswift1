import Foundation

struct Bookmark: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
    let dateAdded: Date

    enum CodingKeys: String, CodingKey {
        case id, title, url, dateAdded
    }
}
