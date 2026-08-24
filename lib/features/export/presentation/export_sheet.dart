/// Progress → Export: the sheet that hands a file to a doctor.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/backup/presentation/backup_actions.dart';
import 'package:nearlystop/features/export/application/dose_history_document.dart';
import 'package:nearlystop/features/export/data/dose_history_csv.dart';
import 'package:nearlystop/features/export/data/dose_history_pdf.dart';
import 'package:nearlystop/features/export/data/pdf_fonts.dart';
import 'package:nearlystop/features/export/domain/export_failure.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// The handout, built from whatever is on the phone right now.
///
/// Null when there is no plan or no day has elapsed. See
/// [buildDoseHistoryDocument] for why that is a null rather than an empty
/// document.
///
/// **It READS the snapshot rather than watching one.** Reading
/// `taperSnapshotProvider.value` returns whatever that stream has cached, and
/// in a container nothing else is listening to that is nothing at all — so the
/// export worked only because the Progress screen behind the sheet happened to
/// be subscribed. The same coupling made the first seconds after a restore,
/// when the connection has just been replaced, export an empty file.
final Provider<Future<DoseHistoryDocument?> Function()> doseHistoryProvider =
    Provider<Future<DoseHistoryDocument?> Function()>(
      (ref) => () async {
        final snapshot = await ref.read(taperRepositoryProvider).readSnapshot();
        if (snapshot is! Ok<TaperSnapshot, StorageFailure>) return null;
        final schedule = scheduleFromSnapshot(snapshot);
        if (schedule is! Ok<List<DayPlan>, Failure>) return null;
        final today = ref.read(todayDateProvider);
        return buildDoseHistoryDocument(
          snapshot: snapshot.value,
          schedule: schedule.value,
          today: today,
          exportedAt: today,
          l10n: ref.read(appLocalizationsProvider),
          locale: ref.read(resolvedLocaleProvider),
        );
      },
    );

/// Loads the two bundled faces a handout embeds.
final Provider<Future<PdfFonts> Function()> pdfFontsProvider =
    Provider<Future<PdfFonts> Function()>((ref) => loadBundledPdfFonts);

/// Renders the history as a PDF and returns the file.
final Provider<Future<Result<File, Failure>> Function()> pdfExportProvider =
    Provider<Future<Result<File, Failure>> Function()>(
      (ref) => () async {
        final document = await ref.read(doseHistoryProvider)();
        if (document == null) {
          return const Err<File, Failure>(NothingToExport());
        }
        try {
          final fonts = await ref.read(pdfFontsProvider)();
          final bytes = await buildDoseHistoryPdf(
            copy: document.copy,
            rows: document.pdfRows,
            latinFont: fonts.latin,
            persoFont: fonts.perso,
            isRightToLeft: document.isRightToLeft,
          ).save();
          return Ok<File, Failure>(
            await _write(ref, '${document.fileStem}.pdf', (file) async {
              await file.writeAsBytes(bytes, flush: true);
            }),
          );
        } on Object catch (error) {
          return Err<File, Failure>(ExportWriteFailed('$error'));
        }
      },
    );

/// Renders the history as a spreadsheet and returns the file.
final Provider<Future<Result<File, Failure>> Function()> csvExportProvider =
    Provider<Future<Result<File, Failure>> Function()>(
      (ref) => () async {
        final document = await ref.read(doseHistoryProvider)();
        if (document == null) {
          return const Err<File, Failure>(NothingToExport());
        }
        try {
          final text = writeDoseHistoryCsv(document.rows);
          return Ok<File, Failure>(
            await _write(ref, '${document.fileStem}.csv', (file) async {
              // The BOM is already the first character of `text` — see
              // `writeDoseHistoryCsv`. Writing it as UTF-8 keeps it there.
              await file.writeAsString(text, flush: true);
            }),
          );
        } on Object catch (error) {
          return Err<File, Failure>(ExportWriteFailed('$error'));
        }
      },
    );

/// Writes [name] into the working directory, replacing any earlier copy.
Future<File> _write(
  Ref ref,
  String name,
  Future<void> Function(File file) fill,
) async {
  final directory = await ref.read(workingDirectoryProvider)();
  final file = File('${directory.path}/$name');
  // Deleted first, not appended to. Exporting twice in one day must not
  // produce a file with the history in it twice.
  if (file.existsSync()) await file.delete();
  await fill(file);
  return file;
}

/// Offers the two formats, and shares whichever the reader picks.
Future<void> showExportSheet(BuildContext context) => showDaybreakSheet<void>(
  context: context,
  builder: (context) => const ExportSheet(),
);

/// The sheet itself.
class ExportSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ExportSheet({super.key});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

/// Which format is rendering, if any.
enum _Rendering {
  /// Neither.
  none,

  /// The PDF.
  pdf,

  /// The spreadsheet.
  csv,
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  _Rendering _rendering = _Rendering.none;
  String? _notice;

  final GlobalKey _pdfKey = GlobalKey();
  final GlobalKey _csvKey = GlobalKey();

  Future<void> _run(
    _Rendering which,
    GlobalKey anchorKey,
    Provider<Future<Result<File, Failure>> Function()> renderer,
    String mimeType,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Read BEFORE the await: by the time the file is written the option may
    // have been rebuilt, and `findRenderObject` on a dead element throws.
    final anchor = originRectOf(anchorKey.currentContext ?? context);
    setState(() {
      _rendering = which;
      _notice = null;
    });

    final rendered = await ref.read(renderer)();
    if (!mounted) return;
    if (rendered case Err<File, Failure>(:final failure)) {
      setState(() {
        _rendering = _Rendering.none;
        // The typed failure's own message, never `e.toString()`. "Nothing yet"
        // and "it broke" are different sentences because they are different
        // facts, and only one of them is worth retrying.
        _notice = failure is NothingToExport
            ? l10n.exportNothingYet
            : l10n.exportFailed;
      });
      return;
    }

    final shared = await shareExportedFile(
      ref,
      file: (rendered as Ok<File, Failure>).value,
      mimeType: mimeType,
      subject: l10n.exportSubject,
      originRect: anchor,
    );
    if (!mounted) return;
    setState(() {
      _rendering = _Rendering.none;
      _notice = shared is Ok ? null : l10n.exportFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final idle = _rendering == _Rendering.none;

    return DaybreakSheetShell(
      routeLabel: l10n.exportSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.exportSheetTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: shapes.s4),
          ExportOption(
            key: _pdfKey,
            label: l10n.exportPdfLabel,
            audience: l10n.exportPdfAudience,
            glyph: Icons.picture_as_pdf_outlined,
            busy: _rendering == _Rendering.pdf,
            onPressed: idle
                ? () => _run(
                    _Rendering.pdf,
                    _pdfKey,
                    pdfExportProvider,
                    'application/pdf',
                  )
                : null,
          ),
          SizedBox(height: shapes.s3),
          ExportOption(
            key: _csvKey,
            label: l10n.exportCsvLabel,
            audience: l10n.exportCsvAudience,
            glyph: Icons.table_chart_outlined,
            busy: _rendering == _Rendering.csv,
            onPressed: idle
                ? () => _run(
                    _Rendering.csv,
                    _csvKey,
                    csvExportProvider,
                    'text/csv',
                  )
                : null,
          ),
          SizedBox(height: shapes.s4),
          // Said where the reader can see it, not only in a policy document:
          // SPEC §5.3's honesty rule, on the surface that hands the file to
          // somebody else.
          Text(
            l10n.exportNotEncrypted,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
          if (_notice case final notice?) ...<Widget>[
            SizedBox(height: shapes.s3),
            Text(
              notice,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

/// One format, with the line that says who it is for.
class ExportOption extends StatelessWidget {
  /// Creates an option.
  const ExportOption({
    required this.label,
    required this.audience,
    required this.glyph,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  /// The format's name.
  final String label;

  /// Who this format is for. **Not decoration:** the two differ only by their
  /// reader, and an option list that does not say so makes somebody guess.
  final String audience;

  /// A leading mark. Decoration — the label already says it.
  final IconData glyph;

  /// Null disables the option.
  final VoidCallback? onPressed;

  /// Whether this option's own render is running.
  ///
  /// Progress belongs on the control that started it: a modal scrim over a
  /// taper app says "you may not look at today's dose while this writes a
  /// file".
  final bool busy;

  /// The diameter of the inline spinner, at 1.0 text scale.
  static const double spinnerSize = 20;

  /// The leading glyph's size, at 1.0 text scale.
  static const double glyphSize = 24;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final enabled = onPressed != null && !busy;

    return DaybreakTappable(
      // Both channels, always: a spinner is invisible to a screen reader and
      // `Semantics(enabled:)` is invisible to a sighted reader.
      semanticsLabel: busyAwareSemantics(
        '$label, $audience',
        busy: busy,
        enabled: enabled,
        l10n: l10n,
      ),
      onPressed: onPressed,
      child: Container(
        padding: EdgeInsetsDirectional.all(shapes.s4),
        decoration: BoxDecoration(
          color: enabled ? colors.surfaceRaised : colors.surfaceSunken,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
          border: Border.all(
            color: enabled ? colors.border : colors.surfaceSunken,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (busy)
              InlineSpinner(diameter: spinnerSize, color: colors.inkMuted)
            else
              ExcludeSemantics(
                child: Icon(
                  glyph,
                  size: MediaQuery.textScalerOf(context).scale(glyphSize),
                  color: enabled ? colors.ink : colors.inkFaint,
                ),
              ),
            SizedBox(width: shapes.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: text.titleMedium
                        ?.atWeight(FontWeight.w700)
                        .copyWith(
                          color: enabled ? colors.ink : colors.inkFaint,
                        ),
                  ),
                  SizedBox(height: shapes.s1),
                  Text(
                    audience,
                    style: text.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
