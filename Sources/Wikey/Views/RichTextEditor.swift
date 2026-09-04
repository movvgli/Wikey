import AppKit
import SwiftUI

@MainActor
final class RichTextEditorController {
    weak var textView: NSTextView?
    var onDocumentChange: ((NSAttributedString) -> Void)?
    private var pendingDocument: NSAttributedString?

    func load(_ document: NSAttributedString) {
        pendingDocument = document
        if let textView { applyPendingDocument(to: textView) }
    }

    func attach(_ textView: NSTextView) {
        self.textView = textView
        applyPendingDocument(to: textView)
    }

    func toggleBold() { toggleFontTrait(.boldFontMask) }
    func toggleItalic() { toggleFontTrait(.italicFontMask) }

    func toggleUnderline() {
        guard let textView, let storage = textView.textStorage else { return }
        let range = effectiveRange(in: textView)
        if range.length == 0 {
            let current = textView.typingAttributes[.underlineStyle] as? Int ?? 0
            if current == 0 {
                textView.typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                textView.typingAttributes.removeValue(forKey: .underlineStyle)
            }
            return
        }
        let current = storage.attribute(.underlineStyle, at: max(0, min(range.location, max(storage.length - 1, 0))), effectiveRange: nil) as? Int ?? 0
        if current == 0 { storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        else { storage.removeAttribute(.underlineStyle, range: range) }
        emitChange()
    }

    func addLink() {
        guard let textView, textView.selectedRange().length > 0 else { NSSound.beep(); return }
        let alert = NSAlert()
        alert.messageText = "링크 추가"
        alert.informativeText = "선택한 텍스트에 연결할 주소를 입력하세요."
        let field = NSTextField(string: "https://")
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "추가")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn, let url = URL(string: field.stringValue),
              let storage = textView.textStorage else { return }
        storage.addAttribute(.link, value: url, range: textView.selectedRange())
        emitChange()
    }

    func insertBullet() {
        guard let textView else { return }
        textView.insertText("• ", replacementRange: textView.selectedRange())
        emitChange()
    }

    func insertImage() {
        guard let textView else { return }
        let panel = NSOpenPanel()
        panel.title = "템플릿에 넣을 이미지 선택"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url),
              image.isValid else {
            return
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.allowsTextAttachmentView = false

        let naturalSize = image.size
        let containerWidth = textView.textContainer?.containerSize.width ?? naturalSize.width
        let maximumWidth = max(containerWidth - 16, 1)
        let scale = naturalSize.width > maximumWidth ? maximumWidth / naturalSize.width : 1
        attachment.bounds = NSRect(
            x: 0,
            y: 0,
            width: max(naturalSize.width * scale, 1),
            height: max(naturalSize.height * scale, 1)
        )

        let attributed = NSAttributedString(attachment: attachment)
        textView.textStorage?.replaceCharacters(in: textView.selectedRange(), with: attributed)
        emitChange()
    }

    func emitChange() {
        guard let storage = textView?.textStorage else { return }
        onDocumentChange?(NSAttributedString(attributedString: storage))
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView, let storage = textView.textStorage else { return }
        let range = effectiveRange(in: textView)
        if range.length == 0 {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 15)
            let manager = NSFontManager.shared
            let hasTrait = manager.traits(of: font).contains(trait)
            textView.typingAttributes[.font] = hasTrait
                ? manager.convert(font, toNotHaveTrait: trait)
                : manager.convert(font, toHaveTrait: trait)
            return
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let manager = NSFontManager.shared
            let hasTrait = manager.traits(of: font).contains(trait)
            let converted = hasTrait ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: converted, range: subrange)
        }
        storage.endEditing()
        emitChange()
    }

    private func effectiveRange(in textView: NSTextView) -> NSRange {
        let selected = textView.selectedRange()
        if selected.length > 0 { return selected }
        return NSRange(location: selected.location, length: 0)
    }

    private func applyPendingDocument(to textView: NSTextView) {
        guard let pendingDocument, let storage = textView.textStorage else { return }
        storage.setAttributedString(pendingDocument)
        if storage.length == 0 {
            textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 14)]
        }
        self.pendingDocument = nil
    }
}

struct RichTextEditor: NSViewRepresentable {
    var controller: RichTextEditorController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 10
        scroll.layer?.cornerCurve = .continuous
        scroll.layer?.borderWidth = 1
        scroll.layer?.borderColor = NSColor.separatorColor.cgColor

        let textView = NSTextView(frame: .zero)
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 22, height: 20)
        textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 15)]
        textView.delegate = context.coordinator
        scroll.documentView = textView
        controller.attach(textView)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.controller = controller
        if let textView = nsView.documentView as? NSTextView, controller.textView !== textView {
            controller.attach(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var controller: RichTextEditorController
        init(controller: RichTextEditorController) { self.controller = controller }

        func textDidChange(_ notification: Notification) {
            controller.emitChange()
        }
    }
}
