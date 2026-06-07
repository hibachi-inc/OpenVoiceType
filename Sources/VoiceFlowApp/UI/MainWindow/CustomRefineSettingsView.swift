#if PROFEATURES
import SwiftUI

struct CustomRefineSettingsView: View {
    @State private var prefs = PreferencesStore.shared

    private var isLocked: Bool { !ProUpgradeManager.shared.isPro }

    var body: some View {
        Form {
            Section("general.refinement") {
                Picker("general.mode", selection: $prefs.refinementMode) {
                    ForEach(RefinementMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.label)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(prefs.refinementMode.description)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section("refinement.default_prompt") {
                TextEditor(text: $prefs.defaultPrompt)
                    .font(DS.Font.body)
                    .frame(height: 50)
                    .scrollContentBackground(.hidden)
                    .background(DS.Colors.fieldBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(DS.Colors.secondary.opacity(0.3))
                    )

                FlowLayout(spacing: DS.Spacing.xs) {
                    ForEach(PromptSuggestion.all) { suggestion in
                        Button {
                            prefs.defaultPrompt = suggestion.prompt
                        } label: {
                            Text(suggestion.label)
                                .font(DS.Font.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DS.Colors.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("refinement.default_prompt_desc_pro")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section("refinement.app_prompts") {
                if isLocked {
                    Label("pro.upgrade_hint_custom_refine", systemImage: "lock.fill")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.darkCoffee)
                }

                AppPromptEditor()
                    .disabled(isLocked)

                Text("refinement.app_prompts_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.windowBg)
        .navigationTitle(String(localized: "sidebar.custom_refine"))
    }
}

// MARK: - Prompt Suggestions

private struct PromptSuggestion: Identifiable {
    let id: String
    let label: String
    let prompt: String

    static let all: [PromptSuggestion] = [
        PromptSuggestion(
            id: "correct",
            label: String(localized: "refinement.suggestion.correct"),
            prompt: String(localized: "refinement.suggestion.correct_prompt")
        ),
        PromptSuggestion(
            id: "polite",
            label: String(localized: "refinement.suggestion.polite"),
            prompt: String(localized: "refinement.suggestion.polite_prompt")
        ),
        PromptSuggestion(
            id: "concise",
            label: String(localized: "refinement.suggestion.concise"),
            prompt: String(localized: "refinement.suggestion.concise_prompt")
        ),
        PromptSuggestion(
            id: "translate",
            label: String(localized: "refinement.suggestion.translate"),
            prompt: String(localized: "refinement.suggestion.translate_prompt")
        ),
    ]
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].isEmpty && currentWidth + spacing + size.width > maxWidth {
                rows.append([])
                currentWidth = 0
            }
            if currentWidth > 0 { currentWidth += spacing }
            currentWidth += size.width
            rows[rows.count - 1].append(i)
        }
        return rows
    }
}
#endif
