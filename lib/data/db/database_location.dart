/// Where the database file lives, behind a seam tests can replace.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-disk database file. Does not create it.
///
/// A function rather than a direct `path_provider` call so no test ever needs
/// a plugin binary: the whole data layer is exercised against
/// `NativeDatabase.memory()` or a temp file, with a closure standing in here.
typedef DatabaseLocation = Future<File> Function();

/// The database's file name, fixed so EPIC-13's backup can find it.
const String databaseFileName = 'nearlystop.sqlite';

/// The shipping location: the app's private documents directory.
Future<File> appDocumentsDatabaseFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File(p.join(directory.path, databaseFileName));
}
