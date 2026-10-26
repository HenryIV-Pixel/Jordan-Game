"""Project Natural Earth shaded relief onto the game's map coordinates and colour it by climate.

Usage: python3 tools/build_terrain.py GRAY_HR_SR.tif LEGACY_MAP_JSON NE_GEOJSON_DIR OUT_DIR
  GRAY_HR_SR.tif: Natural Earth 10m gray shaded relief (github.com/nvkelso/natural-earth-raster)
Writes OUT_DIR/terrain.jpg covering map units X0..X1, Y0..Y1 at S px per unit, plus terrain.json.
Land outside the kingdom is dimmed so Jordan stands out.
"""
import sys
import json
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates, gaussian_filter, zoom

Image.MAX_IMAGE_PIXELS = None
SRC, LEGACY, NE, HERE = sys.argv[1:5]
M = json.load(open(LEGACY))['MAP']
KX, KY, LON0, LAT1 = M['kx'], M['ky'], M['lon0'], M['lat1']
X0, X1, Y0, Y1, S = -420, 1320, -320, 1020, 2.5

# crop the global raster (21600 x 10800, 1/60 degree per pixel, origin at 180W 90N)
img = Image.open(SRC)
lon_a, lon_b, lat_a, lat_b = 30.0, 43.5, 27.0, 36.0
px0, px1 = int((lon_a + 180) * 60), int((lon_b + 180) * 60)
py0, py1 = int((90 - lat_b) * 60), int((90 - lat_a) * 60)
crop = np.asarray(img.crop((px0, py0, px1, py1)), dtype=np.float32)
if crop.ndim == 3:
    crop = crop[..., 0]
print('crop', crop.shape, crop.min(), crop.max(), np.median(crop))

W, H = int((X1 - X0) * S), int((Y1 - Y0) * S)
xs = X0 + (np.arange(W) + 0.5) / S
ys = Y0 + (np.arange(H) + 0.5) / S
X, Y = np.meshgrid(xs, ys)
LON = X / KX + LON0
LAT = LAT1 - Y / KY
col = (LON - lon_a) * 60 - 0.5
row = (lat_b - LAT) * 60 - 0.5
shade = map_coordinates(crop, [row, col], order=3, mode='nearest')

# normalise: flat ground ~1.0, lit slopes >1, shadowed <1
flat = np.median(crop)
sh = shade / flat
sh = np.clip(sh, 0.35, 1.6)


def noise(shape, scale, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((shape[0] // scale + 3, shape[1] // scale + 3)).astype(np.float32)
    big = zoom(small, scale, order=3)[: shape[0], : shape[1]]
    return big


# fractal detail so close zoom does not look blurry
detail = sum(noise((H, W), s, i) * a for i, (s, a) in enumerate([(4, 0.35), (12, 0.35), (40, 0.3)]))
detail = (detail - detail.mean()) / detail.std()


warp1 = noise((H, W), 60, 7) + noise((H, W), 20, 8) * 0.5
warp2 = noise((H, W), 60, 9) + noise((H, W), 20, 10) * 0.5
LONr, LATr = LON, LAT
LON = LONr + (warp1 - 0.75) * 0.35
LAT = LATr + (warp2 - 0.75) * 0.3


def blob(lon, lat, rlon, rlat):
    b = np.exp(-(((LON - lon) / rlon) ** 2 + ((LAT - lat) / rlat) ** 2))
    return np.clip((b - 0.25) * 1.8, 0, 1)


sand = np.array([196, 172, 128], np.float32)
pale = np.array([214, 196, 156], np.float32)
olive = np.array([128, 132, 88], np.float32)
green = np.array([96, 114, 70], np.float32)
basalt = np.array([86, 80, 74], np.float32)
redrock = np.array([176, 112, 82], np.float32)
valley = np.array([110, 120, 76], np.float32)

w_olive = np.clip((LAT - 30.6) / 0.8, 0, 1) * np.clip((36.35 - LON) / 0.5, 0, 1)  # western highlands & West Bank
w_olive = np.maximum(w_olive, np.clip((LAT - 32.4) / 0.6, 0, 1) * np.clip((36.6 - LON) / 0.6, 0, 1))  # north (Irbid, Golan)
w_olive = np.maximum(w_olive, np.clip((LAT - 33.0) / 0.8, 0, 1) * np.clip((36.6 - LON) / 0.6, 0, 1) * 0.8)  # Lebanon / Damascus oasis
w_green = np.clip((LAT - 32.6) / 0.6, 0, 1) * np.clip((35.9 - LON) / 0.5, 0, 1) * 0.8  # Galilee / Mediterranean coast
w_valley = np.exp(-((LONr - (35.57 + (LATr - 32.0) * 0.02)) / 0.06) ** 2) * np.clip((LATr - 31.75) / 0.3, 0, 1) * np.clip((32.75 - LATr) / 0.2, 0, 1)
w_basalt = blob(37.3, 32.35, 0.8, 0.5) * 0.6 + blob(38.3, 32.9, 0.5, 0.35) * 0.45
w_red = blob(35.45, 29.6, 0.35, 0.45) * 0.8 + blob(35.2, 30.3, 0.15, 0.4) * 0.5
w_pale = np.clip((29.9 - LAT) / 1.2, 0, 1) * np.clip((34.9 - LON) / 0.8, 0, 1) + blob(39.0, 30.2, 1.5, 1.2) * 0.4

base = np.zeros((H, W, 3), np.float32) + sand
for w, c in [(w_pale, pale), (w_olive, olive), (w_green, green), (w_basalt, basalt), (w_red, redrock), (w_valley, valley)]:
    w = np.clip(w, 0, 1)[..., None]
    base = base * (1 - w) + c * w

# slight mottling of colour so desert is not flat
tone = 1 + 0.05 * detail
out = base * (sh[..., None] ** 1.15) * tone[..., None]
# bake sea and lakes from Natural Earth, with depth shading near the coast
from PIL import ImageDraw
from scipy.ndimage import distance_transform_edt
mask = Image.new('L', (W, H), 0); dr = ImageDraw.Draw(mask)
def proj(lon, lat): return (((lon - LON0) * KX - X0) * S, ((LAT1 - lat) * KY - Y0) * S)
def polys(fn):
    g = json.load(open(f'{NE}/{fn}'))
    for f in g['features']:
        geom = f['geometry']; rings = geom['coordinates'] if geom['type'] == 'Polygon' else [r for poly in geom['coordinates'] for r in poly]
        if geom['type'] == 'Polygon': rings = [rings[0]] + rings[1:]
        yield geom, rings
for fn in ['ne_10m_ocean.geojson', 'ne_10m_lakes.geojson']:
    g = json.load(open(f'{NE}/{fn}'))
    for f in g['features']:
        geom = f['geometry']
        plist = [geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']
        for poly in plist:
            outer = poly[0]
            xs_ = [c[0] for c in outer]; ys_ = [c[1] for c in outer]
            if max(xs_) < lon_a or min(xs_) > lon_b or max(ys_) < lat_a or min(ys_) > lat_b: continue
            dr.polygon([proj(x, y) for x, y in outer], fill=255)
            for hole in poly[1:]:
                dr.polygon([proj(x, y) for x, y in hole], fill=0)
water = np.asarray(mask, np.float32) / 255
dist = distance_transform_edt(water > 0.5) / S  # map units from the shore
depth = np.clip(dist / 40, 0, 1)[..., None]
shallow = np.array([52, 104, 118], np.float32); deep = np.array([22, 52, 70], np.float32)
wcol = shallow * (1 - depth) + deep * depth
wcol = wcol * (1 + 0.03 * detail[..., None])
wa = gaussian_filter(water, 0.8)[..., None]
# dim land outside the kingdom (East Bank + West Bank)
import re
kmask = Image.new('L', (W, H), 0); kd = ImageDraw.Draw(kmask)
for d in (M['eastBank'], M['westBank']):
    for sub in re.findall(r'M[^M]*', d):
        nums = [float(n) for n in re.findall(r'-?\d+\.?\d*', sub)]
        pts = [((nums[i] - X0) * S, (nums[i + 1] - Y0) * S) for i in range(0, len(nums) - 1, 2)]
        if len(pts) > 2: kd.polygon(pts, fill=255)
k = gaussian_filter(np.asarray(kmask, np.float32) / 255, 1.2)[..., None]
grey = out.mean(axis=2, keepdims=True)
outside = (out * 0.65 + grey * 0.35) * 0.74
land = 1 - wa
out = out * k + (outside * land + out * (1 - land)) * (1 - k)
out = out * (1 - wa) + wcol * wa * (k + (1 - k) * 0.8)
out = np.clip(out, 0, 255).astype(np.uint8)
Image.fromarray(out).save(f'{HERE}/terrain.jpg', quality=90)
json.dump({'x0': X0, 'y0': Y0, 'x1': X1, 'y1': Y1, 's': S}, open(f'{HERE}/terrain.json', 'w'))
print('terrain', W, H)
