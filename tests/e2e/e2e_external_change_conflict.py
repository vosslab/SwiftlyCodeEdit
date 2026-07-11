#!/usr/bin/env python3
"""Drive the external-change conflict matrix against the running app.

Launches the built SwiftlyCodeEdit app on a sandboxed /tmp fixture, rewrites that
fixture from this process (a genuine external change picked up by NSFilePresenter),
and gates on the runtime-log markers for two matrix rows:

- clean + decodable: silent reload, observable as RELOAD_COMPLETE with no conflict
  prompt.
- dirty + decodable: keep-mine-or-reload conflict, observable as
  EXTERNAL_CHANGE_PROMPT kind=reloadConflict, resolved unattended through the
  DEBUG -PlainEditor.conflictAutoChoice launch argument.

Never touches a repo source file: the fixture lives under /tmp and is rewritten
in place, mirroring e2e_launch_time.py's sandboxing and --kill-after discipline.
"""

# Standard Library
import os
import time
import pathlib
import subprocess

KILL_AFTER_SECONDS = 12
LAUNCH_TIMEOUT_SECONDS = 30
# How long to wait for a runtime-log marker to appear after triggering a step.
MARKER_TIMEOUT_SECONDS = 10
POLL_INTERVAL_SECONDS = 0.2
RUNTIME_LOG_PATH = pathlib.Path("/tmp/codeedit_runtime.log")  # nosec B108 - fixed path written by DebugRuntimeLog.swift
FIXTURE_PATH = pathlib.Path("/tmp/codeedit_e2e_conflict_source.swift")  # nosec B108 - sandboxed fixture, never a repo file

ORIGINAL_TEXT = "let value = 1\n"
EXTERNAL_TEXT = "let value = 42 // external edit\n"


#============================================
def get_repo_root() -> pathlib.Path:
	"""Return the repository root via git rev-parse.

	Returns:
		pathlib.Path: absolute path to the repository root.
	"""
	result = subprocess.run(
		["git", "rev-parse", "--show-toplevel"],
		capture_output=True, text=True, check=True,
	)
	return pathlib.Path(result.stdout.strip())


#============================================
def get_app_path(repo_root: pathlib.Path) -> pathlib.Path:
	"""Return the built debug binary path, failing loudly if it is missing.

	Args:
		repo_root: repository root path.

	Returns:
		pathlib.Path: path to the built SwiftlyCodeEdit debug binary.
	"""
	app_path = repo_root / ".build" / "debug" / "SwiftlyCodeEdit"
	if not app_path.exists():
		raise FileNotFoundError(
			f"Built app not found at {app_path}. Run ./build_debug.sh first."
		)
	return app_path


#============================================
def refuse_if_another_codeedit_is_running() -> None:
	"""Fail fast if another app instance is already running.

	The app writes markers to a single shared runtime log, so a second concurrent
	instance would interleave markers and make this harness read another run's
	output.
	"""
	result = subprocess.run(
		["pgrep", "-f", "SwiftlyCodeEdit"],
		capture_output=True, text=True, check=False,
	)
	if result.stdout.strip():
		raise SystemExit(
			"Another SwiftlyCodeEdit process is running; stop it before this e2e "
			"so the shared runtime log has a single writer."
		)


#============================================
def launch_app(app_path: pathlib.Path, extra_env: dict, extra_args: list[str]) -> subprocess.Popen:
	"""Launch the app on the fixture and return the running process.

	Args:
		app_path: path to the built app binary.
		extra_env: extra environment variables for this launch.
		extra_args: extra command-line arguments for this launch.

	Returns:
		subprocess.Popen: the launched app process.
	"""
	RUNTIME_LOG_PATH.write_text("")

	launch_env = os.environ.copy()
	launch_env["CODEEDIT_DEBUG_SOURCE_FILE"] = str(FIXTURE_PATH)
	launch_env.update(extra_env)

	command = [str(app_path), f"--kill-after={KILL_AFTER_SECONDS}"] + extra_args
	# nosec B603 - launching a first-party build with fixed, non-shell arguments.
	return subprocess.Popen(command, env=launch_env)


#============================================
def wait_for_marker(process: subprocess.Popen, needle: str, deadline: float) -> None:
	"""Poll the runtime log until a marker appears or the deadline passes.

	Args:
		process: the running app process (checked so a crash fails fast).
		needle: substring to wait for in the runtime log.
		deadline: monotonic time by which the marker must appear.
	"""
	while time.monotonic() < deadline:
		if process.poll() is not None:
			log_tail = RUNTIME_LOG_PATH.read_text()[-2000:]
			raise SystemExit(
				f"App exited before marker '{needle}'.\nRuntime log tail:\n{log_tail}"
			)
		if needle in RUNTIME_LOG_PATH.read_text():
			return
		time.sleep(POLL_INTERVAL_SECONDS)
	log_tail = RUNTIME_LOG_PATH.read_text()[-2000:]
	raise SystemExit(
		f"Timed out waiting for marker '{needle}'.\nRuntime log tail:\n{log_tail}"
	)


#============================================
def terminate(process: subprocess.Popen) -> None:
	"""Terminate the app process and reap it.

	Args:
		process: the running app process.
	"""
	if process.poll() is None:
		process.terminate()
	try:
		process.wait(timeout=LAUNCH_TIMEOUT_SECONDS)
	except subprocess.TimeoutExpired:
		process.kill()
		process.wait(timeout=LAUNCH_TIMEOUT_SECONDS)


#============================================
def run_clean_reload_scenario(app_path: pathlib.Path) -> None:
	"""Clean document plus a valid external change: expect a silent reload.

	Args:
		app_path: path to the built app binary.
	"""
	FIXTURE_PATH.write_text(ORIGINAL_TEXT)
	process = launch_app(app_path, {"CODEEDIT_CONFLICT_SCENARIO": "clean"}, [])
	try:
		deadline = time.monotonic() + LAUNCH_TIMEOUT_SECONDS
		wait_for_marker(process, "CONFLICT_SCENARIO_READY state=clean", deadline)

		# External change from this process; NSFilePresenter delivers it to the app.
		FIXTURE_PATH.write_text(EXTERNAL_TEXT)

		reload_deadline = time.monotonic() + MARKER_TIMEOUT_SECONDS
		wait_for_marker(process, "RELOAD_COMPLETE", reload_deadline)

		log_text = RUNTIME_LOG_PATH.read_text()
		if "EXTERNAL_CHANGE_PROMPT" in log_text:
			raise SystemExit(
				"Clean + valid external change must reload silently, but a conflict "
				f"prompt was surfaced.\nRuntime log tail:\n{log_text[-2000:]}"
			)
	finally:
		terminate(process)
	print("clean + valid: silent reload observed (RELOAD_COMPLETE, no prompt)")


#============================================
def run_dirty_conflict_scenario(app_path: pathlib.Path) -> None:
	"""Dirty document plus a valid external change: expect the conflict prompt.

	Args:
		app_path: path to the built app binary.
	"""
	FIXTURE_PATH.write_text(ORIGINAL_TEXT)
	process = launch_app(
		app_path,
		{"CODEEDIT_CONFLICT_SCENARIO": "dirty"},
		["-PlainEditor.conflictAutoChoice", "reload"],
	)
	try:
		deadline = time.monotonic() + LAUNCH_TIMEOUT_SECONDS
		wait_for_marker(process, "CONFLICT_SCENARIO_READY state=dirty", deadline)

		# External change while the document holds unsaved edits.
		FIXTURE_PATH.write_text(EXTERNAL_TEXT)

		prompt_deadline = time.monotonic() + MARKER_TIMEOUT_SECONDS
		wait_for_marker(process, "EXTERNAL_CHANGE_PROMPT kind=reloadConflict", prompt_deadline)

		# The DEBUG auto-answer resolves the conflict unattended (reload chosen),
		# which reloads the on-disk text and leaves the document clean so the
		# --kill-after quit races no save prompt.
		resolve_deadline = time.monotonic() + MARKER_TIMEOUT_SECONDS
		wait_for_marker(process, "EXTERNAL_CHANGE_RESOLVED choice=reload", resolve_deadline)
	finally:
		terminate(process)
	print("dirty + valid: conflict prompt surfaced and auto-resolved (reload)")


#============================================
def main() -> None:
	"""Run both external-change scenarios and exit non-zero on any failure."""
	repo_root = get_repo_root()
	app_path = get_app_path(repo_root)
	refuse_if_another_codeedit_is_running()

	run_clean_reload_scenario(app_path)
	run_dirty_conflict_scenario(app_path)

	print("e2e_external_change_conflict: PASS")


if __name__ == '__main__':
	main()
