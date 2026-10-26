"""Convert the first version's map data (SVG path strings) into point arrays for Godot.

Usage: python3 tools/export_godot_map.py LEGACY_MAP_JSON game/data/map.json
LEGACY_MAP_JSON is produced from legacy-web/src/data/mapData.ts and legacy-web/src/sim/data.ts
({MAP, MUNICIPALITIES, OTHER_TOWNS}).
"""
import json, re, sys

src = json.load(open(sys.argv[1]))
M = src['MAP']


def parse(d):
    """SVG path with M/L/Z only -> list of polylines [[x,y,x,y,...], ...] (closed ones repeat the first point)."""
    out, cur = [], []
    for cmd, args in re.findall(r'([MLZ])([^MLZ]*)', d):
        nums = [round(float(n), 1) for n in re.findall(r'-?\d+\.?\d*', args)]
        if cmd == 'M':
            if len(cur) >= 4: out.append(cur)
            cur = nums[:]
        elif cmd == 'L':
            cur += nums
        elif cmd == 'Z':
            if len(cur) >= 4: cur += cur[:2]; out.append(cur)
            cur = []
    if len(cur) >= 4: out.append(cur)
    return out


def many(v):
    if isinstance(v, str): return parse(v)
    r = []
    for x in v: r += parse(x['d'] if isinstance(x, dict) else x)
    return r


IDS = {'الرمثا': 'ramtha', 'عجلون': 'ajloun', 'الطفيلة': 'tafila', 'الشوبك': 'shobak', 'وادي موسى': 'wadimusa', 'الأزرق': 'azraq',
       'القطرانة': 'qatrana', 'ذيبان': 'dhiban', 'الرويشد': 'ruwaished', 'المدوّرة': 'mudawwara', 'القدس': 'jerusalem', 'نابلس': 'nablus',
       'الخليل': 'hebron', 'جنين': 'jenin', 'رام الله': 'ramallah', 'أريحا': 'jericho', 'طولكرم': 'tulkarm', 'دمشق': 'damascus',
       'حيفا': 'haifa', 'تل أبيب': 'telaviv', 'غزة': 'gaza', 'بئر السبع': 'beersheba', 'إيلات': 'eilat'}
SIZE = {'amman': 5, 'zarqa': 3, 'irbid': 4, 'salt': 3, 'karak': 3, 'maan': 3, 'aqaba': 2, 'madaba': 2, 'mafraq': 2, 'jerash': 2,
        'jerusalem': 4, 'nablus': 3, 'hebron': 3, 'damascus': 4}
towns = []
proj = lambda lon, lat: [round((lon - M['lon0']) * M['kx'], 1), round((M['lat1'] - lat) * M['ky'], 1)]
for m in src['MUNICIPALITIES']:
    towns.append({'id': m['id'], 'name': m['name'], 'pos': proj(m['lon'], m['lat']), 'size': SIZE.get(m['id'], 2), 'kind': 'jo'})
for o in src['OTHER_TOWNS']:
    i = IDS[o['name']]
    towns.append({'id': i, 'name': o['name'], 'pos': proj(o['lon'], o['lat']), 'size': SIZE.get(i, 1 if not (o.get('westBank') or o.get('neighbour')) else 2),
                  'kind': 'nb' if o.get('neighbour') else 'wb' if o.get('westBank') else 'jo'})

# 1953 road links between towns (travel graph)
ROADS = [('amman', 'salt'), ('amman', 'zarqa'), ('amman', 'madaba'), ('amman', 'jerash'), ('jerash', 'irbid'), ('jerash', 'ajloun'),
         ('irbid', 'ramtha'), ('irbid', 'ajloun'), ('zarqa', 'mafraq'), ('mafraq', 'irbid'), ('mafraq', 'ruwaished'), ('zarqa', 'azraq'),
         ('madaba', 'dhiban'), ('dhiban', 'karak'), ('karak', 'tafila'), ('tafila', 'shobak'), ('shobak', 'wadimusa'), ('wadimusa', 'maan'),
         ('amman', 'qatrana'), ('qatrana', 'maan'), ('qatrana', 'karak'), ('maan', 'mudawwara'), ('maan', 'aqaba'), ('salt', 'jericho'),
         ('jericho', 'jerusalem'), ('jerusalem', 'ramallah'), ('ramallah', 'nablus'), ('nablus', 'jenin'), ('nablus', 'tulkarm'),
         ('jerusalem', 'hebron'), ('ramtha', 'damascus')]

out = {
    'kx': M['kx'], 'ky': M['ky'], 'lon0': M['lon0'], 'lat1': M['lat1'], 'km_per_unit': 0.675,
    'east_bank': parse(M['eastBank']), 'west_bank': parse(M['westBank']), 'border': parse(M['kingdomBorder']),
    'districts': parse(M['districtLines']), 'rivers': many(M['rivers']), 'roads': many(M['roads']), 'rail': many(M['rail']),
    'towns': towns, 'links': ROADS,
}
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False, separators=(',', ':'))
print('towns', len(towns), 'roads', len(out['roads']), 'rail', len(out['rail']))
