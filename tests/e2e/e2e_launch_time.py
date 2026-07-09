#!/usr/bin/env python3
"""Launch the built app five times and gate on the LAUNCH_TO_WINDOW_MS marker.

Launches ./.build/debug/SwiftlyCodeEdit with --kill-after=3 five times, parses the
LAUNCH_TO_WINDOW_MS runtime log marker from each run, reports min/median/max,
and exits non-zero when the median exceeds the budget.
"""

# Standard Library
import os
import re
import shutil
import pathlib
import statistics
import subprocess

NUM_RUNS = 5
KILL_AFTER_SECONDS = 3
# Provisional single budget for now (cold and warm are not yet split out on
# separate hardware baselines); revisit as a logged decision once the
# recorded baseline hardware exists.
BUDGET_MEDIAN_MS = 1000
LAUNCH_TIMEOUT_SECONDS = 15
RUNTIME_LOG_PATH = pathlib.Path("/tmp/codeedit_runtime.log")  # nosec B108 - fixed path written by DebugRuntimeLog.swift
LAUNCH_MARKER_PATTERN = re.compile(r"LAUNCH_TO_WINDOW_MS=(\d+)")


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
def get_hardware_model() -> str:
	"""Return the Mac hardware model string via sysctl.

	Returns:
		str: the hw.model sysctl value.
	"""
	result = subprocess.run(
		["sysctl", "-n", "hw.model"],
		capture_output=True, text=True, check=True,
	)
	return result.stdout.strip()


#============================================
def prepare_source_file(repo_root: pathlib.Path) -> pathlib.Path:
	"""Copy the deterministic source template to a fixed temp path.

	Args:
		repo_root: repository root path.

	Returns:
		pathlib.Path: path to the copied source file used for every launch.
	"""
	source_template = (
		repo_root / "CodeEdit" / "Features" / "Documents"
		/ "CodeFileDocument" / "CodeFileDocument.swift"
	)
	source_file = pathlib.Path("/tmp/codeedit_e2e_launch_time_source.swift")  # nosec B108 - fixed path paired with runtime log contract
	shutil.copyfile(source_template, source_file)
	return source_file


#============================================
def run_once(app_path: pathlib.Path, source_file: pathlib.Path) -> int:
	"""Launch the app once and return the parsed LAUNCH_TO_WINDOW_MS value.

	Args:
		app_path: path to the built app binary.
		source_file: deterministic source file to open on launch.

	Returns:
		int: the measured launch-to-window time in milliseconds.
	"""
	# Clear the shared runtime log before each run so this run's marker
	# cannot be confused with a marker left over from a prior run.
	RUNTIME_LOG_PATH.write_text("")

	launch_env = os.environ.copy()
	launch_env["CODEEDIT_DEBUG_SOURCE_FILE"] = str(source_file)
	launch_env["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] = "1"

	subprocess.run(
		[str(app_path), f"--kill-after={KILL_AFTER_SECONDS}"],
		env=launch_env, timeout=LAUNCH_TIMEOUT_SECONDS,
	)

	runtime_log_text = RUNTIME_LOG_PATH.read_text()
	match = LAUNCH_MARKER_PATTERN.search(runtime_log_text)
	if match is None:
		raise RuntimeError(
			"LAUNCH_TO_WINDOW_MS marker not found in runtime log after launch."
		)
	return int(match.group(1))


#============================================
def measure_launch_times(app_path: pathlib.Path, source_file: pathlib.Path) -> list[int]:
	"""Launch the app NUM_RUNS times and collect each measured launch time.

	Args:
		app_path: path to the built app binary.
		source_file: deterministic source file to open on launch.

	Returns:
		list[int]: measured launch-to-window times in milliseconds, one per run.
	"""
	launch_times_ms: list[int] = []
	for run_index in range(NUM_RUNS):
		elapsed_ms = run_once(app_path, source_file)
		launch_times_ms.append(elapsed_ms)
		print(f"run {run_index + 1}/{NUM_RUNS}: LAUNCH_TO_WINDOW_MS={elapsed_ms}")
	return launch_times_ms


#============================================
def write_results_report(
	results_file: pathlib.Path, hardware_model: str,
	launch_times_ms: list[int], median_ms: float,
) -> None:
	"""Write the measured launch times and hardware model to a results file.

	Args:
		results_file: destination path for the report.
		hardware_model: the hw.model sysctl value.
		launch_times_ms: measured launch-to-window times in milliseconds.
		median_ms: median of launch_times_ms.
	"""
	report_lines = []
	report_lines.append(f"hardware_model={hardware_model}")
	report_lines.append(f"runs={launch_times_ms}")
	report_lines.append(f"min_ms={min(launch_times_ms)}")
	report_lines.append(f"median_ms={median_ms}")
	report_lines.append(f"max_ms={max(launch_times_ms)}")
	report_lines.append(f"budget_median_ms={BUDGET_MEDIAN_MS}")
	report_text = "\n".join(report_lines) + "\n"

	results_file.parent.mkdir(parents=True, exist_ok=True)
	results_file.write_text(report_text)


#============================================
def main() -> None:
	"""Measure launch-to-window time across five runs and gate on the median."""
	repo_root = get_repo_root()
	app_path = get_app_path(repo_root)
	source_file = prepare_source_file(repo_root)

	launch_times_ms = measure_launch_times(app_path, source_file)
	min_ms = min(launch_times_ms)
	median_ms = statistics.median(launch_times_ms)
	max_ms = max(launch_times_ms)
	print(f"min={min_ms} median={median_ms} max={max_ms}")

	hardware_model = get_hardware_model()
	results_file = repo_root / "test-results" / "perf" / "launch_time.txt"
	write_results_report(results_file, hardware_model, launch_times_ms, median_ms)

	if median_ms > BUDGET_MEDIAN_MS:
		raise SystemExit(
			f"LAUNCH_TO_WINDOW_MS median {median_ms} exceeds budget {BUDGET_MEDIAN_MS}"
		)


if __name__ == '__main__':
	main()
