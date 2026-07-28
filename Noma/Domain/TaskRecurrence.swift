import Foundation

struct TaskRecurrence: Codable, Equatable, Identifiable {
    let id: UUID
    var sourceText: String
    var activeWeekdays: Set<Int>
    let startDate: Date
    var materializedDays: [String: UUID]

    init(
        id: UUID = UUID(),
        sourceText: String,
        activeWeekdays: Set<Int>,
        startDate: Date,
        materializedDays: [String: UUID] = [:]
    ) {
        self.id = id
        self.sourceText = sourceText
        self.activeWeekdays = activeWeekdays
        self.startDate = startDate
        self.materializedDays = materializedDays
    }

    var isValid: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !activeWeekdays.isEmpty
            && activeWeekdays.allSatisfy { (1...7).contains($0) }
    }

    func isActive(on date: Date, calendar: Calendar) -> Bool {
        isValid
            && calendar.compare(date, to: startDate, toGranularity: .day) != .orderedAscending
            && activeWeekdays.contains(calendar.component(.weekday, from: date))
    }
}

enum TaskRecurrenceSchedule: Equatable {
    case daily
    case selectedWeekdays(Set<Int>)

    var activeWeekdays: Set<Int> {
        switch self {
        case .daily:
            Set(1...7)
        case let .selectedWeekdays(weekdays):
            weekdays
        }
    }
}
