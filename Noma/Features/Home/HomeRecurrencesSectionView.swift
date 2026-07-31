import SwiftUI

struct HomeRecurrencesSectionView: View {
    @Environment(DailyTaskGroupStore.self) private var dailyTaskGroups
    @State private var recurrencePendingStop: TaskRecurrence?

    let recurrences: [TaskRecurrence]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("recurrence.manage")
                .accessibilityIdentifier("home-recurrences-section-title")

            VStack(alignment: .leading, spacing: CreateReminderRowsLayout.spacingBetweenTasks) {
                ForEach(recurrences) { recurrence in
                    Button {
                        recurrencePendingStop = recurrence
                    } label: {
                        CreateReminderRowLayout {
                            Text(recurrence.sourceText)
                                .font(.headline.weight(.regular))
                                .foregroundStyle(.textPrimary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } accessory: {
                            Image(systemName: "repeat")
                                .font(.body)
                                .foregroundStyle(.textSecondary)
                                .frame(
                                    width: NomaSize.radioCheckboxOuter,
                                    height: NomaSize.radioCheckboxOuter,
                                    alignment: .center
                                )
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: NomaSize.minimumTouchTarget, alignment: .top)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(recurrence.sourceText))
                    .accessibilityHint(Text("recurrence.home.actions.accessibility-hint"))
                    .accessibilityIdentifier("home-recurrence-\(recurrence.id)")
                }
            }
        }
        .alert(
            "recurrence.stop.confirmation-title",
            isPresented: stopConfirmationIsPresented
        ) {
            Button("common.cancel", role: .cancel) {
                recurrencePendingStop = nil
            }
            .accessibilityIdentifier("home-recurrence-stop-cancel-button")

            Button("recurrence.stop", role: .destructive) {
                stopPendingRecurrence()
            }
            .accessibilityIdentifier("home-recurrence-stop-confirm-button")
        } message: {
            Text("recurrence.stop.confirmation-message")
        }
    }

    private var stopConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { recurrencePendingStop != nil },
            set: { isPresented in
                if !isPresented {
                    recurrencePendingStop = nil
                }
            }
        )
    }

    private func stopPendingRecurrence() {
        guard let recurrencePendingStop else { return }
        _ = dailyTaskGroups.stopRecurrence(withID: recurrencePendingStop.id)
        self.recurrencePendingStop = nil
    }
}
