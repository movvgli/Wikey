import SwiftUI
import WikeyCore

struct WorkflowReferenceSetupView: View {
    var workflows: [Workflow]
    @Binding var selectedWorkflowID: UUID?
    var onCancel: () -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("다른 워크플로 실행 추가")
                    .font(.title2.weight(.semibold))
                Text("이 위치에서 이어서 실행할 워크플로를 선택하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(workflows) { workflow in
                        workflowButton(workflow)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack(spacing: 10) {
                Text("선택한 워크플로의 동작이 이 순서에서 실행됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("취소", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("동작 추가", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedWorkflowID == nil)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.bar)
        }
        .frame(width: 520, height: 420)
    }

    private func workflowButton(_ workflow: Workflow) -> some View {
        let isSelected = selectedWorkflowID == workflow.id

        return Button {
            selectedWorkflowID = workflow.id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.wikeyAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.wikeyAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("동작 \(workflow.actions.count)개")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if !workflow.shortcut.steps.isEmpty {
                    ShortcutBadge(text: workflow.shortcut.displayName)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Color.wikeyAccent : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.wikeyAccent.opacity(0.08) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.wikeyAccent.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.35),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workflow.name) 워크플로")
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }
}
