import AppKit
import os.log

// Pastes a string at the cursor in the focused app: snapshot pasteboard,
// write text, synth ⌘V, restore the original contents after a delay.
//
// Why not type the string character-by-character with
// `CGEventKeyboardSetUnicodeString`? It works, but:
//   - it's measurably slower for paragraphs (paste is O(1), typing is O(n))
//   - some apps (Slack rich-text input, parts of Office) misinterpret rapid
//     synthetic keystrokes
//   - emojis and combining characters need extra care
// Paste avoids all of that and is the same trick BetterTouchTool, Raycast,
// and the dictation reference apps use.
final class TextInserter {
    private let log = Logger(subsystem: "com.arunbrahma.purr", category: "paste")

    // V on a US ANSI keyboard.
    private let kVKey: CGKeyCode = 9

    // How long to wait after sending ⌘V before restoring the original
    // pasteboard. Apps process the paste asynchronously; restore too early
    // and you'll paste the *previous* clipboard contents instead. 250 ms is
    // a comfortable ceiling - Slack, Notes, VS Code, Chrome, and Safari all
    // dispatch the paste within ~50–100 ms on Apple Silicon.
    private let restoreDelay: TimeInterval = 0.25

    // nspasteboard.org markers. Cooperative clipboard managers (Paste,
    // Maccy, Alfred, Raycast) and Universal Clipboard honour these to
    // skip recording or syncing sensitive, short-lived content.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        // Single item so the markers travel with the string; separate
        // setData calls would land on independent pasteboard items.
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: Self.concealedType)
        item.setData(Data(), forType: Self.transientType)
        pasteboard.writeObjects([item])

        sendCommandV()

        // Restore the previous contents on the main queue. We can't restore
        // synchronously because the paste hasn't been consumed yet - see
        // the comment on `restoreDelay` above.
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            self.restorePasteboard(pasteboard, snapshot: snapshot)
        }
    }

    // Deletes the `count` characters before the cursor by synthesising Backspace
    // presses. Used to undo a just-pasted sentence ("scratch that"). A short gap
    // between events stops the Window Server coalescing them, which would
    // otherwise leave stray characters behind.
    func deleteBackward(_ count: Int) {
        guard count > 0, let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let backspace: CGKeyCode = 51
        for _ in 0..<count {
            CGEvent(keyboardEventSource: source, virtualKey: backspace, keyDown: true)?
                .post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: backspace, keyDown: false)?
                .post(tap: .cghidEventTap)
            usleep(800)
        }
    }

    // ------------------------------------------------------------------
    // Pasteboard snapshot/restore
    // ------------------------------------------------------------------

    // Capture every pasteboard item with all of its types. We snapshot the
    // raw Data per type rather than the rendered strings/images because
    // some pasteboard types (rich text, file lists, custom UTIs) lose
    // information when round-tripped through their semantic accessors.
    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private func snapshotPasteboard(_ pb: NSPasteboard) -> PasteboardSnapshot {
        guard let items = pb.pasteboardItems else { return PasteboardSnapshot(items: []) }
        let captured: [[NSPasteboard.PasteboardType: Data]] = items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
        return PasteboardSnapshot(items: captured)
    }

    private func restorePasteboard(_ pb: NSPasteboard, snapshot: PasteboardSnapshot) {
        pb.clearContents()
        if snapshot.items.isEmpty { return }
        let restored: [NSPasteboardItem] = snapshot.items.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types {
                item.setData(data, forType: type)
            }
            return item
        }
        pb.writeObjects(restored)
    }

    // ------------------------------------------------------------------
    // ⌘V synthesis
    // ------------------------------------------------------------------

    private func sendCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            log.error("Could not create CGEventSource - paste injection skipped.")
            return
        }
        // Combined session state preserves the user's actual modifier-key
        // state. If they happened to be holding Shift, we don't want to
        // accidentally send ⇧⌘V (= "Paste and Match Style" in many apps).
        // The flags we set on the keyDown event override anyway.
        let down = CGEvent(keyboardEventSource: source, virtualKey: kVKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: kVKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
