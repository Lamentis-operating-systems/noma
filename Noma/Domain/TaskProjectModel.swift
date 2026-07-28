import Foundation

struct TaskProject: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let symbolName: String
    let colorIndex: Int
    let expiresAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "folder",
        colorIndex: Int = 0,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.colorIndex = colorIndex
        self.expiresAt = expiresAt
    }
}
