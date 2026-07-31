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
                    Menu {
                        Button(role: .destructive) {
                            recurrencePendingStop = recurrence
                        } label: {
                            Label("recurrence.stop", systemImage: "repeat")
                        }
                        .accessibilityIdentifier("home-recurrence-stop-action-\(recurrence.id)")
                    } label: {
                        HStack(alignment: .top, spacing: 0) {
                            Text(recurrence.sourceText)
                                .font(.headline.weight(.regular))
                                .foregroundStyle(.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, NomaSpacing.md)

                            Image(systemName: "repeat")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.textSecondary)
                                .frame(
                                    width: NomaSize.minimumTouchTarget,
                                    height: NomaSize.minimumTouchTarget,
                                    alignment: .center
                                )
                                .accessibilityHidden(true)
                        }
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
