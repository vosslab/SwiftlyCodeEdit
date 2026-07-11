#!/usr/bin/env python3
"""Check whether a screenshot capture is unusably near-black.

Exits 0 when the image looks like a real captured window (mean brightness at
or above the near-black floor) and raises otherwise. A near-black capture is
the signature of an easy-screenshot run taken while the display was asleep
or locked, not a repo bug, so callers should treat a non-zero exit here as a
skip rather than a hard failure.
"""

# Standard Library
import argparse
import pathlib

# PIP3 modules
import numpy
import PIL.Image  # pillow

# Real captured windows (light or dark chrome, syntax-highlighted text) mean
# well above this floor; a slept-display capture reads as solid RGB(0,0,0).
NEAR_BLACK_MEAN_FLOOR = 8.0


#============================================
def compute_mean_brightness(image_path: pathlib.Path) -> float:
	"""Return the mean grayscale brightness (0-255) of the image at image_path.

	Args:
		image_path: path to the PNG capture to check.

	Returns:
		float: mean brightness across every pixel.
	"""
	image = PIL.Image.open(image_path).convert("L")
	pixel_array = numpy.asarray(image)
	mean_brightness = float(pixel_array.mean())
	return mean_brightness


#============================================
def parse_args() -> argparse.Namespace:
	"""Parse command-line arguments.

	Returns:
		argparse.Namespace: parsed arguments with an image_path field.
	"""
	parser = argparse.ArgumentParser(
		description="Check whether a screenshot capture is unusably near-black.")
	parser.add_argument(
		'-i', '--input', dest='image_path', required=True,
		help="path to the PNG capture to check")
	args = parser.parse_args()
	return args


#============================================
def main() -> None:
	"""Raise an error when the given screenshot is near-black (a slept-display capture)."""
	args = parse_args()
	image_path = pathlib.Path(args.image_path)
	mean_brightness = compute_mean_brightness(image_path)
	print(f"mean_brightness={mean_brightness:.2f}")

	if mean_brightness < NEAR_BLACK_MEAN_FLOOR:
		raise RuntimeError(
			f"mean_brightness={mean_brightness:.2f} is below the near-black floor "
			f"{NEAR_BLACK_MEAN_FLOOR}; capture looks like a slept or locked display."
		)


if __name__ == '__main__':
	main()
