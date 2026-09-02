import AppKit
import SwiftUI

struct WikeyEditorHeader<Actions: View>: View {
    @Binding var title: String
    var subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                TextField("이름", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .semibold))
                    .accessibilityLabel("이름")
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 16)
            actions
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
}

struct WikeySection<Content: View>: View {
    var title: String
    var detail: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShortcutBadge: View {
    var text: String
    var isMuted = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(isMuted ? .tertiary : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityLabel("단축키 \(text)")
    }
}

struct StatusPill: View {
    enum Tone {
        case good
        case attention
        case neutral

        var color: Color {
            switch self {
            case .good: .green
            case .attention: .orange
            case .neutral: .secondary
            }
        }
    }

    var title: String
    var tone: Tone

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tone.color.opacity(0.1), in: Capsule())
    }
}

struct PlainPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
            }
    }
}
