// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'v2_database.dart';

// ignore_for_file: type=lint
class $TaperPlansTable extends TaperPlans
    with TableInfo<$TaperPlansTable, TaperPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaperPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _drugNameMeta = const VerificationMeta(
    'drugName',
  );
  @override
  late final GeneratedColumn<String> drugName = GeneratedColumn<String>(
    'drug_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Prednisolone'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> startDate =
      GeneratedColumn<String>(
        'start_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($TaperPlansTable.$converterstartDate);
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> startingDose =
      GeneratedColumn<int>(
        'starting_dose',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($TaperPlansTable.$converterstartingDose);
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> targetDose =
      GeneratedColumn<int>(
        'target_dose',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($TaperPlansTable.$convertertargetDose);
  @override
  late final GeneratedColumnWithTypeConverter<List<Milligrams>, String>
  tabletStrengths = GeneratedColumn<String>(
    'tablet_strengths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<Milligrams>>($TaperPlansTable.$convertertabletStrengths);
  static const VerificationMeta _allowHalvesMeta = const VerificationMeta(
    'allowHalves',
  );
  @override
  late final GeneratedColumn<bool> allowHalves = GeneratedColumn<bool>(
    'allow_halves',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_halves" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaperMethod, String> method =
      GeneratedColumn<String>(
        'method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaperMethod>($TaperPlansTable.$convertermethod);
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
    'percentage',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams?, int> fixedStep =
      GeneratedColumn<int>(
        'fixed_step',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Milligrams?>($TaperPlansTable.$converterfixedStepn);
  static const VerificationMeta _holdPeriodDaysMeta = const VerificationMeta(
    'holdPeriodDays',
  );
  @override
  late final GeneratedColumn<int> holdPeriodDays = GeneratedColumn<int>(
    'hold_period_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(52),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TaperPlansTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    drugName,
    startDate,
    startingDose,
    targetDose,
    tabletStrengths,
    allowHalves,
    method,
    percentage,
    fixedStep,
    holdPeriodDays,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'taper_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaperPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('drug_name')) {
      context.handle(
        _drugNameMeta,
        drugName.isAcceptableOrUnknown(data['drug_name']!, _drugNameMeta),
      );
    }
    if (data.containsKey('allow_halves')) {
      context.handle(
        _allowHalvesMeta,
        allowHalves.isAcceptableOrUnknown(
          data['allow_halves']!,
          _allowHalvesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allowHalvesMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    }
    if (data.containsKey('hold_period_days')) {
      context.handle(
        _holdPeriodDaysMeta,
        holdPeriodDays.isAcceptableOrUnknown(
          data['hold_period_days']!,
          _holdPeriodDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaperPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaperPlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      drugName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drug_name'],
      )!,
      startDate: $TaperPlansTable.$converterstartDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_date'],
        )!,
      ),
      startingDose: $TaperPlansTable.$converterstartingDose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}starting_dose'],
        )!,
      ),
      targetDose: $TaperPlansTable.$convertertargetDose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}target_dose'],
        )!,
      ),
      tabletStrengths: $TaperPlansTable.$convertertabletStrengths.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tablet_strengths'],
        )!,
      ),
      allowHalves: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_halves'],
      )!,
      method: $TaperPlansTable.$convertermethod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}method'],
        )!,
      ),
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percentage'],
      ),
      fixedStep: $TaperPlansTable.$converterfixedStepn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}fixed_step'],
        ),
      ),
      holdPeriodDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hold_period_days'],
      )!,
      createdAt: $TaperPlansTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $TaperPlansTable createAlias(String alias) {
    return $TaperPlansTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterstartDate =
      const LocalDateConverter();
  static TypeConverter<Milligrams, int> $converterstartingDose =
      const MilligramsConverter();
  static TypeConverter<Milligrams, int> $convertertargetDose =
      const MilligramsConverter();
  static TypeConverter<List<Milligrams>, String> $convertertabletStrengths =
      const StrengthListConverter();
  static TypeConverter<TaperMethod, String> $convertermethod =
      const TaperMethodConverter();
  static TypeConverter<Milligrams, int> $converterfixedStep =
      const MilligramsConverter();
  static TypeConverter<Milligrams?, int?> $converterfixedStepn =
      NullAwareTypeConverter.wrap($converterfixedStep);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const UtcInstantConverter();
}

class TaperPlanRow extends DataClass implements Insertable<TaperPlanRow> {
  /// Surrogate key. Local only — never exported.
  final int id;

  /// Stable identity across an export/import round trip.
  final String uid;

  /// Free text, defaulting to Prednisolone. Never looked up in a drug database.
  final String drugName;

  /// The first day of the plan.
  final LocalDate startDate;

  /// The dose the plan starts from, in hundredths of a milligram.
  final Milligrams startingDose;

  /// The dose the plan aims at, usually zero.
  final Milligrams targetDose;

  /// The strengths the patient holds, descending, deduplicated.
  final List<Milligrams> tabletStrengths;

  /// Whether the patient said they can split a tablet.
  final bool allowHalves;

  /// Which arithmetic the plan uses.
  final TaperMethod method;

  /// Percent per step, for [TaperMethod.percentage].
  ///
  /// The one genuine REAL in the schema, and it is not a dose.
  final double? percentage;

  /// A fixed step size, for [TaperMethod.fixedMg]. A dose, so an INTEGER.
  final Milligrams? fixedStep;

  /// Days a non-DSNS step holds the new dose before the next may begin.
  ///
  /// 52 for DSNS, where it is the pattern's own length and cannot be anything
  /// else. It is a COLUMN because `nominalStepLength` reads it for the other
  /// two methods: without one a `percentage` plan that runs 14 days reports 52
  /// on every read, and "Start next step" stays disabled for 38 days after the
  /// schedule has already reached steady state.
  final int holdPeriodDays;

  /// When the plan was created, as UTC epoch milliseconds.
  final DateTime createdAt;
  const TaperPlanRow({
    required this.id,
    required this.uid,
    required this.drugName,
    required this.startDate,
    required this.startingDose,
    required this.targetDose,
    required this.tabletStrengths,
    required this.allowHalves,
    required this.method,
    this.percentage,
    this.fixedStep,
    required this.holdPeriodDays,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['drug_name'] = Variable<String>(drugName);
    {
      map['start_date'] = Variable<String>(
        $TaperPlansTable.$converterstartDate.toSql(startDate),
      );
    }
    {
      map['starting_dose'] = Variable<int>(
        $TaperPlansTable.$converterstartingDose.toSql(startingDose),
      );
    }
    {
      map['target_dose'] = Variable<int>(
        $TaperPlansTable.$convertertargetDose.toSql(targetDose),
      );
    }
    {
      map['tablet_strengths'] = Variable<String>(
        $TaperPlansTable.$convertertabletStrengths.toSql(tabletStrengths),
      );
    }
    map['allow_halves'] = Variable<bool>(allowHalves);
    {
      map['method'] = Variable<String>(
        $TaperPlansTable.$convertermethod.toSql(method),
      );
    }
    if (!nullToAbsent || percentage != null) {
      map['percentage'] = Variable<double>(percentage);
    }
    if (!nullToAbsent || fixedStep != null) {
      map['fixed_step'] = Variable<int>(
        $TaperPlansTable.$converterfixedStepn.toSql(fixedStep),
      );
    }
    map['hold_period_days'] = Variable<int>(holdPeriodDays);
    {
      map['created_at'] = Variable<int>(
        $TaperPlansTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  TaperPlansCompanion toCompanion(bool nullToAbsent) {
    return TaperPlansCompanion(
      id: Value(id),
      uid: Value(uid),
      drugName: Value(drugName),
      startDate: Value(startDate),
      startingDose: Value(startingDose),
      targetDose: Value(targetDose),
      tabletStrengths: Value(tabletStrengths),
      allowHalves: Value(allowHalves),
      method: Value(method),
      percentage: percentage == null && nullToAbsent
          ? const Value.absent()
          : Value(percentage),
      fixedStep: fixedStep == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedStep),
      holdPeriodDays: Value(holdPeriodDays),
      createdAt: Value(createdAt),
    );
  }

  factory TaperPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaperPlanRow(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      drugName: serializer.fromJson<String>(json['drugName']),
      startDate: serializer.fromJson<LocalDate>(json['startDate']),
      startingDose: serializer.fromJson<Milligrams>(json['startingDose']),
      targetDose: serializer.fromJson<Milligrams>(json['targetDose']),
      tabletStrengths: serializer.fromJson<List<Milligrams>>(
        json['tabletStrengths'],
      ),
      allowHalves: serializer.fromJson<bool>(json['allowHalves']),
      method: serializer.fromJson<TaperMethod>(json['method']),
      percentage: serializer.fromJson<double?>(json['percentage']),
      fixedStep: serializer.fromJson<Milligrams?>(json['fixedStep']),
      holdPeriodDays: serializer.fromJson<int>(json['holdPeriodDays']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'drugName': serializer.toJson<String>(drugName),
      'startDate': serializer.toJson<LocalDate>(startDate),
      'startingDose': serializer.toJson<Milligrams>(startingDose),
      'targetDose': serializer.toJson<Milligrams>(targetDose),
      'tabletStrengths': serializer.toJson<List<Milligrams>>(tabletStrengths),
      'allowHalves': serializer.toJson<bool>(allowHalves),
      'method': serializer.toJson<TaperMethod>(method),
      'percentage': serializer.toJson<double?>(percentage),
      'fixedStep': serializer.toJson<Milligrams?>(fixedStep),
      'holdPeriodDays': serializer.toJson<int>(holdPeriodDays),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TaperPlanRow copyWith({
    int? id,
    String? uid,
    String? drugName,
    LocalDate? startDate,
    Milligrams? startingDose,
    Milligrams? targetDose,
    List<Milligrams>? tabletStrengths,
    bool? allowHalves,
    TaperMethod? method,
    Value<double?> percentage = const Value.absent(),
    Value<Milligrams?> fixedStep = const Value.absent(),
    int? holdPeriodDays,
    DateTime? createdAt,
  }) => TaperPlanRow(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    drugName: drugName ?? this.drugName,
    startDate: startDate ?? this.startDate,
    startingDose: startingDose ?? this.startingDose,
    targetDose: targetDose ?? this.targetDose,
    tabletStrengths: tabletStrengths ?? this.tabletStrengths,
    allowHalves: allowHalves ?? this.allowHalves,
    method: method ?? this.method,
    percentage: percentage.present ? percentage.value : this.percentage,
    fixedStep: fixedStep.present ? fixedStep.value : this.fixedStep,
    holdPeriodDays: holdPeriodDays ?? this.holdPeriodDays,
    createdAt: createdAt ?? this.createdAt,
  );
  TaperPlanRow copyWithCompanion(TaperPlansCompanion data) {
    return TaperPlanRow(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      drugName: data.drugName.present ? data.drugName.value : this.drugName,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      startingDose: data.startingDose.present
          ? data.startingDose.value
          : this.startingDose,
      targetDose: data.targetDose.present
          ? data.targetDose.value
          : this.targetDose,
      tabletStrengths: data.tabletStrengths.present
          ? data.tabletStrengths.value
          : this.tabletStrengths,
      allowHalves: data.allowHalves.present
          ? data.allowHalves.value
          : this.allowHalves,
      method: data.method.present ? data.method.value : this.method,
      percentage: data.percentage.present
          ? data.percentage.value
          : this.percentage,
      fixedStep: data.fixedStep.present ? data.fixedStep.value : this.fixedStep,
      holdPeriodDays: data.holdPeriodDays.present
          ? data.holdPeriodDays.value
          : this.holdPeriodDays,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaperPlanRow(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('drugName: $drugName, ')
          ..write('startDate: $startDate, ')
          ..write('startingDose: $startingDose, ')
          ..write('targetDose: $targetDose, ')
          ..write('tabletStrengths: $tabletStrengths, ')
          ..write('allowHalves: $allowHalves, ')
          ..write('method: $method, ')
          ..write('percentage: $percentage, ')
          ..write('fixedStep: $fixedStep, ')
          ..write('holdPeriodDays: $holdPeriodDays, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    drugName,
    startDate,
    startingDose,
    targetDose,
    tabletStrengths,
    allowHalves,
    method,
    percentage,
    fixedStep,
    holdPeriodDays,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaperPlanRow &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.drugName == this.drugName &&
          other.startDate == this.startDate &&
          other.startingDose == this.startingDose &&
          other.targetDose == this.targetDose &&
          other.tabletStrengths == this.tabletStrengths &&
          other.allowHalves == this.allowHalves &&
          other.method == this.method &&
          other.percentage == this.percentage &&
          other.fixedStep == this.fixedStep &&
          other.holdPeriodDays == this.holdPeriodDays &&
          other.createdAt == this.createdAt);
}

class TaperPlansCompanion extends UpdateCompanion<TaperPlanRow> {
  final Value<int> id;
  final Value<String> uid;
  final Value<String> drugName;
  final Value<LocalDate> startDate;
  final Value<Milligrams> startingDose;
  final Value<Milligrams> targetDose;
  final Value<List<Milligrams>> tabletStrengths;
  final Value<bool> allowHalves;
  final Value<TaperMethod> method;
  final Value<double?> percentage;
  final Value<Milligrams?> fixedStep;
  final Value<int> holdPeriodDays;
  final Value<DateTime> createdAt;
  const TaperPlansCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.drugName = const Value.absent(),
    this.startDate = const Value.absent(),
    this.startingDose = const Value.absent(),
    this.targetDose = const Value.absent(),
    this.tabletStrengths = const Value.absent(),
    this.allowHalves = const Value.absent(),
    this.method = const Value.absent(),
    this.percentage = const Value.absent(),
    this.fixedStep = const Value.absent(),
    this.holdPeriodDays = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TaperPlansCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    this.drugName = const Value.absent(),
    required LocalDate startDate,
    required Milligrams startingDose,
    required Milligrams targetDose,
    required List<Milligrams> tabletStrengths,
    required bool allowHalves,
    required TaperMethod method,
    this.percentage = const Value.absent(),
    this.fixedStep = const Value.absent(),
    this.holdPeriodDays = const Value.absent(),
    required DateTime createdAt,
  }) : uid = Value(uid),
       startDate = Value(startDate),
       startingDose = Value(startingDose),
       targetDose = Value(targetDose),
       tabletStrengths = Value(tabletStrengths),
       allowHalves = Value(allowHalves),
       method = Value(method),
       createdAt = Value(createdAt);
  static Insertable<TaperPlanRow> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<String>? drugName,
    Expression<String>? startDate,
    Expression<int>? startingDose,
    Expression<int>? targetDose,
    Expression<String>? tabletStrengths,
    Expression<bool>? allowHalves,
    Expression<String>? method,
    Expression<double>? percentage,
    Expression<int>? fixedStep,
    Expression<int>? holdPeriodDays,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (drugName != null) 'drug_name': drugName,
      if (startDate != null) 'start_date': startDate,
      if (startingDose != null) 'starting_dose': startingDose,
      if (targetDose != null) 'target_dose': targetDose,
      if (tabletStrengths != null) 'tablet_strengths': tabletStrengths,
      if (allowHalves != null) 'allow_halves': allowHalves,
      if (method != null) 'method': method,
      if (percentage != null) 'percentage': percentage,
      if (fixedStep != null) 'fixed_step': fixedStep,
      if (holdPeriodDays != null) 'hold_period_days': holdPeriodDays,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TaperPlansCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<String>? drugName,
    Value<LocalDate>? startDate,
    Value<Milligrams>? startingDose,
    Value<Milligrams>? targetDose,
    Value<List<Milligrams>>? tabletStrengths,
    Value<bool>? allowHalves,
    Value<TaperMethod>? method,
    Value<double?>? percentage,
    Value<Milligrams?>? fixedStep,
    Value<int>? holdPeriodDays,
    Value<DateTime>? createdAt,
  }) {
    return TaperPlansCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      drugName: drugName ?? this.drugName,
      startDate: startDate ?? this.startDate,
      startingDose: startingDose ?? this.startingDose,
      targetDose: targetDose ?? this.targetDose,
      tabletStrengths: tabletStrengths ?? this.tabletStrengths,
      allowHalves: allowHalves ?? this.allowHalves,
      method: method ?? this.method,
      percentage: percentage ?? this.percentage,
      fixedStep: fixedStep ?? this.fixedStep,
      holdPeriodDays: holdPeriodDays ?? this.holdPeriodDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (drugName.present) {
      map['drug_name'] = Variable<String>(drugName.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(
        $TaperPlansTable.$converterstartDate.toSql(startDate.value),
      );
    }
    if (startingDose.present) {
      map['starting_dose'] = Variable<int>(
        $TaperPlansTable.$converterstartingDose.toSql(startingDose.value),
      );
    }
    if (targetDose.present) {
      map['target_dose'] = Variable<int>(
        $TaperPlansTable.$convertertargetDose.toSql(targetDose.value),
      );
    }
    if (tabletStrengths.present) {
      map['tablet_strengths'] = Variable<String>(
        $TaperPlansTable.$convertertabletStrengths.toSql(tabletStrengths.value),
      );
    }
    if (allowHalves.present) {
      map['allow_halves'] = Variable<bool>(allowHalves.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(
        $TaperPlansTable.$convertermethod.toSql(method.value),
      );
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (fixedStep.present) {
      map['fixed_step'] = Variable<int>(
        $TaperPlansTable.$converterfixedStepn.toSql(fixedStep.value),
      );
    }
    if (holdPeriodDays.present) {
      map['hold_period_days'] = Variable<int>(holdPeriodDays.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $TaperPlansTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaperPlansCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('drugName: $drugName, ')
          ..write('startDate: $startDate, ')
          ..write('startingDose: $startingDose, ')
          ..write('targetDose: $targetDose, ')
          ..write('tabletStrengths: $tabletStrengths, ')
          ..write('allowHalves: $allowHalves, ')
          ..write('method: $method, ')
          ..write('percentage: $percentage, ')
          ..write('fixedStep: $fixedStep, ')
          ..write('holdPeriodDays: $holdPeriodDays, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StepsTable extends Steps with TableInfo<$StepsTable, StepRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepIndexMeta = const VerificationMeta(
    'stepIndex',
  );
  @override
  late final GeneratedColumn<int> stepIndex = GeneratedColumn<int>(
    'step_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> fromDose =
      GeneratedColumn<int>(
        'from_dose',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($StepsTable.$converterfromDose);
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> toDose =
      GeneratedColumn<int>(
        'to_dose',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($StepsTable.$convertertoDose);
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> startDate =
      GeneratedColumn<String>(
        'start_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($StepsTable.$converterstartDate);
  @override
  late final GeneratedColumnWithTypeConverter<StepStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<StepStatus>($StepsTable.$converterstatus);
  static const VerificationMeta _patternVersionMeta = const VerificationMeta(
    'patternVersion',
  );
  @override
  late final GeneratedColumn<int> patternVersion = GeneratedColumn<int>(
    'pattern_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    planId,
    stepIndex,
    fromDose,
    toDose,
    startDate,
    status,
    patternVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<StepRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('step_index')) {
      context.handle(
        _stepIndexMeta,
        stepIndex.isAcceptableOrUnknown(data['step_index']!, _stepIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_stepIndexMeta);
    }
    if (data.containsKey('pattern_version')) {
      context.handle(
        _patternVersionMeta,
        patternVersion.isAcceptableOrUnknown(
          data['pattern_version']!,
          _patternVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_patternVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StepRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StepRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_id'],
      )!,
      stepIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step_index'],
      )!,
      fromDose: $StepsTable.$converterfromDose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}from_dose'],
        )!,
      ),
      toDose: $StepsTable.$convertertoDose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}to_dose'],
        )!,
      ),
      startDate: $StepsTable.$converterstartDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_date'],
        )!,
      ),
      status: $StepsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      patternVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pattern_version'],
      )!,
    );
  }

  @override
  $StepsTable createAlias(String alias) {
    return $StepsTable(attachedDatabase, alias);
  }

  static TypeConverter<Milligrams, int> $converterfromDose =
      const MilligramsConverter();
  static TypeConverter<Milligrams, int> $convertertoDose =
      const MilligramsConverter();
  static TypeConverter<LocalDate, String> $converterstartDate =
      const LocalDateConverter();
  static TypeConverter<StepStatus, String> $converterstatus =
      const StepStatusConverter();
}

class StepRow extends DataClass implements Insertable<StepRow> {
  /// Surrogate key.
  final int id;

  /// Stable identity across an export/import round trip.
  final String uid;

  /// Owning plan; deleting the plan deletes its steps.
  final int planId;

  /// 0-based position in the plan.
  ///
  /// **`stepIndex`, not `index`.** `INDEX` is a reserved SQLite keyword, and
  /// the composite unique below is a hand-written constraint drift passes
  /// through
  /// verbatim — `UNIQUE(plan_id, index)` is a syntax error at table creation.
  final int stepIndex;

  /// The dose this step steps down from.
  final Milligrams fromDose;

  /// The dose this step steps down to.
  final Milligrams toDose;

  /// The first day of the step.
  final LocalDate startDate;

  /// The stored status. A record of events, never a derived cache.
  final StepStatus status;

  /// The `DsnsPattern` version frozen when this step was created.
  final int patternVersion;
  const StepRow({
    required this.id,
    required this.uid,
    required this.planId,
    required this.stepIndex,
    required this.fromDose,
    required this.toDose,
    required this.startDate,
    required this.status,
    required this.patternVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['plan_id'] = Variable<int>(planId);
    map['step_index'] = Variable<int>(stepIndex);
    {
      map['from_dose'] = Variable<int>(
        $StepsTable.$converterfromDose.toSql(fromDose),
      );
    }
    {
      map['to_dose'] = Variable<int>(
        $StepsTable.$convertertoDose.toSql(toDose),
      );
    }
    {
      map['start_date'] = Variable<String>(
        $StepsTable.$converterstartDate.toSql(startDate),
      );
    }
    {
      map['status'] = Variable<String>(
        $StepsTable.$converterstatus.toSql(status),
      );
    }
    map['pattern_version'] = Variable<int>(patternVersion);
    return map;
  }

  StepsCompanion toCompanion(bool nullToAbsent) {
    return StepsCompanion(
      id: Value(id),
      uid: Value(uid),
      planId: Value(planId),
      stepIndex: Value(stepIndex),
      fromDose: Value(fromDose),
      toDose: Value(toDose),
      startDate: Value(startDate),
      status: Value(status),
      patternVersion: Value(patternVersion),
    );
  }

  factory StepRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StepRow(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      planId: serializer.fromJson<int>(json['planId']),
      stepIndex: serializer.fromJson<int>(json['stepIndex']),
      fromDose: serializer.fromJson<Milligrams>(json['fromDose']),
      toDose: serializer.fromJson<Milligrams>(json['toDose']),
      startDate: serializer.fromJson<LocalDate>(json['startDate']),
      status: serializer.fromJson<StepStatus>(json['status']),
      patternVersion: serializer.fromJson<int>(json['patternVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'planId': serializer.toJson<int>(planId),
      'stepIndex': serializer.toJson<int>(stepIndex),
      'fromDose': serializer.toJson<Milligrams>(fromDose),
      'toDose': serializer.toJson<Milligrams>(toDose),
      'startDate': serializer.toJson<LocalDate>(startDate),
      'status': serializer.toJson<StepStatus>(status),
      'patternVersion': serializer.toJson<int>(patternVersion),
    };
  }

  StepRow copyWith({
    int? id,
    String? uid,
    int? planId,
    int? stepIndex,
    Milligrams? fromDose,
    Milligrams? toDose,
    LocalDate? startDate,
    StepStatus? status,
    int? patternVersion,
  }) => StepRow(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    planId: planId ?? this.planId,
    stepIndex: stepIndex ?? this.stepIndex,
    fromDose: fromDose ?? this.fromDose,
    toDose: toDose ?? this.toDose,
    startDate: startDate ?? this.startDate,
    status: status ?? this.status,
    patternVersion: patternVersion ?? this.patternVersion,
  );
  StepRow copyWithCompanion(StepsCompanion data) {
    return StepRow(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      planId: data.planId.present ? data.planId.value : this.planId,
      stepIndex: data.stepIndex.present ? data.stepIndex.value : this.stepIndex,
      fromDose: data.fromDose.present ? data.fromDose.value : this.fromDose,
      toDose: data.toDose.present ? data.toDose.value : this.toDose,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      status: data.status.present ? data.status.value : this.status,
      patternVersion: data.patternVersion.present
          ? data.patternVersion.value
          : this.patternVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StepRow(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('planId: $planId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('fromDose: $fromDose, ')
          ..write('toDose: $toDose, ')
          ..write('startDate: $startDate, ')
          ..write('status: $status, ')
          ..write('patternVersion: $patternVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    planId,
    stepIndex,
    fromDose,
    toDose,
    startDate,
    status,
    patternVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepRow &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.planId == this.planId &&
          other.stepIndex == this.stepIndex &&
          other.fromDose == this.fromDose &&
          other.toDose == this.toDose &&
          other.startDate == this.startDate &&
          other.status == this.status &&
          other.patternVersion == this.patternVersion);
}

class StepsCompanion extends UpdateCompanion<StepRow> {
  final Value<int> id;
  final Value<String> uid;
  final Value<int> planId;
  final Value<int> stepIndex;
  final Value<Milligrams> fromDose;
  final Value<Milligrams> toDose;
  final Value<LocalDate> startDate;
  final Value<StepStatus> status;
  final Value<int> patternVersion;
  const StepsCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.planId = const Value.absent(),
    this.stepIndex = const Value.absent(),
    this.fromDose = const Value.absent(),
    this.toDose = const Value.absent(),
    this.startDate = const Value.absent(),
    this.status = const Value.absent(),
    this.patternVersion = const Value.absent(),
  });
  StepsCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    required int planId,
    required int stepIndex,
    required Milligrams fromDose,
    required Milligrams toDose,
    required LocalDate startDate,
    required StepStatus status,
    required int patternVersion,
  }) : uid = Value(uid),
       planId = Value(planId),
       stepIndex = Value(stepIndex),
       fromDose = Value(fromDose),
       toDose = Value(toDose),
       startDate = Value(startDate),
       status = Value(status),
       patternVersion = Value(patternVersion);
  static Insertable<StepRow> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<int>? planId,
    Expression<int>? stepIndex,
    Expression<int>? fromDose,
    Expression<int>? toDose,
    Expression<String>? startDate,
    Expression<String>? status,
    Expression<int>? patternVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (planId != null) 'plan_id': planId,
      if (stepIndex != null) 'step_index': stepIndex,
      if (fromDose != null) 'from_dose': fromDose,
      if (toDose != null) 'to_dose': toDose,
      if (startDate != null) 'start_date': startDate,
      if (status != null) 'status': status,
      if (patternVersion != null) 'pattern_version': patternVersion,
    });
  }

  StepsCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<int>? planId,
    Value<int>? stepIndex,
    Value<Milligrams>? fromDose,
    Value<Milligrams>? toDose,
    Value<LocalDate>? startDate,
    Value<StepStatus>? status,
    Value<int>? patternVersion,
  }) {
    return StepsCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      planId: planId ?? this.planId,
      stepIndex: stepIndex ?? this.stepIndex,
      fromDose: fromDose ?? this.fromDose,
      toDose: toDose ?? this.toDose,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      patternVersion: patternVersion ?? this.patternVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (stepIndex.present) {
      map['step_index'] = Variable<int>(stepIndex.value);
    }
    if (fromDose.present) {
      map['from_dose'] = Variable<int>(
        $StepsTable.$converterfromDose.toSql(fromDose.value),
      );
    }
    if (toDose.present) {
      map['to_dose'] = Variable<int>(
        $StepsTable.$convertertoDose.toSql(toDose.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(
        $StepsTable.$converterstartDate.toSql(startDate.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $StepsTable.$converterstatus.toSql(status.value),
      );
    }
    if (patternVersion.present) {
      map['pattern_version'] = Variable<int>(patternVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StepsCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('planId: $planId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('fromDose: $fromDose, ')
          ..write('toDose: $toDose, ')
          ..write('startDate: $startDate, ')
          ..write('status: $status, ')
          ..write('patternVersion: $patternVersion')
          ..write(')'))
        .toString();
  }
}

class $DoseLogsV2Table extends DoseLogsV2
    with TableInfo<$DoseLogsV2Table, DoseLogV2Row> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DoseLogsV2Table(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($DoseLogsV2Table.$converterdate);
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> plannedMg =
      GeneratedColumn<int>(
        'planned_mg',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($DoseLogsV2Table.$converterplannedMg);
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> actualMg =
      GeneratedColumn<int>(
        'actual_mg',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($DoseLogsV2Table.$converteractualMg);
  static const VerificationMeta _takenMeta = const VerificationMeta('taken');
  @override
  late final GeneratedColumn<bool> taken = GeneratedColumn<bool>(
    'taken',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("taken" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> takenAt =
      GeneratedColumn<int>(
        'taken_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($DoseLogsV2Table.$convertertakenAtn);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedSourceMeta = const VerificationMeta(
    'recordedSource',
  );
  @override
  late final GeneratedColumn<String> recordedSource = GeneratedColumn<String>(
    'recorded_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    planId,
    date,
    plannedMg,
    actualMg,
    taken,
    takenAt,
    note,
    recordedSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dose_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DoseLogV2Row> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('taken')) {
      context.handle(
        _takenMeta,
        taken.isAcceptableOrUnknown(data['taken']!, _takenMeta),
      );
    } else if (isInserting) {
      context.missing(_takenMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('recorded_source')) {
      context.handle(
        _recordedSourceMeta,
        recordedSource.isAcceptableOrUnknown(
          data['recorded_source']!,
          _recordedSourceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DoseLogV2Row map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DoseLogV2Row(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_id'],
      )!,
      date: $DoseLogsV2Table.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      plannedMg: $DoseLogsV2Table.$converterplannedMg.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}planned_mg'],
        )!,
      ),
      actualMg: $DoseLogsV2Table.$converteractualMg.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}actual_mg'],
        )!,
      ),
      taken: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}taken'],
      )!,
      takenAt: $DoseLogsV2Table.$convertertakenAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}taken_at'],
        ),
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      recordedSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_source'],
      ),
    );
  }

  @override
  $DoseLogsV2Table createAlias(String alias) {
    return $DoseLogsV2Table(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterdate =
      const LocalDateConverter();
  static TypeConverter<Milligrams, int> $converterplannedMg =
      const MilligramsConverter();
  static TypeConverter<Milligrams, int> $converteractualMg =
      const MilligramsConverter();
  static TypeConverter<DateTime, int> $convertertakenAt =
      const UtcInstantConverter();
  static TypeConverter<DateTime?, int?> $convertertakenAtn =
      NullAwareTypeConverter.wrap($convertertakenAt);
}

class DoseLogV2Row extends DataClass implements Insertable<DoseLogV2Row> {
  /// Surrogate key.
  final int id;

  /// Stable identity across an export/import round trip.
  final String uid;

  /// Owning plan; deleting the plan deletes its logs.
  final int planId;

  /// The calendar day this log is about.
  final LocalDate date;

  /// What the schedule said, frozen at the moment it was logged.
  final Milligrams plannedMg;

  /// What the patient actually took, frozen at tick time.
  final Milligrams actualMg;

  /// Whether the patient ticked the day.
  final bool taken;

  /// When they ticked it, as UTC epoch milliseconds.
  final DateTime? takenAt;

  /// The patient's own words.
  final String? note;

  /// The additive column under test. Nullable, so the migration is a plain
  /// `ALTER TABLE ... ADD COLUMN` with no backfill.
  final String? recordedSource;
  const DoseLogV2Row({
    required this.id,
    required this.uid,
    required this.planId,
    required this.date,
    required this.plannedMg,
    required this.actualMg,
    required this.taken,
    this.takenAt,
    this.note,
    this.recordedSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['plan_id'] = Variable<int>(planId);
    {
      map['date'] = Variable<String>(
        $DoseLogsV2Table.$converterdate.toSql(date),
      );
    }
    {
      map['planned_mg'] = Variable<int>(
        $DoseLogsV2Table.$converterplannedMg.toSql(plannedMg),
      );
    }
    {
      map['actual_mg'] = Variable<int>(
        $DoseLogsV2Table.$converteractualMg.toSql(actualMg),
      );
    }
    map['taken'] = Variable<bool>(taken);
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<int>(
        $DoseLogsV2Table.$convertertakenAtn.toSql(takenAt),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || recordedSource != null) {
      map['recorded_source'] = Variable<String>(recordedSource);
    }
    return map;
  }

  DoseLogsV2Companion toCompanion(bool nullToAbsent) {
    return DoseLogsV2Companion(
      id: Value(id),
      uid: Value(uid),
      planId: Value(planId),
      date: Value(date),
      plannedMg: Value(plannedMg),
      actualMg: Value(actualMg),
      taken: Value(taken),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recordedSource: recordedSource == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedSource),
    );
  }

  factory DoseLogV2Row.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DoseLogV2Row(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      planId: serializer.fromJson<int>(json['planId']),
      date: serializer.fromJson<LocalDate>(json['date']),
      plannedMg: serializer.fromJson<Milligrams>(json['plannedMg']),
      actualMg: serializer.fromJson<Milligrams>(json['actualMg']),
      taken: serializer.fromJson<bool>(json['taken']),
      takenAt: serializer.fromJson<DateTime?>(json['takenAt']),
      note: serializer.fromJson<String?>(json['note']),
      recordedSource: serializer.fromJson<String?>(json['recordedSource']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'planId': serializer.toJson<int>(planId),
      'date': serializer.toJson<LocalDate>(date),
      'plannedMg': serializer.toJson<Milligrams>(plannedMg),
      'actualMg': serializer.toJson<Milligrams>(actualMg),
      'taken': serializer.toJson<bool>(taken),
      'takenAt': serializer.toJson<DateTime?>(takenAt),
      'note': serializer.toJson<String?>(note),
      'recordedSource': serializer.toJson<String?>(recordedSource),
    };
  }

  DoseLogV2Row copyWith({
    int? id,
    String? uid,
    int? planId,
    LocalDate? date,
    Milligrams? plannedMg,
    Milligrams? actualMg,
    bool? taken,
    Value<DateTime?> takenAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> recordedSource = const Value.absent(),
  }) => DoseLogV2Row(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    planId: planId ?? this.planId,
    date: date ?? this.date,
    plannedMg: plannedMg ?? this.plannedMg,
    actualMg: actualMg ?? this.actualMg,
    taken: taken ?? this.taken,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    note: note.present ? note.value : this.note,
    recordedSource: recordedSource.present
        ? recordedSource.value
        : this.recordedSource,
  );
  DoseLogV2Row copyWithCompanion(DoseLogsV2Companion data) {
    return DoseLogV2Row(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      planId: data.planId.present ? data.planId.value : this.planId,
      date: data.date.present ? data.date.value : this.date,
      plannedMg: data.plannedMg.present ? data.plannedMg.value : this.plannedMg,
      actualMg: data.actualMg.present ? data.actualMg.value : this.actualMg,
      taken: data.taken.present ? data.taken.value : this.taken,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      note: data.note.present ? data.note.value : this.note,
      recordedSource: data.recordedSource.present
          ? data.recordedSource.value
          : this.recordedSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseLogV2Row(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('planId: $planId, ')
          ..write('date: $date, ')
          ..write('plannedMg: $plannedMg, ')
          ..write('actualMg: $actualMg, ')
          ..write('taken: $taken, ')
          ..write('takenAt: $takenAt, ')
          ..write('note: $note, ')
          ..write('recordedSource: $recordedSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    planId,
    date,
    plannedMg,
    actualMg,
    taken,
    takenAt,
    note,
    recordedSource,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseLogV2Row &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.planId == this.planId &&
          other.date == this.date &&
          other.plannedMg == this.plannedMg &&
          other.actualMg == this.actualMg &&
          other.taken == this.taken &&
          other.takenAt == this.takenAt &&
          other.note == this.note &&
          other.recordedSource == this.recordedSource);
}

class DoseLogsV2Companion extends UpdateCompanion<DoseLogV2Row> {
  final Value<int> id;
  final Value<String> uid;
  final Value<int> planId;
  final Value<LocalDate> date;
  final Value<Milligrams> plannedMg;
  final Value<Milligrams> actualMg;
  final Value<bool> taken;
  final Value<DateTime?> takenAt;
  final Value<String?> note;
  final Value<String?> recordedSource;
  const DoseLogsV2Companion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.planId = const Value.absent(),
    this.date = const Value.absent(),
    this.plannedMg = const Value.absent(),
    this.actualMg = const Value.absent(),
    this.taken = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedSource = const Value.absent(),
  });
  DoseLogsV2Companion.insert({
    this.id = const Value.absent(),
    required String uid,
    required int planId,
    required LocalDate date,
    required Milligrams plannedMg,
    required Milligrams actualMg,
    required bool taken,
    this.takenAt = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedSource = const Value.absent(),
  }) : uid = Value(uid),
       planId = Value(planId),
       date = Value(date),
       plannedMg = Value(plannedMg),
       actualMg = Value(actualMg),
       taken = Value(taken);
  static Insertable<DoseLogV2Row> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<int>? planId,
    Expression<String>? date,
    Expression<int>? plannedMg,
    Expression<int>? actualMg,
    Expression<bool>? taken,
    Expression<int>? takenAt,
    Expression<String>? note,
    Expression<String>? recordedSource,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (planId != null) 'plan_id': planId,
      if (date != null) 'date': date,
      if (plannedMg != null) 'planned_mg': plannedMg,
      if (actualMg != null) 'actual_mg': actualMg,
      if (taken != null) 'taken': taken,
      if (takenAt != null) 'taken_at': takenAt,
      if (note != null) 'note': note,
      if (recordedSource != null) 'recorded_source': recordedSource,
    });
  }

  DoseLogsV2Companion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<int>? planId,
    Value<LocalDate>? date,
    Value<Milligrams>? plannedMg,
    Value<Milligrams>? actualMg,
    Value<bool>? taken,
    Value<DateTime?>? takenAt,
    Value<String?>? note,
    Value<String?>? recordedSource,
  }) {
    return DoseLogsV2Companion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      planId: planId ?? this.planId,
      date: date ?? this.date,
      plannedMg: plannedMg ?? this.plannedMg,
      actualMg: actualMg ?? this.actualMg,
      taken: taken ?? this.taken,
      takenAt: takenAt ?? this.takenAt,
      note: note ?? this.note,
      recordedSource: recordedSource ?? this.recordedSource,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $DoseLogsV2Table.$converterdate.toSql(date.value),
      );
    }
    if (plannedMg.present) {
      map['planned_mg'] = Variable<int>(
        $DoseLogsV2Table.$converterplannedMg.toSql(plannedMg.value),
      );
    }
    if (actualMg.present) {
      map['actual_mg'] = Variable<int>(
        $DoseLogsV2Table.$converteractualMg.toSql(actualMg.value),
      );
    }
    if (taken.present) {
      map['taken'] = Variable<bool>(taken.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<int>(
        $DoseLogsV2Table.$convertertakenAtn.toSql(takenAt.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recordedSource.present) {
      map['recorded_source'] = Variable<String>(recordedSource.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoseLogsV2Companion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('planId: $planId, ')
          ..write('date: $date, ')
          ..write('plannedMg: $plannedMg, ')
          ..write('actualMg: $actualMg, ')
          ..write('taken: $taken, ')
          ..write('takenAt: $takenAt, ')
          ..write('note: $note, ')
          ..write('recordedSource: $recordedSource')
          ..write(')'))
        .toString();
  }
}

class $FlareEventsTable extends FlareEvents
    with TableInfo<$FlareEventsTable, FlareEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlareEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($FlareEventsTable.$converterdate);
  @override
  late final GeneratedColumnWithTypeConverter<Milligrams, int> revertToDose =
      GeneratedColumn<int>(
        'revert_to_dose',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Milligrams>($FlareEventsTable.$converterrevertToDose);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    planId,
    date,
    revertToDose,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flare_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlareEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlareEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlareEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_id'],
      )!,
      date: $FlareEventsTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      revertToDose: $FlareEventsTable.$converterrevertToDose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}revert_to_dose'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $FlareEventsTable createAlias(String alias) {
    return $FlareEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterdate =
      const LocalDateConverter();
  static TypeConverter<Milligrams, int> $converterrevertToDose =
      const MilligramsConverter();
}

class FlareEventRow extends DataClass implements Insertable<FlareEventRow> {
  /// Surrogate key.
  final int id;

  /// Stable identity across an export/import round trip.
  final String uid;

  /// Owning plan; deleting the plan deletes its flares.
  final int planId;

  /// The day the flare was recorded.
  final LocalDate date;

  /// The dose the patient went back to.
  final Milligrams revertToDose;

  /// The patient's own words.
  final String? note;
  const FlareEventRow({
    required this.id,
    required this.uid,
    required this.planId,
    required this.date,
    required this.revertToDose,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['plan_id'] = Variable<int>(planId);
    {
      map['date'] = Variable<String>(
        $FlareEventsTable.$converterdate.toSql(date),
      );
    }
    {
      map['revert_to_dose'] = Variable<int>(
        $FlareEventsTable.$converterrevertToDose.toSql(revertToDose),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  FlareEventsCompanion toCompanion(bool nullToAbsent) {
    return FlareEventsCompanion(
      id: Value(id),
      uid: Value(uid),
      planId: Value(planId),
      date: Value(date),
      revertToDose: Value(revertToDose),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory FlareEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlareEventRow(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      planId: serializer.fromJson<int>(json['planId']),
      date: serializer.fromJson<LocalDate>(json['date']),
      revertToDose: serializer.fromJson<Milligrams>(json['revertToDose']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'planId': serializer.toJson<int>(planId),
      'date': serializer.toJson<LocalDate>(date),
      'revertToDose': serializer.toJson<Milligrams>(revertToDose),
      'note': serializer.toJson<String?>(note),
    };
  }

  FlareEventRow copyWith({
    int? id,
    String? uid,
    int? planId,
    LocalDate? date,
    Milligrams? revertToDose,
    Value<String?> note = const Value.absent(),
  }) => FlareEventRow(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    planId: planId ?? this.planId,
    date: date ?? this.date,
    revertToDose: revertToDose ?? this.revertToDose,
    note: note.present ? note.value : this.note,
  );
  FlareEventRow copyWithCompanion(FlareEventsCompanion data) {
    return FlareEventRow(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      planId: data.planId.present ? data.planId.value : this.planId,
      date: data.date.present ? data.date.value : this.date,
      revertToDose: data.revertToDose.present
          ? data.revertToDose.value
          : this.revertToDose,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlareEventRow(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('planId: $planId, ')
          ..write('date: $date, ')
          ..write('revertToDose: $revertToDose, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uid, planId, date, revertToDose, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlareEventRow &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.planId == this.planId &&
          other.date == this.date &&
          other.revertToDose == this.revertToDose &&
          other.note == this.note);
}

class FlareEventsCompanion extends UpdateCompanion<FlareEventRow> {
  final Value<int> id;
  final Value<String> uid;
  final Value<int> planId;
  final Value<LocalDate> date;
  final Value<Milligrams> revertToDose;
  final Value<String?> note;
  const FlareEventsCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.planId = const Value.absent(),
    this.date = const Value.absent(),
    this.revertToDose = const Value.absent(),
    this.note = const Value.absent(),
  });
  FlareEventsCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    required int planId,
    required LocalDate date,
    required Milligrams revertToDose,
    this.note = const Value.absent(),
  }) : uid = Value(uid),
       planId = Value(planId),
       date = Value(date),
       revertToDose = Value(revertToDose);
  static Insertable<FlareEventRow> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<int>? planId,
    Expression<String>? date,
    Expression<int>? revertToDose,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (planId != null) 'plan_id': planId,
      if (date != null) 'date': date,
      if (revertToDose != null) 'revert_to_dose': revertToDose,
      if (note != null) 'note': note,
    });
  }

  FlareEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<int>? planId,
    Value<LocalDate>? date,
    Value<Milligrams>? revertToDose,
    Value<String?>? note,
  }) {
    return FlareEventsCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      planId: planId ?? this.planId,
      date: date ?? this.date,
      revertToDose: revertToDose ?? this.revertToDose,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $FlareEventsTable.$converterdate.toSql(date.value),
      );
    }
    if (revertToDose.present) {
      map['revert_to_dose'] = Variable<int>(
        $FlareEventsTable.$converterrevertToDose.toSql(revertToDose.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlareEventsCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('planId: $planId, ')
          ..write('date: $date, ')
          ..write('revertToDose: $revertToDose, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $HoldEventsTable extends HoldEvents
    with TableInfo<$HoldEventsTable, HoldEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _stepIdMeta = const VerificationMeta('stepId');
  @override
  late final GeneratedColumn<int> stepId = GeneratedColumn<int>(
    'step_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> fromDate =
      GeneratedColumn<String>(
        'from_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($HoldEventsTable.$converterfromDate);
  static const VerificationMeta _extraDaysMeta = const VerificationMeta(
    'extraDays',
  );
  @override
  late final GeneratedColumn<int> extraDays = GeneratedColumn<int>(
    'extra_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    stepId,
    fromDate,
    extraDays,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hold_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('step_id')) {
      context.handle(
        _stepIdMeta,
        stepId.isAcceptableOrUnknown(data['step_id']!, _stepIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stepIdMeta);
    }
    if (data.containsKey('extra_days')) {
      context.handle(
        _extraDaysMeta,
        extraDays.isAcceptableOrUnknown(data['extra_days']!, _extraDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_extraDaysMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HoldEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      stepId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step_id'],
      )!,
      fromDate: $HoldEventsTable.$converterfromDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}from_date'],
        )!,
      ),
      extraDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}extra_days'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $HoldEventsTable createAlias(String alias) {
    return $HoldEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterfromDate =
      const LocalDateConverter();
}

class HoldEventRow extends DataClass implements Insertable<HoldEventRow> {
  /// Surrogate key.
  final int id;

  /// Stable identity across an export/import round trip.
  final String uid;

  /// Owning step; deleting the plan cascades THROUGH Steps to here.
  final int stepId;

  /// The last day taken as normal; the extra days follow it.
  final LocalDate fromDate;

  /// How many extra days to insert.
  final int extraDays;

  /// The patient's own words.
  final String? note;
  const HoldEventRow({
    required this.id,
    required this.uid,
    required this.stepId,
    required this.fromDate,
    required this.extraDays,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['step_id'] = Variable<int>(stepId);
    {
      map['from_date'] = Variable<String>(
        $HoldEventsTable.$converterfromDate.toSql(fromDate),
      );
    }
    map['extra_days'] = Variable<int>(extraDays);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  HoldEventsCompanion toCompanion(bool nullToAbsent) {
    return HoldEventsCompanion(
      id: Value(id),
      uid: Value(uid),
      stepId: Value(stepId),
      fromDate: Value(fromDate),
      extraDays: Value(extraDays),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory HoldEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldEventRow(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      stepId: serializer.fromJson<int>(json['stepId']),
      fromDate: serializer.fromJson<LocalDate>(json['fromDate']),
      extraDays: serializer.fromJson<int>(json['extraDays']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'stepId': serializer.toJson<int>(stepId),
      'fromDate': serializer.toJson<LocalDate>(fromDate),
      'extraDays': serializer.toJson<int>(extraDays),
      'note': serializer.toJson<String?>(note),
    };
  }

  HoldEventRow copyWith({
    int? id,
    String? uid,
    int? stepId,
    LocalDate? fromDate,
    int? extraDays,
    Value<String?> note = const Value.absent(),
  }) => HoldEventRow(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    stepId: stepId ?? this.stepId,
    fromDate: fromDate ?? this.fromDate,
    extraDays: extraDays ?? this.extraDays,
    note: note.present ? note.value : this.note,
  );
  HoldEventRow copyWithCompanion(HoldEventsCompanion data) {
    return HoldEventRow(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      stepId: data.stepId.present ? data.stepId.value : this.stepId,
      fromDate: data.fromDate.present ? data.fromDate.value : this.fromDate,
      extraDays: data.extraDays.present ? data.extraDays.value : this.extraDays,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldEventRow(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('stepId: $stepId, ')
          ..write('fromDate: $fromDate, ')
          ..write('extraDays: $extraDays, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uid, stepId, fromDate, extraDays, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldEventRow &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.stepId == this.stepId &&
          other.fromDate == this.fromDate &&
          other.extraDays == this.extraDays &&
          other.note == this.note);
}

class HoldEventsCompanion extends UpdateCompanion<HoldEventRow> {
  final Value<int> id;
  final Value<String> uid;
  final Value<int> stepId;
  final Value<LocalDate> fromDate;
  final Value<int> extraDays;
  final Value<String?> note;
  const HoldEventsCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.stepId = const Value.absent(),
    this.fromDate = const Value.absent(),
    this.extraDays = const Value.absent(),
    this.note = const Value.absent(),
  });
  HoldEventsCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    required int stepId,
    required LocalDate fromDate,
    required int extraDays,
    this.note = const Value.absent(),
  }) : uid = Value(uid),
       stepId = Value(stepId),
       fromDate = Value(fromDate),
       extraDays = Value(extraDays);
  static Insertable<HoldEventRow> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<int>? stepId,
    Expression<String>? fromDate,
    Expression<int>? extraDays,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (stepId != null) 'step_id': stepId,
      if (fromDate != null) 'from_date': fromDate,
      if (extraDays != null) 'extra_days': extraDays,
      if (note != null) 'note': note,
    });
  }

  HoldEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<int>? stepId,
    Value<LocalDate>? fromDate,
    Value<int>? extraDays,
    Value<String?>? note,
  }) {
    return HoldEventsCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      stepId: stepId ?? this.stepId,
      fromDate: fromDate ?? this.fromDate,
      extraDays: extraDays ?? this.extraDays,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (stepId.present) {
      map['step_id'] = Variable<int>(stepId.value);
    }
    if (fromDate.present) {
      map['from_date'] = Variable<String>(
        $HoldEventsTable.$converterfromDate.toSql(fromDate.value),
      );
    }
    if (extraDays.present) {
      map['extra_days'] = Variable<int>(extraDays.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldEventsCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('stepId: $stepId, ')
          ..write('fromDate: $fromDate, ')
          ..write('extraDays: $extraDays, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $SettingsRowsTable extends SettingsRows
    with TableInfo<$SettingsRowsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderMinuteOfDayMeta =
      const VerificationMeta('reminderMinuteOfDay');
  @override
  late final GeneratedColumn<int> reminderMinuteOfDay = GeneratedColumn<int>(
    'reminder_minute_of_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textScaleMeta = const VerificationMeta(
    'textScale',
  );
  @override
  late final GeneratedColumn<double> textScale = GeneratedColumn<double>(
    'text_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _highContrastMeta = const VerificationMeta(
    'highContrast',
  );
  @override
  late final GeneratedColumn<bool> highContrast = GeneratedColumn<bool>(
    'high_contrast',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("high_contrast" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int>
  disclaimerAcceptedAt =
      GeneratedColumn<int>(
        'disclaimer_accepted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $SettingsRowsTable.$converterdisclaimerAcceptedAtn,
      );
  static const VerificationMeta _localeTagMeta = const VerificationMeta(
    'localeTag',
  );
  @override
  late final GeneratedColumn<String> localeTag = GeneratedColumn<String>(
    'locale_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    reminderEnabled,
    reminderMinuteOfDay,
    textScale,
    highContrast,
    disclaimerAcceptedAt,
    localeTag,
    themeMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minute_of_day')) {
      context.handle(
        _reminderMinuteOfDayMeta,
        reminderMinuteOfDay.isAcceptableOrUnknown(
          data['reminder_minute_of_day']!,
          _reminderMinuteOfDayMeta,
        ),
      );
    }
    if (data.containsKey('text_scale')) {
      context.handle(
        _textScaleMeta,
        textScale.isAcceptableOrUnknown(data['text_scale']!, _textScaleMeta),
      );
    }
    if (data.containsKey('high_contrast')) {
      context.handle(
        _highContrastMeta,
        highContrast.isAcceptableOrUnknown(
          data['high_contrast']!,
          _highContrastMeta,
        ),
      );
    }
    if (data.containsKey('locale_tag')) {
      context.handle(
        _localeTagMeta,
        localeTag.isAcceptableOrUnknown(data['locale_tag']!, _localeTagMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderMinuteOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minute_of_day'],
      ),
      textScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}text_scale'],
      )!,
      highContrast: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}high_contrast'],
      )!,
      disclaimerAcceptedAt: $SettingsRowsTable.$converterdisclaimerAcceptedAtn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}disclaimer_accepted_at'],
            ),
          ),
      localeTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale_tag'],
      ),
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
    );
  }

  @override
  $SettingsRowsTable createAlias(String alias) {
    return $SettingsRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterdisclaimerAcceptedAt =
      const UtcInstantConverter();
  static TypeConverter<DateTime?, int?> $converterdisclaimerAcceptedAtn =
      NullAwareTypeConverter.wrap($converterdisclaimerAcceptedAt);
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  /// Always 0 — the CHECK below is what stops a second row existing.
  final int id;

  /// Stable identity across an export/import round trip.
  final String uid;

  /// Whether the daily reminder is on.
  final bool reminderEnabled;

  /// Minutes since **local** midnight.
  ///
  /// A reminder is a wall-clock time. Storing it as an instant is the same DST
  /// bug in a different hat.
  final int? reminderMinuteOfDay;

  /// The user's text-scale preference, on top of the OS setting.
  final double textScale;

  /// Whether the high-contrast palette is selected.
  final bool highContrast;

  /// When the disclaimer was accepted, as UTC epoch milliseconds.
  final DateTime? disclaimerAcceptedAt;

  /// The chosen locale, or null to follow the OS.
  final String? localeTag;

  /// `system`, `light` or `dark`.
  final String themeMode;
  const SettingsRow({
    required this.id,
    required this.uid,
    required this.reminderEnabled,
    this.reminderMinuteOfDay,
    required this.textScale,
    required this.highContrast,
    this.disclaimerAcceptedAt,
    this.localeTag,
    required this.themeMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    if (!nullToAbsent || reminderMinuteOfDay != null) {
      map['reminder_minute_of_day'] = Variable<int>(reminderMinuteOfDay);
    }
    map['text_scale'] = Variable<double>(textScale);
    map['high_contrast'] = Variable<bool>(highContrast);
    if (!nullToAbsent || disclaimerAcceptedAt != null) {
      map['disclaimer_accepted_at'] = Variable<int>(
        $SettingsRowsTable.$converterdisclaimerAcceptedAtn.toSql(
          disclaimerAcceptedAt,
        ),
      );
    }
    if (!nullToAbsent || localeTag != null) {
      map['locale_tag'] = Variable<String>(localeTag);
    }
    map['theme_mode'] = Variable<String>(themeMode);
    return map;
  }

  SettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return SettingsRowsCompanion(
      id: Value(id),
      uid: Value(uid),
      reminderEnabled: Value(reminderEnabled),
      reminderMinuteOfDay: reminderMinuteOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinuteOfDay),
      textScale: Value(textScale),
      highContrast: Value(highContrast),
      disclaimerAcceptedAt: disclaimerAcceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(disclaimerAcceptedAt),
      localeTag: localeTag == null && nullToAbsent
          ? const Value.absent()
          : Value(localeTag),
      themeMode: Value(themeMode),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderMinuteOfDay: serializer.fromJson<int?>(
        json['reminderMinuteOfDay'],
      ),
      textScale: serializer.fromJson<double>(json['textScale']),
      highContrast: serializer.fromJson<bool>(json['highContrast']),
      disclaimerAcceptedAt: serializer.fromJson<DateTime?>(
        json['disclaimerAcceptedAt'],
      ),
      localeTag: serializer.fromJson<String?>(json['localeTag']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderMinuteOfDay': serializer.toJson<int?>(reminderMinuteOfDay),
      'textScale': serializer.toJson<double>(textScale),
      'highContrast': serializer.toJson<bool>(highContrast),
      'disclaimerAcceptedAt': serializer.toJson<DateTime?>(
        disclaimerAcceptedAt,
      ),
      'localeTag': serializer.toJson<String?>(localeTag),
      'themeMode': serializer.toJson<String>(themeMode),
    };
  }

  SettingsRow copyWith({
    int? id,
    String? uid,
    bool? reminderEnabled,
    Value<int?> reminderMinuteOfDay = const Value.absent(),
    double? textScale,
    bool? highContrast,
    Value<DateTime?> disclaimerAcceptedAt = const Value.absent(),
    Value<String?> localeTag = const Value.absent(),
    String? themeMode,
  }) => SettingsRow(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinuteOfDay: reminderMinuteOfDay.present
        ? reminderMinuteOfDay.value
        : this.reminderMinuteOfDay,
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    disclaimerAcceptedAt: disclaimerAcceptedAt.present
        ? disclaimerAcceptedAt.value
        : this.disclaimerAcceptedAt,
    localeTag: localeTag.present ? localeTag.value : this.localeTag,
    themeMode: themeMode ?? this.themeMode,
  );
  SettingsRow copyWithCompanion(SettingsRowsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderMinuteOfDay: data.reminderMinuteOfDay.present
          ? data.reminderMinuteOfDay.value
          : this.reminderMinuteOfDay,
      textScale: data.textScale.present ? data.textScale.value : this.textScale,
      highContrast: data.highContrast.present
          ? data.highContrast.value
          : this.highContrast,
      disclaimerAcceptedAt: data.disclaimerAcceptedAt.present
          ? data.disclaimerAcceptedAt.value
          : this.disclaimerAcceptedAt,
      localeTag: data.localeTag.present ? data.localeTag.value : this.localeTag,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderMinuteOfDay: $reminderMinuteOfDay, ')
          ..write('textScale: $textScale, ')
          ..write('highContrast: $highContrast, ')
          ..write('disclaimerAcceptedAt: $disclaimerAcceptedAt, ')
          ..write('localeTag: $localeTag, ')
          ..write('themeMode: $themeMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    reminderEnabled,
    reminderMinuteOfDay,
    textScale,
    highContrast,
    disclaimerAcceptedAt,
    localeTag,
    themeMode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderMinuteOfDay == this.reminderMinuteOfDay &&
          other.textScale == this.textScale &&
          other.highContrast == this.highContrast &&
          other.disclaimerAcceptedAt == this.disclaimerAcceptedAt &&
          other.localeTag == this.localeTag &&
          other.themeMode == this.themeMode);
}

class SettingsRowsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<String> uid;
  final Value<bool> reminderEnabled;
  final Value<int?> reminderMinuteOfDay;
  final Value<double> textScale;
  final Value<bool> highContrast;
  final Value<DateTime?> disclaimerAcceptedAt;
  final Value<String?> localeTag;
  final Value<String> themeMode;
  const SettingsRowsCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderMinuteOfDay = const Value.absent(),
    this.textScale = const Value.absent(),
    this.highContrast = const Value.absent(),
    this.disclaimerAcceptedAt = const Value.absent(),
    this.localeTag = const Value.absent(),
    this.themeMode = const Value.absent(),
  });
  SettingsRowsCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    this.reminderEnabled = const Value.absent(),
    this.reminderMinuteOfDay = const Value.absent(),
    this.textScale = const Value.absent(),
    this.highContrast = const Value.absent(),
    this.disclaimerAcceptedAt = const Value.absent(),
    this.localeTag = const Value.absent(),
    this.themeMode = const Value.absent(),
  }) : uid = Value(uid);
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<bool>? reminderEnabled,
    Expression<int>? reminderMinuteOfDay,
    Expression<double>? textScale,
    Expression<bool>? highContrast,
    Expression<int>? disclaimerAcceptedAt,
    Expression<String>? localeTag,
    Expression<String>? themeMode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderMinuteOfDay != null)
        'reminder_minute_of_day': reminderMinuteOfDay,
      if (textScale != null) 'text_scale': textScale,
      if (highContrast != null) 'high_contrast': highContrast,
      if (disclaimerAcceptedAt != null)
        'disclaimer_accepted_at': disclaimerAcceptedAt,
      if (localeTag != null) 'locale_tag': localeTag,
      if (themeMode != null) 'theme_mode': themeMode,
    });
  }

  SettingsRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<bool>? reminderEnabled,
    Value<int?>? reminderMinuteOfDay,
    Value<double>? textScale,
    Value<bool>? highContrast,
    Value<DateTime?>? disclaimerAcceptedAt,
    Value<String?>? localeTag,
    Value<String>? themeMode,
  }) {
    return SettingsRowsCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinuteOfDay: reminderMinuteOfDay ?? this.reminderMinuteOfDay,
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      disclaimerAcceptedAt: disclaimerAcceptedAt ?? this.disclaimerAcceptedAt,
      localeTag: localeTag ?? this.localeTag,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderMinuteOfDay.present) {
      map['reminder_minute_of_day'] = Variable<int>(reminderMinuteOfDay.value);
    }
    if (textScale.present) {
      map['text_scale'] = Variable<double>(textScale.value);
    }
    if (highContrast.present) {
      map['high_contrast'] = Variable<bool>(highContrast.value);
    }
    if (disclaimerAcceptedAt.present) {
      map['disclaimer_accepted_at'] = Variable<int>(
        $SettingsRowsTable.$converterdisclaimerAcceptedAtn.toSql(
          disclaimerAcceptedAt.value,
        ),
      );
    }
    if (localeTag.present) {
      map['locale_tag'] = Variable<String>(localeTag.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRowsCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderMinuteOfDay: $reminderMinuteOfDay, ')
          ..write('textScale: $textScale, ')
          ..write('highContrast: $highContrast, ')
          ..write('disclaimerAcceptedAt: $disclaimerAcceptedAt, ')
          ..write('localeTag: $localeTag, ')
          ..write('themeMode: $themeMode')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabaseV2 extends GeneratedDatabase {
  _$AppDatabaseV2(QueryExecutor e) : super(e);
  $AppDatabaseV2Manager get managers => $AppDatabaseV2Manager(this);
  late final $TaperPlansTable taperPlans = $TaperPlansTable(this);
  late final $StepsTable steps = $StepsTable(this);
  late final $DoseLogsV2Table doseLogsV2 = $DoseLogsV2Table(this);
  late final $FlareEventsTable flareEvents = $FlareEventsTable(this);
  late final $HoldEventsTable holdEvents = $HoldEventsTable(this);
  late final $SettingsRowsTable settingsRows = $SettingsRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    taperPlans,
    steps,
    doseLogsV2,
    flareEvents,
    holdEvents,
    settingsRows,
  ];
}

typedef $$TaperPlansTableCreateCompanionBuilder =
    TaperPlansCompanion Function({
      Value<int> id,
      required String uid,
      Value<String> drugName,
      required LocalDate startDate,
      required Milligrams startingDose,
      required Milligrams targetDose,
      required List<Milligrams> tabletStrengths,
      required bool allowHalves,
      required TaperMethod method,
      Value<double?> percentage,
      Value<Milligrams?> fixedStep,
      Value<int> holdPeriodDays,
      required DateTime createdAt,
    });
typedef $$TaperPlansTableUpdateCompanionBuilder =
    TaperPlansCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<String> drugName,
      Value<LocalDate> startDate,
      Value<Milligrams> startingDose,
      Value<Milligrams> targetDose,
      Value<List<Milligrams>> tabletStrengths,
      Value<bool> allowHalves,
      Value<TaperMethod> method,
      Value<double?> percentage,
      Value<Milligrams?> fixedStep,
      Value<int> holdPeriodDays,
      Value<DateTime> createdAt,
    });

class $$TaperPlansTableFilterComposer
    extends Composer<_$AppDatabaseV2, $TaperPlansTable> {
  $$TaperPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get drugName => $composableBuilder(
    column: $table.drugName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get startDate =>
      $composableBuilder(
        column: $table.startDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int>
  get startingDose => $composableBuilder(
    column: $table.startingDose,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int> get targetDose =>
      $composableBuilder(
        column: $table.targetDose,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<Milligrams>, List<Milligrams>, String>
  get tabletStrengths => $composableBuilder(
    column: $table.tabletStrengths,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get allowHalves => $composableBuilder(
    column: $table.allowHalves,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaperMethod, TaperMethod, String> get method =>
      $composableBuilder(
        column: $table.method,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Milligrams?, Milligrams, int> get fixedStep =>
      $composableBuilder(
        column: $table.fixedStep,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get holdPeriodDays => $composableBuilder(
    column: $table.holdPeriodDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$TaperPlansTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $TaperPlansTable> {
  $$TaperPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get drugName => $composableBuilder(
    column: $table.drugName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingDose => $composableBuilder(
    column: $table.startingDose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDose => $composableBuilder(
    column: $table.targetDose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tabletStrengths => $composableBuilder(
    column: $table.tabletStrengths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowHalves => $composableBuilder(
    column: $table.allowHalves,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedStep => $composableBuilder(
    column: $table.fixedStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holdPeriodDays => $composableBuilder(
    column: $table.holdPeriodDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaperPlansTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $TaperPlansTable> {
  $$TaperPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get drugName =>
      $composableBuilder(column: $table.drugName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Milligrams, int> get startingDose =>
      $composableBuilder(
        column: $table.startingDose,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Milligrams, int> get targetDose =>
      $composableBuilder(
        column: $table.targetDose,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<Milligrams>, String>
  get tabletStrengths => $composableBuilder(
    column: $table.tabletStrengths,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowHalves => $composableBuilder(
    column: $table.allowHalves,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaperMethod, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Milligrams?, int> get fixedStep =>
      $composableBuilder(column: $table.fixedStep, builder: (column) => column);

  GeneratedColumn<int> get holdPeriodDays => $composableBuilder(
    column: $table.holdPeriodDays,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TaperPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $TaperPlansTable,
          TaperPlanRow,
          $$TaperPlansTableFilterComposer,
          $$TaperPlansTableOrderingComposer,
          $$TaperPlansTableAnnotationComposer,
          $$TaperPlansTableCreateCompanionBuilder,
          $$TaperPlansTableUpdateCompanionBuilder,
          (
            TaperPlanRow,
            BaseReferences<_$AppDatabaseV2, $TaperPlansTable, TaperPlanRow>,
          ),
          TaperPlanRow,
          PrefetchHooks Function()
        > {
  $$TaperPlansTableTableManager(_$AppDatabaseV2 db, $TaperPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaperPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaperPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaperPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> drugName = const Value.absent(),
                Value<LocalDate> startDate = const Value.absent(),
                Value<Milligrams> startingDose = const Value.absent(),
                Value<Milligrams> targetDose = const Value.absent(),
                Value<List<Milligrams>> tabletStrengths = const Value.absent(),
                Value<bool> allowHalves = const Value.absent(),
                Value<TaperMethod> method = const Value.absent(),
                Value<double?> percentage = const Value.absent(),
                Value<Milligrams?> fixedStep = const Value.absent(),
                Value<int> holdPeriodDays = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TaperPlansCompanion(
                id: id,
                uid: uid,
                drugName: drugName,
                startDate: startDate,
                startingDose: startingDose,
                targetDose: targetDose,
                tabletStrengths: tabletStrengths,
                allowHalves: allowHalves,
                method: method,
                percentage: percentage,
                fixedStep: fixedStep,
                holdPeriodDays: holdPeriodDays,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                Value<String> drugName = const Value.absent(),
                required LocalDate startDate,
                required Milligrams startingDose,
                required Milligrams targetDose,
                required List<Milligrams> tabletStrengths,
                required bool allowHalves,
                required TaperMethod method,
                Value<double?> percentage = const Value.absent(),
                Value<Milligrams?> fixedStep = const Value.absent(),
                Value<int> holdPeriodDays = const Value.absent(),
                required DateTime createdAt,
              }) => TaperPlansCompanion.insert(
                id: id,
                uid: uid,
                drugName: drugName,
                startDate: startDate,
                startingDose: startingDose,
                targetDose: targetDose,
                tabletStrengths: tabletStrengths,
                allowHalves: allowHalves,
                method: method,
                percentage: percentage,
                fixedStep: fixedStep,
                holdPeriodDays: holdPeriodDays,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaperPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $TaperPlansTable,
      TaperPlanRow,
      $$TaperPlansTableFilterComposer,
      $$TaperPlansTableOrderingComposer,
      $$TaperPlansTableAnnotationComposer,
      $$TaperPlansTableCreateCompanionBuilder,
      $$TaperPlansTableUpdateCompanionBuilder,
      (
        TaperPlanRow,
        BaseReferences<_$AppDatabaseV2, $TaperPlansTable, TaperPlanRow>,
      ),
      TaperPlanRow,
      PrefetchHooks Function()
    >;
typedef $$StepsTableCreateCompanionBuilder =
    StepsCompanion Function({
      Value<int> id,
      required String uid,
      required int planId,
      required int stepIndex,
      required Milligrams fromDose,
      required Milligrams toDose,
      required LocalDate startDate,
      required StepStatus status,
      required int patternVersion,
    });
typedef $$StepsTableUpdateCompanionBuilder =
    StepsCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<int> planId,
      Value<int> stepIndex,
      Value<Milligrams> fromDose,
      Value<Milligrams> toDose,
      Value<LocalDate> startDate,
      Value<StepStatus> status,
      Value<int> patternVersion,
    });

class $$StepsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $StepsTable> {
  $$StepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stepIndex => $composableBuilder(
    column: $table.stepIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int> get fromDose =>
      $composableBuilder(
        column: $table.fromDose,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int> get toDose =>
      $composableBuilder(
        column: $table.toDose,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get startDate =>
      $composableBuilder(
        column: $table.startDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<StepStatus, StepStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get patternVersion => $composableBuilder(
    column: $table.patternVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StepsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $StepsTable> {
  $$StepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stepIndex => $composableBuilder(
    column: $table.stepIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromDose => $composableBuilder(
    column: $table.fromDose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toDose => $composableBuilder(
    column: $table.toDose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get patternVersion => $composableBuilder(
    column: $table.patternVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StepsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $StepsTable> {
  $$StepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<int> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<int> get stepIndex =>
      $composableBuilder(column: $table.stepIndex, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Milligrams, int> get fromDose =>
      $composableBuilder(column: $table.fromDose, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Milligrams, int> get toDose =>
      $composableBuilder(column: $table.toDose, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StepStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get patternVersion => $composableBuilder(
    column: $table.patternVersion,
    builder: (column) => column,
  );
}

class $$StepsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $StepsTable,
          StepRow,
          $$StepsTableFilterComposer,
          $$StepsTableOrderingComposer,
          $$StepsTableAnnotationComposer,
          $$StepsTableCreateCompanionBuilder,
          $$StepsTableUpdateCompanionBuilder,
          (StepRow, BaseReferences<_$AppDatabaseV2, $StepsTable, StepRow>),
          StepRow,
          PrefetchHooks Function()
        > {
  $$StepsTableTableManager(_$AppDatabaseV2 db, $StepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<int> stepIndex = const Value.absent(),
                Value<Milligrams> fromDose = const Value.absent(),
                Value<Milligrams> toDose = const Value.absent(),
                Value<LocalDate> startDate = const Value.absent(),
                Value<StepStatus> status = const Value.absent(),
                Value<int> patternVersion = const Value.absent(),
              }) => StepsCompanion(
                id: id,
                uid: uid,
                planId: planId,
                stepIndex: stepIndex,
                fromDose: fromDose,
                toDose: toDose,
                startDate: startDate,
                status: status,
                patternVersion: patternVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                required int planId,
                required int stepIndex,
                required Milligrams fromDose,
                required Milligrams toDose,
                required LocalDate startDate,
                required StepStatus status,
                required int patternVersion,
              }) => StepsCompanion.insert(
                id: id,
                uid: uid,
                planId: planId,
                stepIndex: stepIndex,
                fromDose: fromDose,
                toDose: toDose,
                startDate: startDate,
                status: status,
                patternVersion: patternVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StepsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $StepsTable,
      StepRow,
      $$StepsTableFilterComposer,
      $$StepsTableOrderingComposer,
      $$StepsTableAnnotationComposer,
      $$StepsTableCreateCompanionBuilder,
      $$StepsTableUpdateCompanionBuilder,
      (StepRow, BaseReferences<_$AppDatabaseV2, $StepsTable, StepRow>),
      StepRow,
      PrefetchHooks Function()
    >;
typedef $$DoseLogsV2TableCreateCompanionBuilder =
    DoseLogsV2Companion Function({
      Value<int> id,
      required String uid,
      required int planId,
      required LocalDate date,
      required Milligrams plannedMg,
      required Milligrams actualMg,
      required bool taken,
      Value<DateTime?> takenAt,
      Value<String?> note,
      Value<String?> recordedSource,
    });
typedef $$DoseLogsV2TableUpdateCompanionBuilder =
    DoseLogsV2Companion Function({
      Value<int> id,
      Value<String> uid,
      Value<int> planId,
      Value<LocalDate> date,
      Value<Milligrams> plannedMg,
      Value<Milligrams> actualMg,
      Value<bool> taken,
      Value<DateTime?> takenAt,
      Value<String?> note,
      Value<String?> recordedSource,
    });

class $$DoseLogsV2TableFilterComposer
    extends Composer<_$AppDatabaseV2, $DoseLogsV2Table> {
  $$DoseLogsV2TableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int> get plannedMg =>
      $composableBuilder(
        column: $table.plannedMg,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int> get actualMg =>
      $composableBuilder(
        column: $table.actualMg,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get taken => $composableBuilder(
    column: $table.taken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get takenAt =>
      $composableBuilder(
        column: $table.takenAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedSource => $composableBuilder(
    column: $table.recordedSource,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DoseLogsV2TableOrderingComposer
    extends Composer<_$AppDatabaseV2, $DoseLogsV2Table> {
  $$DoseLogsV2TableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedMg => $composableBuilder(
    column: $table.plannedMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualMg => $composableBuilder(
    column: $table.actualMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get taken => $composableBuilder(
    column: $table.taken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedSource => $composableBuilder(
    column: $table.recordedSource,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DoseLogsV2TableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $DoseLogsV2Table> {
  $$DoseLogsV2TableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<int> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Milligrams, int> get plannedMg =>
      $composableBuilder(column: $table.plannedMg, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Milligrams, int> get actualMg =>
      $composableBuilder(column: $table.actualMg, builder: (column) => column);

  GeneratedColumn<bool> get taken =>
      $composableBuilder(column: $table.taken, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get recordedSource => $composableBuilder(
    column: $table.recordedSource,
    builder: (column) => column,
  );
}

class $$DoseLogsV2TableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $DoseLogsV2Table,
          DoseLogV2Row,
          $$DoseLogsV2TableFilterComposer,
          $$DoseLogsV2TableOrderingComposer,
          $$DoseLogsV2TableAnnotationComposer,
          $$DoseLogsV2TableCreateCompanionBuilder,
          $$DoseLogsV2TableUpdateCompanionBuilder,
          (
            DoseLogV2Row,
            BaseReferences<_$AppDatabaseV2, $DoseLogsV2Table, DoseLogV2Row>,
          ),
          DoseLogV2Row,
          PrefetchHooks Function()
        > {
  $$DoseLogsV2TableTableManager(_$AppDatabaseV2 db, $DoseLogsV2Table table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DoseLogsV2TableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DoseLogsV2TableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DoseLogsV2TableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<LocalDate> date = const Value.absent(),
                Value<Milligrams> plannedMg = const Value.absent(),
                Value<Milligrams> actualMg = const Value.absent(),
                Value<bool> taken = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> recordedSource = const Value.absent(),
              }) => DoseLogsV2Companion(
                id: id,
                uid: uid,
                planId: planId,
                date: date,
                plannedMg: plannedMg,
                actualMg: actualMg,
                taken: taken,
                takenAt: takenAt,
                note: note,
                recordedSource: recordedSource,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                required int planId,
                required LocalDate date,
                required Milligrams plannedMg,
                required Milligrams actualMg,
                required bool taken,
                Value<DateTime?> takenAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> recordedSource = const Value.absent(),
              }) => DoseLogsV2Companion.insert(
                id: id,
                uid: uid,
                planId: planId,
                date: date,
                plannedMg: plannedMg,
                actualMg: actualMg,
                taken: taken,
                takenAt: takenAt,
                note: note,
                recordedSource: recordedSource,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DoseLogsV2TableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $DoseLogsV2Table,
      DoseLogV2Row,
      $$DoseLogsV2TableFilterComposer,
      $$DoseLogsV2TableOrderingComposer,
      $$DoseLogsV2TableAnnotationComposer,
      $$DoseLogsV2TableCreateCompanionBuilder,
      $$DoseLogsV2TableUpdateCompanionBuilder,
      (
        DoseLogV2Row,
        BaseReferences<_$AppDatabaseV2, $DoseLogsV2Table, DoseLogV2Row>,
      ),
      DoseLogV2Row,
      PrefetchHooks Function()
    >;
typedef $$FlareEventsTableCreateCompanionBuilder =
    FlareEventsCompanion Function({
      Value<int> id,
      required String uid,
      required int planId,
      required LocalDate date,
      required Milligrams revertToDose,
      Value<String?> note,
    });
typedef $$FlareEventsTableUpdateCompanionBuilder =
    FlareEventsCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<int> planId,
      Value<LocalDate> date,
      Value<Milligrams> revertToDose,
      Value<String?> note,
    });

class $$FlareEventsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $FlareEventsTable> {
  $$FlareEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Milligrams, Milligrams, int>
  get revertToDose => $composableBuilder(
    column: $table.revertToDose,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FlareEventsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $FlareEventsTable> {
  $$FlareEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revertToDose => $composableBuilder(
    column: $table.revertToDose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FlareEventsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $FlareEventsTable> {
  $$FlareEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<int> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Milligrams, int> get revertToDose =>
      $composableBuilder(
        column: $table.revertToDose,
        builder: (column) => column,
      );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$FlareEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $FlareEventsTable,
          FlareEventRow,
          $$FlareEventsTableFilterComposer,
          $$FlareEventsTableOrderingComposer,
          $$FlareEventsTableAnnotationComposer,
          $$FlareEventsTableCreateCompanionBuilder,
          $$FlareEventsTableUpdateCompanionBuilder,
          (
            FlareEventRow,
            BaseReferences<_$AppDatabaseV2, $FlareEventsTable, FlareEventRow>,
          ),
          FlareEventRow,
          PrefetchHooks Function()
        > {
  $$FlareEventsTableTableManager(_$AppDatabaseV2 db, $FlareEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlareEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlareEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlareEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<LocalDate> date = const Value.absent(),
                Value<Milligrams> revertToDose = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => FlareEventsCompanion(
                id: id,
                uid: uid,
                planId: planId,
                date: date,
                revertToDose: revertToDose,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                required int planId,
                required LocalDate date,
                required Milligrams revertToDose,
                Value<String?> note = const Value.absent(),
              }) => FlareEventsCompanion.insert(
                id: id,
                uid: uid,
                planId: planId,
                date: date,
                revertToDose: revertToDose,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FlareEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $FlareEventsTable,
      FlareEventRow,
      $$FlareEventsTableFilterComposer,
      $$FlareEventsTableOrderingComposer,
      $$FlareEventsTableAnnotationComposer,
      $$FlareEventsTableCreateCompanionBuilder,
      $$FlareEventsTableUpdateCompanionBuilder,
      (
        FlareEventRow,
        BaseReferences<_$AppDatabaseV2, $FlareEventsTable, FlareEventRow>,
      ),
      FlareEventRow,
      PrefetchHooks Function()
    >;
typedef $$HoldEventsTableCreateCompanionBuilder =
    HoldEventsCompanion Function({
      Value<int> id,
      required String uid,
      required int stepId,
      required LocalDate fromDate,
      required int extraDays,
      Value<String?> note,
    });
typedef $$HoldEventsTableUpdateCompanionBuilder =
    HoldEventsCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<int> stepId,
      Value<LocalDate> fromDate,
      Value<int> extraDays,
      Value<String?> note,
    });

class $$HoldEventsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $HoldEventsTable> {
  $$HoldEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stepId => $composableBuilder(
    column: $table.stepId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get fromDate =>
      $composableBuilder(
        column: $table.fromDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get extraDays => $composableBuilder(
    column: $table.extraDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldEventsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $HoldEventsTable> {
  $$HoldEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stepId => $composableBuilder(
    column: $table.stepId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromDate => $composableBuilder(
    column: $table.fromDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get extraDays => $composableBuilder(
    column: $table.extraDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldEventsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $HoldEventsTable> {
  $$HoldEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<int> get stepId =>
      $composableBuilder(column: $table.stepId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get fromDate =>
      $composableBuilder(column: $table.fromDate, builder: (column) => column);

  GeneratedColumn<int> get extraDays =>
      $composableBuilder(column: $table.extraDays, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$HoldEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $HoldEventsTable,
          HoldEventRow,
          $$HoldEventsTableFilterComposer,
          $$HoldEventsTableOrderingComposer,
          $$HoldEventsTableAnnotationComposer,
          $$HoldEventsTableCreateCompanionBuilder,
          $$HoldEventsTableUpdateCompanionBuilder,
          (
            HoldEventRow,
            BaseReferences<_$AppDatabaseV2, $HoldEventsTable, HoldEventRow>,
          ),
          HoldEventRow,
          PrefetchHooks Function()
        > {
  $$HoldEventsTableTableManager(_$AppDatabaseV2 db, $HoldEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<int> stepId = const Value.absent(),
                Value<LocalDate> fromDate = const Value.absent(),
                Value<int> extraDays = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => HoldEventsCompanion(
                id: id,
                uid: uid,
                stepId: stepId,
                fromDate: fromDate,
                extraDays: extraDays,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                required int stepId,
                required LocalDate fromDate,
                required int extraDays,
                Value<String?> note = const Value.absent(),
              }) => HoldEventsCompanion.insert(
                id: id,
                uid: uid,
                stepId: stepId,
                fromDate: fromDate,
                extraDays: extraDays,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $HoldEventsTable,
      HoldEventRow,
      $$HoldEventsTableFilterComposer,
      $$HoldEventsTableOrderingComposer,
      $$HoldEventsTableAnnotationComposer,
      $$HoldEventsTableCreateCompanionBuilder,
      $$HoldEventsTableUpdateCompanionBuilder,
      (
        HoldEventRow,
        BaseReferences<_$AppDatabaseV2, $HoldEventsTable, HoldEventRow>,
      ),
      HoldEventRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsRowsTableCreateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      required String uid,
      Value<bool> reminderEnabled,
      Value<int?> reminderMinuteOfDay,
      Value<double> textScale,
      Value<bool> highContrast,
      Value<DateTime?> disclaimerAcceptedAt,
      Value<String?> localeTag,
      Value<String> themeMode,
    });
typedef $$SettingsRowsTableUpdateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<bool> reminderEnabled,
      Value<int?> reminderMinuteOfDay,
      Value<double> textScale,
      Value<bool> highContrast,
      Value<DateTime?> disclaimerAcceptedAt,
      Value<String?> localeTag,
      Value<String> themeMode,
    });

class $$SettingsRowsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $SettingsRowsTable> {
  $$SettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinuteOfDay => $composableBuilder(
    column: $table.reminderMinuteOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get highContrast => $composableBuilder(
    column: $table.highContrast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get disclaimerAcceptedAt => $composableBuilder(
    column: $table.disclaimerAcceptedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get localeTag => $composableBuilder(
    column: $table.localeTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsRowsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $SettingsRowsTable> {
  $$SettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinuteOfDay => $composableBuilder(
    column: $table.reminderMinuteOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get highContrast => $composableBuilder(
    column: $table.highContrast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get disclaimerAcceptedAt => $composableBuilder(
    column: $table.disclaimerAcceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localeTag => $composableBuilder(
    column: $table.localeTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $SettingsRowsTable> {
  $$SettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinuteOfDay => $composableBuilder(
    column: $table.reminderMinuteOfDay,
    builder: (column) => column,
  );

  GeneratedColumn<double> get textScale =>
      $composableBuilder(column: $table.textScale, builder: (column) => column);

  GeneratedColumn<bool> get highContrast => $composableBuilder(
    column: $table.highContrast,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get disclaimerAcceptedAt =>
      $composableBuilder(
        column: $table.disclaimerAcceptedAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get localeTag =>
      $composableBuilder(column: $table.localeTag, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);
}

class $$SettingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $SettingsRowsTable,
          SettingsRow,
          $$SettingsRowsTableFilterComposer,
          $$SettingsRowsTableOrderingComposer,
          $$SettingsRowsTableAnnotationComposer,
          $$SettingsRowsTableCreateCompanionBuilder,
          $$SettingsRowsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabaseV2, $SettingsRowsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsRowsTableTableManager(_$AppDatabaseV2 db, $SettingsRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int?> reminderMinuteOfDay = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<bool> highContrast = const Value.absent(),
                Value<DateTime?> disclaimerAcceptedAt = const Value.absent(),
                Value<String?> localeTag = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
              }) => SettingsRowsCompanion(
                id: id,
                uid: uid,
                reminderEnabled: reminderEnabled,
                reminderMinuteOfDay: reminderMinuteOfDay,
                textScale: textScale,
                highContrast: highContrast,
                disclaimerAcceptedAt: disclaimerAcceptedAt,
                localeTag: localeTag,
                themeMode: themeMode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int?> reminderMinuteOfDay = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<bool> highContrast = const Value.absent(),
                Value<DateTime?> disclaimerAcceptedAt = const Value.absent(),
                Value<String?> localeTag = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
              }) => SettingsRowsCompanion.insert(
                id: id,
                uid: uid,
                reminderEnabled: reminderEnabled,
                reminderMinuteOfDay: reminderMinuteOfDay,
                textScale: textScale,
                highContrast: highContrast,
                disclaimerAcceptedAt: disclaimerAcceptedAt,
                localeTag: localeTag,
                themeMode: themeMode,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $SettingsRowsTable,
      SettingsRow,
      $$SettingsRowsTableFilterComposer,
      $$SettingsRowsTableOrderingComposer,
      $$SettingsRowsTableAnnotationComposer,
      $$SettingsRowsTableCreateCompanionBuilder,
      $$SettingsRowsTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$AppDatabaseV2, $SettingsRowsTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseV2Manager {
  final _$AppDatabaseV2 _db;
  $AppDatabaseV2Manager(this._db);
  $$TaperPlansTableTableManager get taperPlans =>
      $$TaperPlansTableTableManager(_db, _db.taperPlans);
  $$StepsTableTableManager get steps =>
      $$StepsTableTableManager(_db, _db.steps);
  $$DoseLogsV2TableTableManager get doseLogsV2 =>
      $$DoseLogsV2TableTableManager(_db, _db.doseLogsV2);
  $$FlareEventsTableTableManager get flareEvents =>
      $$FlareEventsTableTableManager(_db, _db.flareEvents);
  $$HoldEventsTableTableManager get holdEvents =>
      $$HoldEventsTableTableManager(_db, _db.holdEvents);
  $$SettingsRowsTableTableManager get settingsRows =>
      $$SettingsRowsTableTableManager(_db, _db.settingsRows);
}
