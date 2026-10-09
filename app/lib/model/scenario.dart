/// Traffic demand, signal, driver and run settings of one design variant.
library;

enum DemandSource { observed, assumed }

class VehicleMix {
  final double car;
  final double truck;
  final double bus;
  const VehicleMix({this.car = 0.9, this.truck = 0.08, this.bus = 0.02});

  double get total => car + truck + bus;

  VehicleMix copyWith({double? car, double? truck, double? bus}) =>
      VehicleMix(car: car ?? this.car, truck: truck ?? this.truck, bus: bus ?? this.bus);

  Map<String, dynamic> toJson() => {'car': car, 'truck': truck, 'bus': bus};
  factory VehicleMix.fromJson(Map<String, dynamic> j) => VehicleMix(
        car: (j['car'] as num).toDouble(),
        truck: (j['truck'] as num).toDouble(),
        bus: (j['bus'] as num).toDouble(),
      );
}

class OriginDemand {
  final double flowVehPerHour;
  final VehicleMix mix;

  /// Destination node id -> share (0..1). Missing destinations get 0.
  final Map<String, double> shares;

  const OriginDemand({this.flowVehPerHour = 0, this.mix = const VehicleMix(), this.shares = const {}});

  double get shareTotal => shares.values.fold(0.0, (a, b) => a + b);

  OriginDemand copyWith({double? flowVehPerHour, VehicleMix? mix, Map<String, double>? shares}) => OriginDemand(
        flowVehPerHour: flowVehPerHour ?? this.flowVehPerHour,
        mix: mix ?? this.mix,
        shares: shares ?? this.shares,
      );

  Map<String, dynamic> toJson() => {'flowVehPerHour': flowVehPerHour, 'mix': mix.toJson(), 'shares': shares};
  factory OriginDemand.fromJson(Map<String, dynamic> j) => OriginDemand(
        flowVehPerHour: (j['flowVehPerHour'] as num).toDouble(),
        mix: VehicleMix.fromJson(j['mix'] as Map<String, dynamic>),
        shares: ((j['shares'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      );
}

class Demand {
  final DemandSource source;
  final String note;
  final bool poissonArrivals;

  /// Origin node id -> demand.
  final Map<String, OriginDemand> origins;

  const Demand({this.source = DemandSource.assumed, this.note = '', this.poissonArrivals = true, this.origins = const {}});

  Demand copyWith({DemandSource? source, String? note, bool? poissonArrivals, Map<String, OriginDemand>? origins}) =>
      Demand(
        source: source ?? this.source,
        note: note ?? this.note,
        poissonArrivals: poissonArrivals ?? this.poissonArrivals,
        origins: origins ?? this.origins,
      );

  double get totalFlow => origins.values.fold(0.0, (a, o) => a + o.flowVehPerHour);

  Map<String, dynamic> toJson() => {
        'source': source.name,
        'note': note,
        'poissonArrivals': poissonArrivals,
        'origins': origins.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Demand.fromJson(Map<String, dynamic> j) => Demand(
        source: j['source'] == 'observed' ? DemandSource.observed : DemandSource.assumed,
        note: j['note'] as String? ?? '',
        poissonArrivals: j['poissonArrivals'] as bool? ?? true,
        origins: ((j['origins'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, OriginDemand.fromJson(v as Map<String, dynamic>))),
      );
}

class SignalSettings {
  final int cycleTimeS;
  final int? yellowTimeS;
  final int allRedTimeS;
  final String layout; // opposites | incoming
  final int leftTurnGreenS;

  const SignalSettings({
    this.cycleTimeS = 90,
    this.yellowTimeS,
    this.allRedTimeS = 0,
    this.layout = 'opposites',
    this.leftTurnGreenS = 6,
  });

  SignalSettings copyWith({
    int? cycleTimeS,
    int? yellowTimeS,
    bool autoYellow = false,
    int? allRedTimeS,
    String? layout,
    int? leftTurnGreenS,
  }) =>
      SignalSettings(
        cycleTimeS: cycleTimeS ?? this.cycleTimeS,
        yellowTimeS: autoYellow ? null : (yellowTimeS ?? this.yellowTimeS),
        allRedTimeS: allRedTimeS ?? this.allRedTimeS,
        layout: layout ?? this.layout,
        leftTurnGreenS: leftTurnGreenS ?? this.leftTurnGreenS,
      );

  Map<String, dynamic> toJson() => {
        'cycleTimeS': cycleTimeS,
        if (yellowTimeS != null) 'yellowTimeS': yellowTimeS,
        'allRedTimeS': allRedTimeS,
        'layout': layout,
        'leftTurnGreenS': leftTurnGreenS,
      };

  factory SignalSettings.fromJson(Map<String, dynamic> j) => SignalSettings(
        cycleTimeS: (j['cycleTimeS'] as num?)?.toInt() ?? 90,
        yellowTimeS: (j['yellowTimeS'] as num?)?.toInt(),
        allRedTimeS: (j['allRedTimeS'] as num?)?.toInt() ?? 0,
        layout: j['layout'] as String? ?? 'opposites',
        leftTurnGreenS: (j['leftTurnGreenS'] as num?)?.toInt() ?? 6,
      );
}

class DriverSettings {
  final String carFollowModel; // EIDM | IDM | Krauss
  final bool heterogeneity;
  final double reactionTimeMinS;
  final double reactionTimeMaxS;

  /// Gap-acceptance willingness (SUMO `impatience`); 0.5 matches HCM capacities in the benchmarks.
  final double impatience;

  /// Enforce a full halt of every vehicle at stop signs (SUMO strict stop).
  final bool stopSignFullStop;

  const DriverSettings({
    this.carFollowModel = 'EIDM',
    this.heterogeneity = true,
    this.reactionTimeMinS = 0.5,
    this.reactionTimeMaxS = 1.0,
    this.impatience = 0.5,
    this.stopSignFullStop = false,
  });

  DriverSettings copyWith({
    String? carFollowModel,
    bool? heterogeneity,
    double? reactionTimeMinS,
    double? reactionTimeMaxS,
    double? impatience,
    bool? stopSignFullStop,
  }) =>
      DriverSettings(
        carFollowModel: carFollowModel ?? this.carFollowModel,
        heterogeneity: heterogeneity ?? this.heterogeneity,
        reactionTimeMinS: reactionTimeMinS ?? this.reactionTimeMinS,
        reactionTimeMaxS: reactionTimeMaxS ?? this.reactionTimeMaxS,
        impatience: impatience ?? this.impatience,
        stopSignFullStop: stopSignFullStop ?? this.stopSignFullStop,
      );

  Map<String, dynamic> toJson() => {
        'carFollowModel': carFollowModel,
        'heterogeneity': heterogeneity,
        'reactionTimeMinS': reactionTimeMinS,
        'reactionTimeMaxS': reactionTimeMaxS,
        'impatience': impatience,
        'stopSignFullStop': stopSignFullStop,
      };

  factory DriverSettings.fromJson(Map<String, dynamic> j) => DriverSettings(
        carFollowModel: j['carFollowModel'] as String? ?? 'EIDM',
        heterogeneity: j['heterogeneity'] as bool? ?? true,
        reactionTimeMinS: (j['reactionTimeMinS'] as num?)?.toDouble() ?? 0.5,
        reactionTimeMaxS: (j['reactionTimeMaxS'] as num?)?.toDouble() ?? 1.0,
        impatience: (j['impatience'] as num?)?.toDouble() ?? 0.5,
        stopSignFullStop: j['stopSignFullStop'] as bool? ?? false,
      );
}

class RunSettings {
  final double durationS;
  final double warmupS;
  final double stepLengthS;
  final int replications;
  final int baseSeed;
  final bool trajectory;
  final double trajectoryPeriodS;
  final double trajectoryMaxS;

  const RunSettings({
    this.durationS = 3600,
    this.warmupS = 600,
    this.stepLengthS = 0.2,
    this.replications = 5,
    this.baseSeed = 1,
    this.trajectory = true,
    this.trajectoryPeriodS = 0.4,
    this.trajectoryMaxS = 900,
  });

  RunSettings copyWith({
    double? durationS,
    double? warmupS,
    double? stepLengthS,
    int? replications,
    int? baseSeed,
    bool? trajectory,
    double? trajectoryPeriodS,
    double? trajectoryMaxS,
  }) =>
      RunSettings(
        durationS: durationS ?? this.durationS,
        warmupS: warmupS ?? this.warmupS,
        stepLengthS: stepLengthS ?? this.stepLengthS,
        replications: replications ?? this.replications,
        baseSeed: baseSeed ?? this.baseSeed,
        trajectory: trajectory ?? this.trajectory,
        trajectoryPeriodS: trajectoryPeriodS ?? this.trajectoryPeriodS,
        trajectoryMaxS: trajectoryMaxS ?? this.trajectoryMaxS,
      );

  Map<String, dynamic> toJson() => {
        'durationS': durationS,
        'warmupS': warmupS,
        'stepLengthS': stepLengthS,
        'replications': replications,
        'baseSeed': baseSeed,
        'trajectory': trajectory,
        'trajectoryPeriodS': trajectoryPeriodS,
        'trajectoryMaxS': trajectoryMaxS,
      };

  factory RunSettings.fromJson(Map<String, dynamic> j) => RunSettings(
        durationS: (j['durationS'] as num?)?.toDouble() ?? 3600,
        warmupS: (j['warmupS'] as num?)?.toDouble() ?? 600,
        stepLengthS: (j['stepLengthS'] as num?)?.toDouble() ?? 0.2,
        replications: (j['replications'] as num?)?.toInt() ?? 5,
        baseSeed: (j['baseSeed'] as num?)?.toInt() ?? 1,
        trajectory: j['trajectory'] as bool? ?? true,
        trajectoryPeriodS: (j['trajectoryPeriodS'] as num?)?.toDouble() ?? 0.4,
        trajectoryMaxS: (j['trajectoryMaxS'] as num?)?.toDouble() ?? 900,
      );
}
