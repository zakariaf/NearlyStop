// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_dao.dart';

// ignore_for_file: type=lint
mixin _$PlanDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaperPlansTable get taperPlans => attachedDatabase.taperPlans;
  $FlareEventsTable get flareEvents => attachedDatabase.flareEvents;
  PlanDaoManager get managers => PlanDaoManager(this);
}

class PlanDaoManager {
  final _$PlanDaoMixin _db;
  PlanDaoManager(this._db);
  $$TaperPlansTableTableManager get taperPlans =>
      $$TaperPlansTableTableManager(_db.attachedDatabase, _db.taperPlans);
  $$FlareEventsTableTableManager get flareEvents =>
      $$FlareEventsTableTableManager(_db.attachedDatabase, _db.flareEvents);
}
