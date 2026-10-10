# Supplied world art

One PNG per world, each containing **the planet and its king together** — the
map draws the file as a single sprite and skips its own planet/king pair for
that world.

Name each file for the world's id, which is also what the save file keys on:

```
neonia_1.png
sulfur_kor.png
crystallos.png
black_hole_04.png
celestial_ring_station.png
terra_former.png
gaia_prime.png
galactic_core.png
```

Worlds without a file keep the authored sprites in `planets.gd` / `kings.gd`,
so these can be added one at a time.

## Export settings

**PNG, never JPEG.** JPEG is lossy and smears exactly the hard edges that make
pixel art readable.

**Transparent background.** This is the one that matters most. A sprite on a
coloured background cannot be placed on the map's nebula, and the background
cannot be keyed out reliably — the first sheet had four different dark values
within a single cell, so any threshold loose enough to remove all of them also
ate the planets' own dark outlines.

**No labels in the image.** Names are drawn by the map, under each node.

**Native pixel resolution, or an exact integer multiple.** If the art is 32x32,
send 32x32 or 256x256 (8x). A 200x200 export of 32x32 art has already blended
the pixels and cannot be recovered.

**Nearest-neighbour on export, not bicubic.** Most pixel editors do this by
default; general image editors do not.

Around 32x32 of actual art is the sweet spot — they are drawn at roughly 96px
on the map, so that is a clean 3x.
