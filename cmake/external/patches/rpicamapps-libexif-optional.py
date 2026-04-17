#!/usr/bin/env python3
"""
Patch rpicam-apps to make libexif optional.

In rpicam-apps v1.9.1+ image/meson.build declares libexif with required: true,
and jpeg.cpp unconditionally includes <libexif/exif-data.h> throughout.

This patch:
1. Changes image/meson.build: required: true -> required: false for libexif.
2. Guards all libexif-specific code in jpeg.cpp with HAVE_LIBEXIF (derived from
   __has_include), so the file compiles with or without libexif headers present:

  HAVE_LIBEXIF=1  ->  full JPEG+EXIF save (original behaviour)
  HAVE_LIBEXIF=0  ->  JPEG save without EXIF metadata

Usage:
    python3 rpicamapps-libexif-optional.py <rpicam-apps-source-dir>
"""

import re
import sys

if len(sys.argv) != 2:
    print("Usage: rpicamapps-libexif-optional.py <source_dir>", file=sys.stderr)
    sys.exit(1)

source_dir = sys.argv[1]

# ── 0. Patch image/meson.build: make libexif not required ────────────────────
meson_path = source_dir + "/image/meson.build"
with open(meson_path, "r") as f:
    meson_src = f.read()

if "dependency('libexif', required : false)" in meson_src:
    print(f"Already patched: {meson_path}")
else:
    meson_src = meson_src.replace(
        "dependency('libexif', required : true)",
        "dependency('libexif', required : false)",
    )
    # Also handle older style without spaces around :
    meson_src = meson_src.replace(
        "dependency('libexif', required:true)",
        "dependency('libexif', required : false)",
    )
    with open(meson_path, "w") as f:
        f.write(meson_src)
    print(f"Patched: {meson_path}")

path = source_dir + "/image/jpeg.cpp"

with open(path, "r") as f:
    src = f.read()

# Guard is idempotent — skip if already applied.
if "HAVE_LIBEXIF" in src:
    print(f"Already patched: {path}")
    sys.exit(0)

# ── 1. Guard the libexif include; define HAVE_LIBEXIF via __has_include ──────
src = src.replace(
    "#include <libexif/exif-data.h>",
    "#if __has_include(<libexif/exif-data.h>)\n"
    "#include <libexif/exif-data.h>\n"
    "#define HAVE_LIBEXIF 1\n"
    "#else\n"
    "#define HAVE_LIBEXIF 0\n"
    "#endif",
)

# ── 2. Wrap EXIF-only typedefs/declarations up to YUYV_to_JPEG ───────────────
src = src.replace(
    "typedef int (*ExifReadFunction)",
    "#if HAVE_LIBEXIF\ntypedef int (*ExifReadFunction)",
)
src = src.replace(
    "static void YUYV_to_JPEG(",
    "#endif // HAVE_LIBEXIF\n\nstatic void YUYV_to_JPEG(",
)

# ── 3. Wrap create_exif_data (uses ExifData types and calls YUV_to_JPEG) ─────
src = src.replace(
    "static void create_exif_data(",
    "#if HAVE_LIBEXIF\nstatic void create_exif_data(",
)

# ── 4. Replace jpeg_save with a version that has HAVE_LIBEXIF / fallback ─────
#
# Full (EXIF) path:   identical to original — EXIF header + data + thumbnail.
# Fallback (no EXIF): plain JPEG buffer written directly.

fallback_jpeg_save = """\
#endif // HAVE_LIBEXIF

void jpeg_save(std::vector<libcamera::Span<uint8_t>> const &mem, StreamInfo const &info, ControlList const &metadata,
\t\t\t   std::string const &filename, std::string const &cam_model, StillOptions const *options)
{
#if HAVE_LIBEXIF
\tFILE *fp = nullptr;
\tuint8_t *thumb_buffer = nullptr;
\tunsigned char *exif_buffer = nullptr;
\tuint8_t *jpeg_buffer = nullptr;

\ttry
\t{
\t\tif ((info.width & 1) || (info.height & 1))
\t\t\tthrow std::runtime_error("both width and height must be even");
\t\tif (mem.size() != 1)
\t\t\tthrow std::runtime_error("only single plane YUV supported");

\t\tjpeg_mem_len_t thumb_len = 0;
\t\tunsigned int exif_len;
\t\tcreate_exif_data(mem, info, metadata, cam_model, options, exif_buffer, exif_len, thumb_buffer, thumb_len);

\t\tjpeg_mem_len_t jpeg_len;
\t\tYUV_to_JPEG((uint8_t *)(mem[0].data()), info, info.width, info.height, options->Get().quality,
\t\t\t\t\toptions->Get().restart, jpeg_buffer, jpeg_len);
\t\tLOG(2, "JPEG size is " << jpeg_len);

\t\tfp = filename == "-" ? stdout : fopen(filename.c_str(), "w");
\t\tif (!fp)
\t\t\tthrow std::runtime_error("failed to open file " + options->Get().output);

\t\tLOG(2, "EXIF data len " << exif_len);

\t\tif (fwrite(exif_header, sizeof(exif_header), 1, fp) != 1 ||
\t\t\tfputc((exif_len + thumb_len + 2) >> 8, fp) == EOF ||
\t\t\tfputc((exif_len + thumb_len + 2) & 0xff, fp) == EOF ||
\t\t\tfwrite(exif_buffer, exif_len, 1, fp) != 1 ||
\t\t\t(thumb_len && fwrite(thumb_buffer, thumb_len, 1, fp) != 1) ||
\t\t\tfwrite(jpeg_buffer + exif_image_offset, jpeg_len - exif_image_offset, 1, fp) != 1)
\t\t\tthrow std::runtime_error("failed to write file - output probably corrupt");

\t\tif (fp != stdout)
\t\t\tfclose(fp);
\t\tfp = nullptr;

\t\tfree(exif_buffer); exif_buffer = nullptr;
\t\tfree(thumb_buffer); thumb_buffer = nullptr;
\t\tfree(jpeg_buffer); jpeg_buffer = nullptr;
\t}
\tcatch (std::exception const &e)
\t{
\t\tif (fp) fclose(fp);
\t\tfree(exif_buffer);
\t\tfree(thumb_buffer);
\t\tfree(jpeg_buffer);
\t\tthrow;
\t}
#else
\t// libexif not available: save JPEG without EXIF metadata.
\tuint8_t *jpeg_buffer = nullptr;
\ttry
\t{
\t\tif ((info.width & 1) || (info.height & 1))
\t\t\tthrow std::runtime_error("both width and height must be even");
\t\tif (mem.size() != 1)
\t\t\tthrow std::runtime_error("only single plane YUV supported");

\t\tjpeg_mem_len_t jpeg_len;
\t\tYUV_to_JPEG((uint8_t *)(mem[0].data()), info, info.width, info.height, options->Get().quality,
\t\t\t\t\toptions->Get().restart, jpeg_buffer, jpeg_len);
\t\tLOG(2, "JPEG size is " << jpeg_len);

\t\tFILE *fp = filename == "-" ? stdout : fopen(filename.c_str(), "w");
\t\tif (!fp)
\t\t\tthrow std::runtime_error("failed to open file " + options->Get().output);
\t\tif (fwrite(jpeg_buffer, jpeg_len, 1, fp) != 1)
\t\t\tthrow std::runtime_error("failed to write file - output probably corrupt");
\t\tif (fp != stdout)
\t\t\tfclose(fp);
\t\tfree(jpeg_buffer);
\t\tjpeg_buffer = nullptr;
\t}
\tcatch (std::exception const &e)
\t{
\t\tfree(jpeg_buffer);
\t\tthrow;
\t}
#endif
}
"""

src = re.sub(
    r"void jpeg_save\(.*?^\}\n",
    fallback_jpeg_save,
    src,
    count=1,
    flags=re.DOTALL | re.MULTILINE,
)

with open(path, "w") as f:
    f.write(src)

print(f"Patched: {path}")
