import SwiftUI

struct TaskRecurrenceMenu: View {
    @Environment(DailyTaskGroupStore.self) private var dailyTaskGroups

    let reminder: CreateReminder
    let dayID: String
    @Binding var selectedCustomWeekdays: Set<Int>

    static let customWeekdays = Array(2...6)

    var body: some View {
        if let recurrence {
            Button("recurrence.stop", role: .destructive) {
                _ = dailyTaskGroups.stopRecurrence(withID: recurrence.id)
            }
            .accessibilityIdentifier("recurrence-stop-button")
        } else {
            Menu {
                Button("recurrence.daily") {
                    createRecurrence(with: .daily)
                }
                .accessibilityIdentifier("recurrence-daily-button")

                Menu {
                    ForEach(Self.customWeekdays, id: \.self) { weekday in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            HStack {
                                Text(weekdayName(weekday))

                                if selectedCustomWeekdays.contains(weekday) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .menuActionDismissBehavior(.disabled)
                        .accessibilityIdentifier("recurrence-weekday-\(weekday)")
                    }

                    Divider()

                    Button("recurrence.save") {
                        createRecurrence(with: .selectedWeekdays(selectedCustomWeekdays))
                    }
                    .disabled(selectedCustomWeekdays.isEmpty)
                    .accessibilityIdentifier("recurrence-custom-save-button")
                } label: {
                    Text("recurrence.custom")
                }
                .accessibilityIdentifier("recurrence-custom-menu")
            } label: {
                Label("recurrence.context-menu", systemImage: "repeat")
            }
            .accessibilityIdentifier("recurrence-menu")
        }
    }

    private var recurrence: TaskRecurrence? {
        dailyTaskGroups.recurrence(for: reminder.id, onDayID: dayID)
    }

    private func createRecurrence(with schedule: TaskRecurrenceSchedule) {
        _ = dailyTaskGroups.createRecurrence(
            from: reminder,
            onDayID: dayID,
            schedule: schedule
        )
    }

    private func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedCustomWeekdays.contains(weekday) {
            selectedCustomWeekdays.remove(weekday)
        } else {
            selectedCustomWeekdays.insert(weekday)
        }
    }
}
