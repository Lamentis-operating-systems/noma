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
                        Toggle(weekdayName(weekday), isOn: weekdayBinding(weekday))
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

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { selectedCustomWeekdays.contains(weekday) },
            set: { isSelected in
                if isSelected {
                    selectedCustomWeekdays.insert(weekday)
                } else {
                    selectedCustomWeekdays.remove(weekday)
                }
            }
        )
    }
}
