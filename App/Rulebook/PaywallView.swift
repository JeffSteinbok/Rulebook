import SwiftUI
import StoreKit

/// Shown when a free user reaches a write action, naming the action they tried.
///
/// Deliberately not a launch-time wall: reading is the free tier, and the ask
/// lands at the moment someone has found a rule they want to fix.
struct PaywallView: View {
    let trigger: PaywallTrigger
    let pro: ProStore

    @Environment(\.dismiss) private var dismiss

    private let included = [
        "Edit, create, and delete rules",
        "Turn rules on and off",
        "Reorder them — order decides what runs",
        "Fix the rules that quietly stopped working",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(trigger.headline)
                        .font(DS.Font.sectionTitle)
                        .foregroundStyle(DS.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Reading your rules is free and always will be. Changing them is a one-time purchase — no subscription.")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Palette.ink60)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(included, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(DS.Palette.accent)
                                Text(line)
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Palette.ink80)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if let message = pro.errorMessage {
                        Text(message)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Palette.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Metric.gutter)
            }
            .background(DS.Palette.ground)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    PrimaryButton(
                        title: buyTitle,
                        trailing: nil
                    ) {
                        Task {
                            await pro.purchase()
                            if pro.isPro { dismiss() }
                        }
                    }
                    .disabled(pro.product == nil || pro.isWorking)

                    Button("Restore purchase") {
                        Task {
                            await pro.restore()
                            if pro.isPro { dismiss() }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(pro.isWorking)
                }
                .padding(DS.Metric.gutter)
                .background(DS.Palette.ground)
            }
            .navigationTitle("Rulebook Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .task {
            // The product may not have loaded yet if the app opened offline.
            if pro.product == nil { await pro.loadProduct() }
        }
        .onDisappear { pro.errorMessage = nil }
    }

    private var buyTitle: String {
        if pro.isWorking { return "Working…" }
        guard let product = pro.product else { return "Unavailable right now" }
        return "Unlock Pro — \(product.displayPrice)"
    }
}
