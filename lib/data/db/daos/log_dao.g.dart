// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_dao.dart';

// ignore_for_file: type=lint
mixin _$LogDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaperPlansTable get taperPlans => attachedDatabase.taperPlans;
  $DoseLogsTable get doseLogs => attachedDatabase.doseLogs;
  LogDaoManager get managers => LogDaoManager(this);
}

class LogDaoManager {
  final _$LogDaoMixin _db;
  LogDaoManager(this._db);
  $$TaperPlansTableTableManager get taperPlans =>
      $$TaperPlansTableTableManager(_db.attachedDatabase, _db.taperPlans);
  $$DoseLogsTableTableManager get doseLogs =>
      $$DoseLogsTableTableManager(_db.attachedDatabase, _db.doseLogs);
}
