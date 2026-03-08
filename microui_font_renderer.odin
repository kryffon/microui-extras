package main

import "core:os"
import mu "vendor:microui"
import stbtt "vendor:stb/truetype"

ATLAS_WIDTH :: 128
ATLAS_HEIGHT :: 128

Font :: struct {
	width, height: i32,
	yoffset:       i32,
	pixel_height:  i32,
	atlas:         []stbtt.bakedchar,
	alpha:         []u8,
}

get_text_width :: proc(mufont: mu.Font, text: string) -> (width: i32) {
	font := (^Font)(rawptr(mufont))
	for ch in text do if ch & 0xc0 != 0x80 {
		r := min(int(ch), 127)
		width += i32(font.atlas[mu.DEFAULT_ATLAS_FONT + r].xadvance)
	}
	return
}

get_text_height :: proc(mufont: mu.Font) -> (width: i32) {
	font := (^Font)(rawptr(mufont))
	return font.pixel_height
}

// returns src, dst and updates cursor for next char
get_text_coords :: proc(font: ^Font, ch: rune, cursor: ^mu.Rect) -> (src, dst: mu.Rect) {
	glyph := font.atlas[mu.DEFAULT_ATLAS_FONT + min(int(ch), 127)]
	src = mu.Rect {
		i32(glyph.x0),
		i32(glyph.y0),
		i32(glyph.x1) - i32(glyph.x0),
		i32(glyph.y1) - i32(glyph.y0),
	}
	dst = mu.Rect{cursor.x + i32(glyph.xoff), cursor.y + i32(glyph.yoff), src.w, src.h}
	cursor.x += i32(glyph.xadvance)
	return
}

get_src_rect :: proc(glyph: stbtt.bakedchar) -> mu.Rect {
	return mu.Rect {
		i32(glyph.x0),
		i32(glyph.y0),
		i32(glyph.x1) - i32(glyph.x0),
		i32(glyph.y1) - i32(glyph.y0),
	}
}

load_font :: proc(fontfile: string, fontsize: i32) -> (font: Font) {
	ttf_data, err := os.read_entire_file(fontfile, context.temp_allocator)
	assert(err == nil, "failed to read font file")

	font.width = ATLAS_WIDTH
	font.height = ATLAS_HEIGHT
	font.pixel_height = fontsize
	// yoffset needed rigth now. why? idk
	font.yoffset = fontsize * 8 / 10

	font.alpha = make([]u8, ATLAS_WIDTH * ATLAS_HEIGHT)
	font.atlas = make([]stbtt.bakedchar, len(mu.default_atlas))

	FIRST_CHAR :: 32
	NUM_CHARS :: 96
	last_row := stbtt.BakeFontBitmap(
		raw_data(ttf_data),
		0,
		f32(font.pixel_height),
		raw_data(font.alpha),
		ATLAS_WIDTH,
		ATLAS_HEIGHT,
		FIRST_CHAR,
		NUM_CHARS,
		raw_data(font.atlas[mu.DEFAULT_ATLAS_FONT + FIRST_CHAR:]),
	)
	assert(last_row > 0, "failed to bake bitmap")

	add_microui_icons(last_row, &font)

	return
}

destroy_font :: proc(font: ^Font) {
	delete(font.atlas)
	delete(font.alpha)
}

add_microui_icons :: proc(last_row: i32, font: ^Font) {
	last_row := last_row

	mu_icons_id := [?]int {
		mu.DEFAULT_ATLAS_ICON_CHECK,
		mu.DEFAULT_ATLAS_ICON_CLOSE,
		mu.DEFAULT_ATLAS_ICON_RESIZE,
		mu.DEFAULT_ATLAS_ICON_COLLAPSED,
		mu.DEFAULT_ATLAS_ICON_EXPANDED,
		mu.DEFAULT_ATLAS_WHITE,
	}
	dst := mu.Rect {
		x = 0,
		y = last_row + 1,
	}
	for icon_id in mu_icons_id {
		src := mu.default_atlas[icon_id]
		dst.w, dst.h = src.w, src.h

		if dst.x + dst.w > ATLAS_WIDTH {
			dst.x, dst.y = 0, last_row + 1
		}
		assert(dst.y + dst.h < ATLAS_HEIGHT)
		last_row = max(last_row, dst.y + dst.h)

		for x := i32(0); x < src.w; x += 1 {
			for y := i32(0); y < src.h; y += 1 {
				font.alpha[(dst.x + x) + ATLAS_WIDTH * (dst.y + y)] =
					mu.default_atlas_alpha[(src.x + x) + mu.DEFAULT_ATLAS_WIDTH * (src.y + y)]
			}
		}

		font.atlas[icon_id] = {
			x0       = u16(dst.x),
			y0       = u16(dst.y),
			x1       = u16(dst.x + dst.w),
			y1       = u16(dst.y + dst.h),
			xadvance = f32(dst.w),
		}

		dst.x += dst.w
	}
}

load_default_font :: proc() -> (font: Font) {
	font.width = mu.DEFAULT_ATLAS_WIDTH
	font.height = mu.DEFAULT_ATLAS_HEIGHT
	font.pixel_height = 18
	font.alpha = make([]u8, len(mu.default_atlas_alpha))
	for a, i in mu.default_atlas_alpha do font.alpha[i] = a

	font.atlas = make([]stbtt.bakedchar, len(mu.default_atlas))
	for src, i in mu.default_atlas {
		font.atlas[i] = {
			x0       = u16(src.x),
			y0       = u16(src.y),
			x1       = u16(src.x + src.w),
			y1       = u16(src.y + src.h),
			xadvance = f32(src.w),
		}
	}
	return
}

