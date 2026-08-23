#!/usr/bin/env python3
"""Print the OpenType feature tags each bundled face carries.

`FontFeature.tabularFigures()` on the dose numeral is only true if the SHIPPED
file has a `tnum` record. This reads the GSUB/GPOS FeatureList straight out of
the TTF — no fontTools needed for a tag inventory, and reading the bytes is the
point: the claim has to come from the file, not from memory.
"""
import struct
import sys

FACES = [
    'assets/fonts/Nunito-VariableFont_wght.ttf',
    'assets/fonts/Vazirmatn-VariableFont_wght.ttf',
]


def _u16(data, offset):
    return struct.unpack('>H', data[offset:offset + 2])[0]


def _u32(data, offset):
    return struct.unpack('>I', data[offset:offset + 4])[0]


def feature_tags(path):
    """Every feature tag in the font's GSUB and GPOS tables."""
    data = open(path, 'rb').read()
    tables = {}
    for index in range(_u16(data, 4)):
        record = 12 + index * 16
        tables[data[record:record + 4].decode('latin1')] = _u32(data, record + 8)

    found = {}
    for tag in ('GSUB', 'GPOS'):
        if tag not in tables:
            continue
        table = tables[tag]
        feature_list = table + _u16(data, table + 6)
        found[tag] = sorted({
            data[feature_list + 2 + i * 6:feature_list + 6 + i * 6]
            .decode('latin1')
            for i in range(_u16(data, feature_list))
        })
    return found


def main():
    failures = 0
    for face in FACES:
        print(f'== {face}')
        tags = feature_tags(face)
        for table, features in tags.items():
            print(f'   {table}: {" ".join(features)}')
        has_tnum = any('tnum' in features for features in tags.values())
        print(f'   tnum: {"present" if has_tnum else "ABSENT"}')
        if not has_tnum:
            print(
                '   -> the tabularFigures() declaration is a NO-OP for this '
                'face; test/theme/tabular_figures_test.dart is what proves '
                'the digits are equal-width anyway.'
            )
    return failures


if __name__ == '__main__':
    sys.exit(main())
