import Foundation

struct Bookmark: Identifiable, Codable {
    let id: UUID
    let title: String
    let url: String
    let dateAdded: Date

    init(id: UUID = UUID(), title: String, url: String, dateAdded: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.dateAdded = dateAdded
    }
}
