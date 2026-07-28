import SwiftUI

struct TaskRecurrenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DailyTaskGroupStore.self) private var dailyTaskGroups

    let reminder: CreateReminder
    let dayID: String

    @State private var usesSelectedWeekdays = false
    @State private var selectedWeekdays: Set<Int> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(reminder.text)
                } header: {
                    Text("recurrence.task")
                }

                if let recurrence {
                    Section {
                        Text("recurrence.stop.explanation")
                            .foregroundStyle(.secondary)
                        Button("recurrence.stop", role: .destructive) {
                            guard dailyTaskGroups.stopRecurrence(withID: recurrence.id) else { return }
                            dismiss()
                        }
                        .accessibilityIdentifier("recurrence-stop-button")
                    }
                } else {
                    Section {
                        Picker("recurrence.frequency", selection: $usesSelectedWeekdays) {
                            Text("recurrence.daily").tag(false)
                            Text("recurrence.weekdays").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("recurrence-frequency-picker")

                        if usesSelectedWeekdays {
                            ForEach(1...7, id: \.self) { weekday in
                                Toggle(weekdayName(weekday), isOn: weekdayBinding(weekday))
                                    .accessibilityIdentifier("recurrence-weekday-\(weekday)")
                            }
                        }
                    }

                    Section {
                        Button("recurrence.save") {
                            let schedule: TaskRecurrenceSchedule = usesSelectedWeekdays
                                ? .selectedWeekdays(selectedWeekdays)
                                : .daily
                            guard dailyTaskGroups.createRecurrence(
                                from: reminder,
                                onDayID: dayID,
                                schedule: schedule
                            ) else { return }
                            dismiss()
                        }
                        .disabled(usesSelectedWeekdays && selectedWeekdays.isEmpty)
                        .accessibilityIdentifier("recurrence-save-button")
                    } footer: {
                        Text("recurrence.foreground-only")
                    }
                }
            }
            .navigationTitle("recurrence.title")
            .toolbar {
                CloseToolbarButton(
                    accessibilityLabelKey: "recurrence.close",
                    action: { dismiss() }
                )
            }
        }
    }

    private var recurrence: TaskRecurrence? {
        dailyTaskGroups.recurrence(for: reminder.id, onDayID: dayID)
    }

    private func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { selectedWeekdays.contains(weekday) },
            set: { isSelected in
                if isSelected {
                    selectedWeekdays.insert(weekday)
                } else {
                    selectedWeekdays.remove(weekday)
                }
            }
        )
    }
}
