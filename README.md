# Specced

Quick-lookup Mac app for export settings: which pixel dimensions for what,
which DPI for prints vs murals vs screens, which file format to actually use.
Built so the answer is one ⌘Space away instead of re-deriving it or digging
through an old chat every time. - GE

## Building

```
./build.sh
```

Produces `build/Specced.app`. Needs only the Xcode Command Line Tools — no
Xcode, no package manager, no dependencies.

## How it works

**Calculator** — width × height × DPI → pixels, with optional bleed. Switch
the unit to `px` to run it backwards (pixels + target DPI → print size).
Enter a viewing distance to get the minimum DPI that still looks sharp —
the answer for murals and banners. Results show the aspect ratio and
uncompressed file size, and warn when a file will break Photoshop's
30,000 px PSD limit, JPEG's 65,535 px limit, or InDesign's 216 in page.
Click any result to copy it.

**Reference tables** — Music & Streaming (cover art, Canvas, artist images),
Social Media, Print, and Web & Screen. Print sizes are computed from their
physical dimensions at whatever DPI you pick (300 / 150 / 100 / 72).

**Print specs** — click any print size for what to actually send: bleed,
the full document size in inches and pixels, safe zone, recommended DPI,
color mode, file format and paper. The calculator shows the same card for
whatever size you type and recognizes known ones (11 × 17 comes up as a
Tabloid poster: 0.125 in bleed → 11.25 × 17.25 in → 3375 × 5175 px).
"Print as" overrides the guess; "Use this bleed and DPI" applies it.

**Check a File** (toolbar, ⌘O, or drop an image on the window or Dock icon)
— pick what it's for and Specced checks the actual file: resolution at
that size, shape and crop, bleed, color profile, format, platform file-size
caps, and text sitting where the Instagram UI, a profile-grid crop or a
trim cut would hide it (found with macOS's on-device text recognition —
nothing is uploaded). Stores' no-URL rule and Spotify's no-text rule are
checked too. **Export Fixed Copy** does what can honestly be fixed:
crops, downsizes and converts screen images to sRGB under any size cap,
and retags print files with their real DPI as lossless TIFF. It never
upscales, and it won't pretend to fix a low-res file or missing bleed.

**File Formats** — images, video, and color (RGB vs CMYK, rich black).
**Sending Out** — checklists for print shops, social, distributors, and
clients. **DPI vs PPI** — the stuff that's easy to get backwards.

Search in the sidebar covers all of it — try "instagram", "a4", "vinyl",
"cmyk", or "1080x1920".

## Numbers

Platform specs were checked against the platforms' own docs where they
publish them (Apple, Spotify, SoundCloud, Bandcamp, YouTube) and current
guides where they don't. Things change. Lmk.

[gregor.art@pm.me](mailto:gregor.art@pm.me)
