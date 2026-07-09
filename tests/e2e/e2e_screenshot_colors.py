#!/usr/bin/env python3
"""Count distinct hues in a screenshot to prove syntax highlighting is visible.

Crops 10% off all four edges of the target image (to avoid window chrome and
scrollbar noise), quantizes each RGB channel to 32-value buckets to tolerate
antialiasing, then splits the quantized buckets into grayscale (antialiasing
ramps of plain black-on-white or white-on-black text) and chromatic buckets.
Chromatic buckets are grouped into 30-degree hue families, and the count of
families holding at least 0.05% of the cropped pixels combined is used as the
proof of multi-color syntax highlighting: a plain grayscale bucket count
proves nothing about highlighting, since antialiased text alone produces many
grayscale buckets.
"""

# Standard Library
import sys
import pathlib
import colorsys
import collections

# PIP3 modules
import numpy
import PIL.Image  # pillow

DEFAULT_IMAGE_PATH = pathlib.Path("docs/screenshots/codeedit_window.png")
CROP_FRACTION = 0.10
QUANTIZE_STEP = 32
MIN_PIXEL_SHARE = 0.001
MIN_HUE_FAMILY_SHARE = 0.0005
GRAYSCALE_SPREAD_THRESHOLD = 40
HUE_FAMILY_DEGREES = 30
MIN_CHROMATIC_HUE_FAMILIES = 3
TOP_BUCKETS_TO_REPORT = 10


#============================================
def get_target_image_path(argv: list[str]) -> pathlib.Path:
	"""Return the image path to check, from the optional positional argument.

	Args:
		argv: command-line arguments excluding the program name.

	Returns:
		pathlib.Path: path to the image to analyze.
	"""
	if len(argv) >= 1:
		return pathlib.Path(argv[0])
	return DEFAULT_IMAGE_PATH


#============================================
def load_cropped_image(image_path: pathlib.Path) -> PIL.Image.Image:
	"""Open the image and crop 10% off all four edges.

	Args:
		image_path: path to the source screenshot.

	Returns:
		PIL.Image.Image: the cropped RGB image.

	Raises:
		FileNotFoundError: when image_path does not exist.
	"""
	if not image_path.exists():
		raise FileNotFoundError(f"Screenshot file not found: {image_path}")

	image = PIL.Image.open(image_path).convert("RGB")
	width, height = image.size
	# Crop 10% off each edge so window chrome and scrollbars do not
	# contribute noise to the color count.
	left = int(width * CROP_FRACTION)
	top = int(height * CROP_FRACTION)
	right = width - left
	bottom = height - top
	return image.crop((left, top, right, bottom))


#============================================
def count_bucket_pixels(cropped_image: PIL.Image.Image) -> collections.Counter:
	"""Quantize each pixel's RGB channels to QUANTIZE_STEP-sized buckets and count them.

	Args:
		cropped_image: the cropped RGB image to analyze.

	Returns:
		collections.Counter: bucket (r, g, b) tuple to pixel count.
	"""
	pixel_array = numpy.asarray(cropped_image)
	# Quantize each channel down to the start of its QUANTIZE_STEP-sized
	# bucket, then flatten to a list of (r, g, b) bucket tuples.
	quantized_array = (pixel_array // QUANTIZE_STEP) * QUANTIZE_STEP
	flattened_buckets = quantized_array.reshape(-1, 3)

	bucket_counts: collections.Counter = collections.Counter()
	for red, green, blue in flattened_buckets.tolist():
		bucket_counts[(red, green, blue)] += 1
	return bucket_counts


#============================================
def get_significant_buckets(
	bucket_counts: collections.Counter, total_pixels: int, min_pixel_share: float,
) -> list[tuple[tuple[int, int, int], int]]:
	"""Return buckets holding at least min_pixel_share of total_pixels, largest first.

	Args:
		bucket_counts: bucket (r, g, b) tuple to pixel count.
		total_pixels: total number of pixels in the cropped image.
		min_pixel_share: minimum fraction of total_pixels a bucket must hold.

	Returns:
		list[tuple[tuple[int, int, int], int]]: (bucket, count) pairs, sorted
			by count descending.
	"""
	minimum_pixel_count = total_pixels * min_pixel_share
	significant_buckets = [
		(bucket, count) for bucket, count in bucket_counts.items()
		if count >= minimum_pixel_count
	]
	significant_buckets.sort(key=lambda pair: pair[1], reverse=True)
	return significant_buckets


#============================================
def compute_channel_spread(bucket: tuple[int, int, int]) -> int:
	"""Return the gap between the brightest and dimmest channel of a bucket.

	Args:
		bucket: quantized (r, g, b) tuple.

	Returns:
		int: max(bucket) - min(bucket). A small spread means the bucket is
			grayscale (r, g, and b are close together); a large spread means
			the bucket carries actual hue.
	"""
	return max(bucket) - min(bucket)


#============================================
def compute_bucket_hue_degrees(bucket: tuple[int, int, int]) -> float:
	"""Return the hue angle, in degrees, of a quantized RGB bucket.

	Args:
		bucket: quantized (r, g, b) tuple.

	Returns:
		float: hue in the range [0, 360).
	"""
	red, green, blue = bucket
	# rgb_to_hsv expects channels scaled to the 0-1 range.
	hue_fraction, _saturation, _value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
	return hue_fraction * 360


#============================================
def split_significant_buckets_by_hue(
	significant_buckets: list[tuple[tuple[int, int, int], int]],
) -> tuple[
	list[tuple[tuple[int, int, int], int]], list[tuple[tuple[int, int, int], int]],
]:
	"""Partition significant buckets into grayscale and chromatic groups.

	Args:
		significant_buckets: (bucket, count) pairs, sorted by count descending.

	Returns:
		tuple: (grayscale_buckets, chromatic_buckets), each a list of
			(bucket, count) pairs preserving the input order.
	"""
	grayscale_buckets = []
	chromatic_buckets = []
	for bucket, count in significant_buckets:
		if compute_channel_spread(bucket) < GRAYSCALE_SPREAD_THRESHOLD:
			grayscale_buckets.append((bucket, count))
		else:
			chromatic_buckets.append((bucket, count))
	return grayscale_buckets, chromatic_buckets


#============================================
def count_all_chromatic_buckets(bucket_counts: collections.Counter) -> int:
	"""Count every chromatic bucket, ignoring the per-bucket display share floor.

	Args:
		bucket_counts: bucket (r, g, b) tuple to pixel count.

	Returns:
		int: number of buckets whose channel spread marks them as chromatic.
	"""
	chromatic_total = sum(
		1 for bucket in bucket_counts
		if compute_channel_spread(bucket) >= GRAYSCALE_SPREAD_THRESHOLD
	)
	return chromatic_total


#============================================
def get_chromatic_hue_families(
	bucket_counts: collections.Counter, total_pixels: int,
) -> list[tuple[int, int]]:
	"""Group chromatic buckets into 30-degree hue families and keep the significant ones.

	Grayscale buckets (antialiasing ramps of plain text) are excluded before
	grouping, since they carry no hue signal. Every chromatic bucket
	contributes to its family regardless of its own individual pixel share,
	so faint but consistently colored tokens still register once their
	family total crosses MIN_HUE_FAMILY_SHARE.

	Args:
		bucket_counts: bucket (r, g, b) tuple to pixel count.
		total_pixels: total number of pixels in the cropped image.

	Returns:
		list[tuple[int, int]]: (family_start_degree, combined_count) pairs
			for families holding at least MIN_HUE_FAMILY_SHARE of
			total_pixels, sorted by combined_count descending.
	"""
	minimum_family_count = total_pixels * MIN_HUE_FAMILY_SHARE
	family_totals: collections.Counter = collections.Counter()
	for bucket, count in bucket_counts.items():
		if compute_channel_spread(bucket) < GRAYSCALE_SPREAD_THRESHOLD:
			continue
		hue_degrees = compute_bucket_hue_degrees(bucket)
		family_start = int(hue_degrees // HUE_FAMILY_DEGREES) * HUE_FAMILY_DEGREES
		family_totals[family_start] += count

	qualifying_families = [
		(family_start, family_count) for family_start, family_count in family_totals.items()
		if family_count >= minimum_family_count
	]
	qualifying_families.sort(key=lambda pair: pair[1], reverse=True)
	return qualifying_families


#============================================
def print_color_report(
	grayscale_buckets: list[tuple[tuple[int, int, int], int]],
	chromatic_buckets: list[tuple[tuple[int, int, int], int]],
	chromatic_hue_families: list[tuple[int, int]],
	chromatic_bucket_total: int,
	total_pixels: int,
) -> None:
	"""Print the grayscale/chromatic/hue-family summary and the top buckets.

	The chromatic bucket count is reported two ways so the numbers cannot read
	as contradictory: chromatic_buckets_total counts every chromatic bucket
	(the same population hue families are built from), while
	chromatic_buckets_printed counts only the buckets above the per-bucket
	display share floor (MIN_PIXEL_SHARE) that appear in the top list below.

	Args:
		grayscale_buckets: significant grayscale (bucket, count) pairs, sorted descending.
		chromatic_buckets: significant chromatic (bucket, count) pairs, sorted descending.
		chromatic_hue_families: qualifying (family_start_degree, count) pairs, sorted descending.
		chromatic_bucket_total: count of all chromatic buckets, ignoring the display floor.
		total_pixels: total number of pixels in the cropped image.
	"""
	print(f"grayscale_buckets={len(grayscale_buckets)}")
	print(f"chromatic_buckets_total={chromatic_bucket_total}")
	print(f"chromatic_buckets_printed={len(chromatic_buckets)}")
	print(f"chromatic_hue_families={len(chromatic_hue_families)}")

	print("top chromatic buckets (above display floor):")
	for bucket, count in chromatic_buckets[:TOP_BUCKETS_TO_REPORT]:
		hue_degrees = compute_bucket_hue_degrees(bucket)
		pixel_share = count / total_pixels
		print(f"bucket={bucket} hue={hue_degrees:.1f} count={count} share={pixel_share:.4f}")

	print("top grayscale buckets:")
	for bucket, count in grayscale_buckets[:TOP_BUCKETS_TO_REPORT]:
		pixel_share = count / total_pixels
		print(f"bucket={bucket} count={count} share={pixel_share:.4f}")


#============================================
def main() -> None:
	"""Check the screenshot for a minimum number of distinct chromatic hue families."""
	image_path = get_target_image_path(sys.argv[1:])
	cropped_image = load_cropped_image(image_path)
	total_pixels = cropped_image.width * cropped_image.height

	bucket_counts = count_bucket_pixels(cropped_image)
	significant_buckets = get_significant_buckets(bucket_counts, total_pixels, MIN_PIXEL_SHARE)
	grayscale_buckets, chromatic_buckets = split_significant_buckets_by_hue(significant_buckets)
	chromatic_hue_families = get_chromatic_hue_families(bucket_counts, total_pixels)
	chromatic_bucket_total = count_all_chromatic_buckets(bucket_counts)

	print_color_report(
		grayscale_buckets, chromatic_buckets, chromatic_hue_families,
		chromatic_bucket_total, total_pixels,
	)

	if len(chromatic_hue_families) < MIN_CHROMATIC_HUE_FAMILIES:
		raise SystemExit(
			f"chromatic_hue_families={len(chromatic_hue_families)} is below the "
			f"minimum {MIN_CHROMATIC_HUE_FAMILIES}; syntax highlighting does not "
			f"appear visible in {image_path}."
		)


if __name__ == '__main__':
	main()
