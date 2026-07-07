# App Intents Smoke Test Goal

## Purpose

Use App Intents as narrow smoke-test hooks for the plain editor path.

The goal is not to add user-facing automation as a product feature yet. The goal is deterministic repo-owned validation that does not depend on a human screenshot, manual typing, or a visible display session.

## Goal

Add a small App Intents smoke-test surface that can prove the editor can:

- open a known file
- report loaded file state
- apply a known edit
- save the edited file
- reopen the file
- verify the edit persisted

The App Intents should exercise the same document and editor path used by the app. They should not create a separate fake validation path.

## Candidate Smoke-Test Intents

- `OpenKnownFileIntent`
- `ReportEditorStateIntent`
- `ApplySyntheticEditIntent`
- `SaveCurrentDocumentIntent`
- `ReopenAndVerifyIntent`

## Expected Intent Results

Each intent should return simple, assertable results for the smoke script.

Useful return values include:

- loaded file path
- loaded character count
- editor window created
- editor view created
- editable state
- first-responder request status
- edit applied status
- save result
- reopened character count
- persisted-edit result

## Smoke Script Use

The smoke script should be able to run the validation without human interaction.

A successful smoke flow should:

1. Build the app.
2. Launch the app.
3. Run `OpenKnownFileIntent`.
4. Run `ReportEditorStateIntent`.
5. Run `ApplySyntheticEditIntent`.
6. Run `SaveCurrentDocumentIntent`.
7. Run `ReopenAndVerifyIntent`.
8. Assert the edit persisted.
9. Keep `./build_debug.sh` green.
10. Keep `./scripts/plain_editor_smoke.sh` green.

## Boundaries

App Intents are useful here only if they reduce human validation and prove real editor behavior.

Keep the intent surface small. Do not turn this into a product automation system yet.

The current milestone remains a working plain text editor:

- open files
- display text
- edit text
- save text
- reopen saved files
- support the plain-editor path without IDE, terminal, source control, or workspace-shell behavior

## Success Condition

This goal is complete when the repo has an automated smoke path that proves:

- a known text/source file opens
- the document receives non-empty text
- the editor path receives the text
- a synthetic edit updates the document/editor model
- saving writes the edited text
- reopening confirms the edit persisted
- no human screenshot or manual typing is required to prove the behavior
