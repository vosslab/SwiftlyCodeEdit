//
//  FindPanelView.swift
//  SwiftlyCodeEdit
//
//  The SwiftUI find/replace bar. The old CodeEditSourceEditor find panel was
//  an AppKit `NSViewController` hosted in the scroll view; this port is plain SwiftUI
//  laid over the top of the editor, keeping AppKit out of the find feature entirely.
//  All state and behavior live in `FindPanelModel`; this view is its surface.
//

import SwiftUI

/// The find bar shown above the editor when a search is active. In replace mode it
/// grows a second row with the replacement field and the Replace / Replace All
/// buttons. An inline message appears when a regex query does not compile.
struct FindPanelView: View {
    @Bindable var model: FindPanelModel

    // Focuses the find field the moment the bar appears, so Cmd-F lets the user type
    // immediately.
    @FocusState private var findFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            findRow
            if model.mode == .replace {
                replaceRow
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .onAppear {
            findFieldFocused = true
        }
    }

    // MARK: - Find row

    private var findRow: some View {
        HStack(spacing: 8) {
            // Toggles the bar between find-only and find-and-replace.
            Button {
                model.mode = model.mode == .find ? .replace : .find
            } label: {
                Image(systemName: model.mode == .replace ? "chevron.down" : "chevron.right")
            }
            .buttonStyle(.borderless)
            .help("Toggle replace")

            methodPicker

            Toggle("Aa", isOn: $model.matchCase)
                .toggleStyle(.button)
                .help("Match case")
                .onChange(of: model.matchCase) { _, _ in
                    model.performFind()
                }

            TextField("Find", text: $model.findText)
                .textFieldStyle(.roundedBorder)
                .focused($findFieldFocused)
                .frame(minWidth: 160)
                .onChange(of: model.findText) { _, _ in
                    model.performFind()
                }
                .onSubmit {
                    model.moveToNextMatch()
                }

            Text(matchCountLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(minWidth: 74, alignment: .leading)

            Button {
                model.moveToPreviousMatch()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(model.matchCount == 0)
            .help("Previous match")

            Button {
                model.moveToNextMatch()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(model.matchCount == 0)
            .help("Next match")

            Spacer(minLength: 8)

            Button("Done") {
                model.dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var methodPicker: some View {
        Picker("", selection: $model.findMethod) {
            ForEach(FindMethod.allCases, id: \.self) { method in
                Text(method.displayName).tag(method)
            }
        }
        .labelsHidden()
        .frame(width: 150)
        .onChange(of: model.findMethod) { _, _ in
            model.performFind()
        }
    }

    // MARK: - Replace row

    private var replaceRow: some View {
        HStack(spacing: 8) {
            TextField("Replace", text: $model.replaceText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160)

            Button("Replace") {
                model.replaceCurrentMatch()
            }
            .disabled(model.currentMatchIndex == nil)

            Button("Replace All") {
                model.replaceAllMatches()
            }
            .disabled(model.matchCount == 0)

            Spacer(minLength: 8)
        }
        // Indent under the find field so the two rows line up visually.
        .padding(.leading, 24)
    }

    // MARK: - Labels

    private var matchCountLabel: String {
        if model.findText.isEmpty {
            return ""
        }
        if model.matchCount == 0 {
            return "No results"
        }
        if let index = model.currentMatchIndex {
            let label = "\(index + 1) of \(model.matchCount)"
            return label
        }
        let label = "\(model.matchCount) matches"
        return label
    }
}
