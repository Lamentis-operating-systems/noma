import SwiftUI

struct RecurrenceManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DailyTaskGroupStore.self) private var dailyTaskGroups

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(dailyTaskGroups.recurrences) { recurrence in
                        HStack {
                            Text(recurrence.sourceText)
                            Spacer()
                            Button("recurrence.stop", role: .destructive) {
                                dailyTaskGroups.stopRecurrence(withID: recurrence.id)
                            }
                            .accessibilityIdentifier("recurrence-manage-stop-\(recurrence.id)")
                        }
                    }
                } footer: {
                    Text("recurrence.stop.explanation")
                }
            }
            .navigationTitle("recurrence.manage")
            .toolbar {
                CloseToolbarButton(
                    accessibilityLabelKey: "recurrence.close",
                    action: { dismiss() }
                )
            }
        }
    }
}
