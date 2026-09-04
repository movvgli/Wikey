import SwiftUI
import WikeyCore

struct TemplateEditorView: View {
    @Environment(WikeyRuntime.self) private var runtime
    @Binding var template: RichTemplate
    var onBack: () -> Void
    var onDelete: () -> Void
    @State private var editor = RichTextEditorController()
    @State private var copyState: CopyState = .idle
    @State private var showsDeleteConfirmation = false

    private enum CopyState {
        case idle
        case copied
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            WikeyEditorHeader(
                title: $template.name,
                subtitle: "서식과 이미지를 그대로 보관합니다. 내용은 자동으로 저장됩니다.",
                onBack: onBack
            ) {
                if copyState != .idle {
                    Label(
                        copyState == .copied ? "복사됨" : "복사 실패",
                        systemImage: copyState == .copied ? "checkmark" : "exclamationmark.triangle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(copyState == .copied ? Color.green : Color.orange)
                    .transition(.opacity)
                }
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("템플릿 삭제")
                .accessibilityLabel("템플릿 삭제")
                Button("클립보드에 복사", systemImage: "doc.on.doc", action: copyTemplate)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }

            Divider()

            HStack(spacing: 8) {
                ControlGroup {
                    Button(action: editor.toggleBold) { Image(systemName: "bold") }
                        .help("굵게")
                    Button(action: editor.toggleItalic) { Image(systemName: "italic") }
                        .help("기울임")
                    Button(action: editor.toggleUnderline) { Image(systemName: "underline") }
                        .help("밑줄")
                }
                .fixedSize()
                ControlGroup {
                    Button(action: editor.addLink) { Image(systemName: "link") }
                        .help("선택한 글자에 링크 추가")
                    Button(action: editor.insertBullet) { Image(systemName: "list.bullet") }
                        .help("목록 항목 추가")
                    Button(action: editor.insertImage) { Image(systemName: "photo") }
                        .help("이미지 넣기")
                }
                .fixedSize()
                Spacer()
                Text("자동 저장")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            ZStack {
                Color(nsColor: .windowBackgroundColor)
                RichTextEditor(controller: editor)
                    .frame(maxWidth: 760)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
            }
        }
        .navigationTitle(template.name)
        .task(id: template.id) {
            editor.load(runtime.store.templateDocument(id: template.id))
            editor.onDocumentChange = { [weak runtime] document in
                runtime?.store.saveTemplateDocument(document, for: template.id)
            }
        }
        .alert("템플릿을 삭제할까요?", isPresented: $showsDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: onDelete)
        } message: {
            Text("‘\(template.name)’과 이 템플릿을 사용하는 워크플로 동작이 함께 삭제됩니다.")
        }
    }

    private func copyTemplate() {
        do {
            try runtime.clipboard.copy(runtime.store.templateDocument(id: template.id))
            showCopyState(.copied)
        } catch {
            showCopyState(.failed)
        }
    }

    private func showCopyState(_ state: CopyState) {
        withAnimation(.easeOut(duration: 0.15)) {
            copyState = state
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeIn(duration: 0.15)) {
                copyState = .idle
            }
        }
    }
}
