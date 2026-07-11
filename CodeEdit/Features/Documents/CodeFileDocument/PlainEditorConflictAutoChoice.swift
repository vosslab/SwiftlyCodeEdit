//
//  PlainEditorConflictAutoChoice.swift
//  SwiftlyCodeEdit
//
//  DEBUG-only auto-answer seam for the external-change reload conflict.
//  Passing `-PlainEditor.conflictAutoChoice keep|reload` lands in UserDefaults'
//  volatile NSArgumentDomain (per-process, never persisted, no `defaults write`),
//  so an unattended e2e run can drive the dirty + decodable conflict to a fixed
//  answer without a human clicking the SwiftUI alert. Absent the argument this is
//  a no-op and the real alert is shown. Mirrors the same volatile-argument seam
//  pattern as PlainEditorWindowCapture.
//

#if DEBUG
import Foundation

enum PlainEditorConflictAutoChoice {
    /// The two answers to the keep-mine-or-reload conflict.
    enum Choice: String {
        case keep
        case reload
    }

    /// Launch-argument key read from the volatile NSArgumentDomain.
    static let argumentKey = "PlainEditor.conflictAutoChoice"

    /// The requested auto-answer, or nil when the argument is absent or not one of
    /// the two recognized values.
    static func requested() -> Choice? {
        guard let raw = UserDefaults.standard.string(forKey: argumentKey) else {
            return nil
        }
        return Choice(rawValue: raw)
    }
}
#endif
