import Foundation

struct CreateReminder: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let isCompleted: Bool
    let projectID: TaskProject.ID?
    let createdAt: Date
    let carryForwardCount: Int

    init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        projectID: TaskProject.ID? = nil,
        createdAt: Date = Date(),
        carryForwardCount: Int = 0
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.projectID = projectID
        self.createdAt = createdAt
        self.carryForwardCount = carryForwardCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isCompleted
        case projectID
        case createdAt
        case carryForwardCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(carryForwardCount, forKey: .carryForwardCount)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        projectID = try container.decodeIfPresent(TaskProject.ID.self, forKey: .projectID)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        carryForwardCount = try container.decodeIfPresent(Int.self, forKey: .carryForwardCount) ?? 0
    }

    var wasCarriedForward: Bool {
        carryForwardCount > 0
    }

    func removingProjectAssociation() -> CreateReminder {
        CreateReminder(
            id: id,
            text: text,
            isCompleted: isCompleted,
            createdAt: createdAt,
            carryForwardCount: carryForwardCount
        )
    }

    func togglingCompletion() -> CreateReminder {
        CreateReminder(
            id: id,
            text: text,
            isCompleted: !isCompleted,
            projectID: projectID,
            createdAt: createdAt,
            carryForwardCount: carryForwardCount
        )
    }
}

enum CreateReminderCarryForwardCompletion {
    static func completing(_ reminder: CreateReminder, in reminders: [CreateReminder]) -> [CreateReminder] {
        reminders.map { storedReminder in
            storedReminder.id == reminder.id && !storedReminder.isCompleted
                ? storedReminder.togglingCompletion()
                : storedReminder
        }
    }
}

enum CreateReminderCarryForwardTransfer {
    static func carriedReminder(from reminder: CreateReminder) -> CreateReminder {
        CreateReminder(
            text: reminder.text,
            createdAt: reminder.createdAt,
            carryForwardCount: reminder.carryForwardCount + 1
        )
    }

    static func sourceRemindersAfterTransfer(
        sourceReminders: [CreateReminder],
        transferredReminders: [CreateReminder]
    ) -> [CreateReminder] {
        let transferredIDs = Set(transferredReminders.map(\.id))
        return sourceReminders.filter { !transferredIDs.contains($0.id) }
    }
}
