# Size and cold-start budgets

The two numbers every future release is compared against. **A regression past
a measured number is a release blocker, not a note.**

Measured 2026-08-24 on commit `39df533`, from a real signed, obfuscated
release build — not an estimate and not a debug build.

## Size — measured

`flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/1.0.0+1`

| | Bytes | |
|---|---:|---|
| **`app-release.aab`** | **61,261,492** (58.4 MiB) | all three ABIs in one bundle |

The bundle is not the download. Play splits by ABI at delivery, so what a
phone actually fetches is one slice:

| ABI | Native libs |
|---|---:|
| `arm64-v8a` | 21 MB |
| `armeabi-v7a` | 19 MB |
| `x86_64` | 22 MB |

Inside `arm64-v8a`, which is what every current device gets:

| Library | Size | |
|---|---:|---|
| `libflutter.so` | 11 MB | the engine. Fixed cost, not ours to move |
| `libapp.so` | 8.4 MB | the AOT snapshot of this app |
| `libsqlite3.so` | 1.5 MB | bundled by `sqlite3_flutter_libs` rather than using the OS copy — deliberate, so the database behaves identically on every Android version |

Assets, all ABIs:

| | Size | |
|---|---:|---|
| `flutter_assets/assets` | 524 KB | the two bundled variable faces, Nunito and Vazirmatn |
| `NOTICES.Z` | 112 KB | the licence text, compressed |
| `shaders` | 44 KB | |

**Subsetting confirmed working**: `MaterialIcons-Regular.otf` was tree-shaken
from 1,645,184 to **7,400 bytes** — a 99.6% reduction — so only the glyphs the
app actually names ship.

The two text faces are **not** subset, and that is correct rather than an
oversight: they are variable fonts carrying the whole `wght` axis, and the app
renders arbitrary user-entered drug names in four languages across two scripts.
A subset built from the ARB would clip the first patient who types a name it
did not anticipate. 524 KB is the price of that and it is worth it.

### iOS

`flutter build ios --release` → `Runner.app` **24.9 MB** before App Store
thinning and re-compression. The store's own delivery makes the installed size
smaller; that number can only be read off App Store Connect after an upload,
which has not happened.

### The budget

| Metric | Today | Blocker above |
|---|---:|---:|
| `.aab` total | 58.4 MiB | 70 MiB |
| arm64 native slice | 21 MB | 26 MB |
| `libapp.so` (arm64) | 8.4 MB | 11 MB |
| Bundled font assets | 524 KB | 800 KB |

`libapp.so` is the one to watch: the engine and sqlite are fixed costs, so
growth there is this app's own code and packages.

## Cold start — NOT MEASURED

**No number is recorded here, because none was taken.**

It needs `flutter run --profile --trace-startup` on a real floor device — a
cheap Android — reading `start_up_info.json` for engine init and first frame.
This environment has no such device, and a number from a simulator or a
development Mac would measure the wrong machine and then be treated as a
baseline forever.

Cold start matters more than usual for this app: it is opened **once a
morning, every morning, for roughly 780 days**, and the only `await` on the
launch path is opening the database. What is verified structurally, in CI:

- `test/app/bootstrap_test.dart` — no `FutureBuilder` anywhere in the launch
  path, and a corrupt database still paints a first frame on defaults rather
  than a black screen.
- `flutter_native_splash` lands on the app's own `bg` in both themes, so there
  is nothing to flash between the splash and the first frame.

**This lands in the release gate.** Until it is run, the app's startup is
*structurally sound and unmeasured*, and no release note may say otherwise.
