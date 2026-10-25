"""Copy usable slice components into Godot's imported assets directory.

Source artwork stays untouched under art_sources, which Godot ignores.
Drop detached neighboring-slice debris, retaining the largest alpha component.
Run with Python + Pillow. Anchors and surface UVs live in terrain_lab2.gd.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SLICES = [6, 9, 10, 25, 27, 28, 30, 31, 49, 50, 51, 53, 58, 60, 62, 67, 69, 70, 73, 74]


def prepare():
    target = ROOT / 'assets/terrain_painted'
    target.mkdir(exist_ok=True)
    for number in SLICES:
        image = Image.open(ROOT / f'art_sources/slices/sliced/slice{number:02}_.png').convert('RGBA')
        alpha = image.getchannel('A')
        remaining = {(x, y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x, y)) > 8}
        groups = []
        while remaining:
            seed = remaining.pop()
            group, stack = {seed}, [seed]
            while stack:
                x, y = stack.pop()
                for neighbor in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        group.add(neighbor)
                        stack.append(neighbor)
            groups.append(group)
        main = max(groups, key=len)
        # Preserve original image dimensions so measured anchors remain valid.
        mask = Image.new('L', image.size)
        for x, y in main:
            mask.putpixel((x, y), alpha.getpixel((x, y)))
        image.putalpha(mask)
        image.save(target / f'slice{number:02}.png')
        print(f'slice{number:02}: kept {len(main)} pixels, removed {sum(map(len, groups)) - len(main)}')


if __name__ == '__main__':
    prepare()
