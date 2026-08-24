/// The rows the CSV golden vector is written from.
///
/// A separate file so the generator and the test cannot drift: a golden
/// regenerated from different data than the test asserts over is a green test
/// over a file nobody checked.
library;

import 'package:nearlystop/features/export/data/dose_history_csv.dart';

/// Every awkward cell, in one small table.
const List<DoseHistoryRow> csvGoldenRows = <DoseHistoryRow>[
  DoseHistoryRow(
    date: '2026-04-01',
    weekday: 'Wednesday',
    step: '1',
    block: '1',
    plannedMg: '10.25',
    actualMg: '10.25',
    taken: 'Taken',
    tablets: '2 × 5mg, 1 × 0.25mg',
    note: 'felt fine, "no aches"\nslept well',
    event: '',
  ),
  DoseHistoryRow(
    date: '2026-04-02',
    weekday: 'Thursday',
    step: '1',
    block: '1',
    plannedMg: '9',
    actualMg: '',
    taken: '',
    tablets: '1 × 5mg, 4 × 1mg',
    // A live formula in Excel, and a real sentence in English.
    note: '=cmd()|"/c calc"!A1',
    event: 'Flare',
  ),
  DoseHistoryRow(
    date: '2026-04-03',
    weekday: 'Friday',
    step: '1',
    block: '2',
    plannedMg: '9',
    actualMg: '9',
    taken: 'Taken',
    tablets: '1 × 5mg, 4 × 1mg',
    // Perso-Arabic with an explicit right-to-left mark in it.
    note: '‏درد کمتر شد ‎(10mg)‏',
    event: 'Hold',
  ),
  DoseHistoryRow(
    date: '2026-04-04',
    weekday: 'Saturday',
    step: '1',
    block: '2',
    plannedMg: '9',
    actualMg: '9',
    taken: 'Taken',
    tablets: '1 × 5mg, 4 × 1mg',
    // A note that is absent, which is not the same fact as an empty one.
    note: null,
    event: '',
  ),
  DoseHistoryRow(
    date: '2026-04-05',
    weekday: 'Sunday',
    step: '1',
    block: '3',
    plannedMg: '9',
    actualMg: '9',
    taken: 'Taken',
    tablets: '1 × 5mg, 4 × 1mg',
    note: '-2 today 🌅',
    event: '',
  ),
];
