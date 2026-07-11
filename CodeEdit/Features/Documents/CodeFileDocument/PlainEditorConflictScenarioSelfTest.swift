//
//  PlainEditorConflictScenarioSelfTest.swift
//  SwiftlyCodeEdit
//
//  DEBUG-only driver that stages an external-change scenario so the unattended
//  e2e (tests/e2e/e2e_external_change_conflict.py) can exercise the real
//  NSFilePresenter path in a running app. Gated by the environment
//  variable CODEEDIT_CONFLICT_SCENARIO=clean|dirty and scheduled from
//  CodeFileView.onTextViewReady, mirroring PlainEditorCommandSelfTest. For the
//  dirty scenario it makes one real edit through the editor so the document is
//  genuinely dirty; for both scenarios it logs a single readiness marker so the
//  harness knows exactly when to rewrite the backing file on disk. Absent the
//  variable it is a no-op.
//

#if DEBUG
import Foundation
import CodeEditTextView

@MainActor
enum PlainEditorConflictScenarioSelfTest {
    private static var didSchedule = false
    static let environmentKey = "CODEEDIT_CONFLICT_SCENARIO"

    static func scheduleIfRequested(textView: TextView) {
        let scenario = ProcessInfo.processInfo.environment[environmentKey]
        guard let scenario, scenario == "clean" || scenario == "dirty", !didSchedule else {
            return
        }
        didSchedule = true

        // Wait past the first highlight pass and initial layout so the edit lands
        // on a settled window and the document's opened modification date is fixed
        // before the harness rewrites the file.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if scenario == "dirty" {
                // A real edit through the editor dirties the document via the same
                // onEdit -> recordEdit(.edit) path a keystroke uses.
                textView.window?.makeFirstResponder(textView)
                textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 0))
                textView.replaceCharacters(in: NSRange(location: 0, length: 0), with: "// unsaved edit\n")
            }
            debugRuntimeLog("CONFLICT_SCENARIO_READY state=\(scenario)")
        }
    }
}
#endif
