// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'step_dao.dart';

// ignore_for_file: type=lint
mixin _$StepDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaperPlansTable get taperPlans => attachedDatabase.taperPlans;
  $StepsTable get steps => attachedDatabase.steps;
  $HoldEventsTable get holdEvents => attachedDatabase.holdEvents;
  StepDaoManager get managers => StepDaoManager(this);
}

class StepDaoManager {
  final _$StepDaoMixin _db;
  StepDaoManager(this._db);
  $$TaperPlansTableTableManager get taperPlans =>
      $$TaperPlansTableTableManager(_db.attachedDatabase, _db.taperPlans);
  $$StepsTableTableManager get steps =>
      $$StepsTableTableManager(_db.attachedDatabase, _db.steps);
  $$HoldEventsTableTableManager get holdEvents =>
      $$HoldEventsTableTableManager(_db.attachedDatabase, _db.holdEvents);
}
