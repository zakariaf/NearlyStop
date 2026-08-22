// Pure `package:test`. DayState is the ROW LOG state, and it has exactly four
// members: a dose change is not a fifth, because a day is routinely both
// `today` and a new-dose day (CONTRACTS.md §1).
import 'package:nearlystop/core/day_state.dart';
import 'package:test/test.dart';

void main() {
  test('has exactly four members', () {
    expect(DayState.values, hasLength(4));
  });

  test('an exhaustive switch needs no default arm', () {
    // No `default:` and no `case _:`. Adding a fifth member stops this file
    // compiling, which is the whole point of the type.
    String tag(DayState state) => switch (state) {
      DayState.taken => 'taken',
      DayState.missed => 'missed',
      DayState.today => 'today',
      DayState.upcoming => 'upcoming',
    };

    expect(DayState.values.map(tag).toList(), <String>[
      'taken',
      'missed',
      'today',
      'upcoming',
    ]);
  });
}
