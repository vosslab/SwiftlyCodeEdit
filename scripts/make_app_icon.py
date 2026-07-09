#!/usr/bin/env python3
"""
Generate the SwiftlyCodeEdit app icon programmatically.

The logo is a lightning bolt centered between two angle brackets
(< bolt >), flat two-tone, drawn on a macOS-style rounded-square tile.
Renders every macOS icon size and saves them directly into a single
.icns file via Pillow's native ICNS writer (no `iconutil` dependency),
plus a 512px preview PNG for human review.
"""

# Standard Library
import os
import argparse

# PIP3 modules
import PIL.Image
import PIL.ImageDraw

# Master canvas size the logo is drawn at before downsampling.
MASTER_SIZE = 1024

# Flat two-tone palette: dark tile background, single bright accent glyph color.
BACKGROUND_COLOR = (20, 24, 31, 255)  # near-black charcoal navy
ACCENT_COLOR = (255, 214, 10, 255)  # bright electric yellow (speed / lightning)

# macOS 26 icon grid: corner radius ~22.5% of tile size, content inset ~10%.
CORNER_RADIUS_FRACTION = 0.225
CONTENT_INSET_FRACTION = 0.10

# Distinct pixel sizes covering the full macOS icon set (16 through 512@2x).
ICNS_SIZES = (16, 32, 64, 128, 256, 512, 1024)

PREVIEW_SIZE = 512


#============================================
def parse_args() -> argparse.Namespace:
	"""
	Parse command-line arguments.
	"""
	parser = argparse.ArgumentParser(description="Generate the SwiftlyCodeEdit app icon set")
	parser.add_argument(
		'-o', '--icns-out', dest='icns_out', default=os.path.join('Resources', 'SwiftlyCodeEdit.icns'),
		help='output path for the assembled .icns file',
	)
	parser.add_argument(
		'-p', '--preview-out', dest='preview_out',
		default=os.path.join('docs', 'screenshots', 'app_icon_preview.png'),
		help='output path for the 512px human-review preview PNG',
	)
	args = parser.parse_args()
	return args


#============================================
def draw_rounded_tile(size: int) -> PIL.Image.Image:
	"""
	Draw the dark rounded-square background tile at the given pixel size.
	"""
	image = PIL.Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = PIL.ImageDraw.Draw(image)
	corner_radius = int(size * CORNER_RADIUS_FRACTION)
	draw.rounded_rectangle(
		[(0, 0), (size - 1, size - 1)],
		radius=corner_radius,
		fill=BACKGROUND_COLOR,
	)
	return image


#============================================
def draw_chevron(
	draw: PIL.ImageDraw.ImageDraw,
	vertex_x: float,
	center_y: float,
	arm_dx: float,
	arm_dy: float,
	pointing_right: bool,
	thickness: int,
) -> None:
	"""
	Draw one thick angle-bracket chevron (< or >) with rounded joints and caps.
	"""
	# For ">" the arms extend to the left of the vertex; for "<" to the right.
	arm_sign = -1 if pointing_right else 1
	top_point = (vertex_x + arm_sign * arm_dx, center_y - arm_dy)
	vertex_point = (vertex_x, center_y)
	bottom_point = (vertex_x + arm_sign * arm_dx, center_y + arm_dy)
	draw.line([top_point, vertex_point, bottom_point], fill=ACCENT_COLOR, width=thickness, joint="curve")
	# Round off the two arm endpoints and the vertex so caps are not flat-cut.
	cap_radius = thickness / 2.0
	for point in (top_point, vertex_point, bottom_point):
		draw.ellipse(
			[point[0] - cap_radius, point[1] - cap_radius, point[0] + cap_radius, point[1] + cap_radius],
			fill=ACCENT_COLOR,
		)


#============================================
def bolt_polygon(center_x: float, center_y: float, width: float, height: float) -> list[tuple[float, float]]:
	"""
	Build the lightning-bolt polygon points, scaled and centered in a box.
	"""
	# Classic zigzag bolt shape, normalized to a unit box (x right, y down).
	unit_points = [
		(0.65, 0.0),
		(0.20, 0.58),
		(0.45, 0.58),
		(0.35, 1.0),
		(0.80, 0.42),
		(0.55, 0.42),
	]
	left_x = center_x - width / 2.0
	top_y = center_y - height / 2.0
	scaled_points = [
		(left_x + unit_x * width, top_y + unit_y * height)
		for unit_x, unit_y in unit_points
	]
	return scaled_points


#============================================
def render_master_icon() -> PIL.Image.Image:
	"""
	Render the full logo (tile plus bolt-between-brackets glyph) at MASTER_SIZE.
	"""
	image = draw_rounded_tile(MASTER_SIZE)
	draw = PIL.ImageDraw.Draw(image)

	# Content area sits inset from the tile edges; drawn extents (stroke
	# centerline plus rounded cap) land on the inset line, not inside it.
	inset = MASTER_SIZE * CONTENT_INSET_FRACTION
	chevron_thickness = int(MASTER_SIZE * 0.075)
	cap_radius = chevron_thickness / 2.0
	content_left = inset + cap_radius
	content_right = MASTER_SIZE - inset - cap_radius
	center_y = MASTER_SIZE / 2.0

	# Arm tips (plus rounded caps) reach the vertical 10% inset line.
	arm_dy = MASTER_SIZE / 2.0 - inset - cap_radius
	# Keep the original chevron dx/dy ratio (~0.53) so brackets stay pointed.
	arm_dx = arm_dy * 0.53

	# Left bracket "<" with its vertex (plus cap) on the left inset line.
	left_vertex_x = content_left
	draw_chevron(draw, left_vertex_x, center_y, arm_dx, arm_dy, pointing_right=False, thickness=chevron_thickness)

	# Right bracket ">" with its vertex (plus cap) on the right inset line.
	right_vertex_x = content_right
	draw_chevron(draw, right_vertex_x, center_y, arm_dx, arm_dy, pointing_right=True, thickness=chevron_thickness)

	# Lightning bolt centered between the two brackets, tips on the inset lines.
	bolt_height = MASTER_SIZE - 2.0 * inset
	bolt_width = bolt_height * (0.34 / 0.62)
	bolt_center_x = (content_left + content_right) / 2.0
	polygon_points = bolt_polygon(bolt_center_x, center_y, bolt_width, bolt_height)
	draw.polygon(polygon_points, fill=ACCENT_COLOR)

	return image


#============================================
def render_sized_icons(master_icon: PIL.Image.Image) -> dict[int, PIL.Image.Image]:
	"""
	Downsample the master icon into every distinct pixel size the icns needs.
	"""
	sized_icons = {}
	for pixel_size in ICNS_SIZES:
		sized_icons[pixel_size] = master_icon.resize((pixel_size, pixel_size), PIL.Image.LANCZOS)
	return sized_icons


#============================================
def write_icns(sized_icons: dict[int, PIL.Image.Image], icns_out: str) -> None:
	"""
	Save every rendered size directly into one .icns file via Pillow's ICNS writer.

	The largest rendered size is the base image; every other size is passed
	through append_images so Pillow embeds the full set in one file, with no
	external `iconutil` dependency.
	"""
	os.makedirs(os.path.dirname(icns_out), exist_ok=True)
	largest_size = max(ICNS_SIZES)
	base_icon = sized_icons[largest_size]
	other_icons = [sized_icons[size] for size in ICNS_SIZES if size != largest_size]
	base_icon.save(icns_out, format="ICNS", append_images=other_icons)


#============================================
def write_preview(master_icon: PIL.Image.Image, preview_out: str) -> None:
	"""
	Write a single flattened preview PNG at PREVIEW_SIZE for human review.
	"""
	os.makedirs(os.path.dirname(preview_out), exist_ok=True)
	preview = master_icon.resize((PREVIEW_SIZE, PREVIEW_SIZE), PIL.Image.LANCZOS)
	preview.save(preview_out)


#============================================
def main() -> None:
	args = parse_args()
	master_icon = render_master_icon()

	sized_icons = render_sized_icons(master_icon)
	write_icns(sized_icons, args.icns_out)
	write_preview(master_icon, args.preview_out)

	print(f"Wrote icns: {args.icns_out}")
	print(f"Wrote preview: {args.preview_out}")


if __name__ == '__main__':
	main()
