import 'network.dart';
import 'scenario.dart';

/// A simulation result as returned by the server, stored with the request it answers.
class StoredResult {
  final String jobId;
  final String serverUrl;
  final DateTime completedAt;

  /// Fingerprint of the request JSON that produced this result; used to flag stale results.
  final String requestFingerprint;
  final Map<String, dynamic> result;

  const StoredResult({
    required this.jobId,
    required this.serverUrl,
    required this.completedAt,
    required this.requestFingerprint,
    required this.result,
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'serverUrl': serverUrl,
        'completedAt': completedAt.toIso8601String(),
        'requestFingerprint': requestFingerprint,
        'result': result,
      };

  factory StoredResult.fromJson(Map<String, dynamic> j) => StoredResult(
        jobId: j['jobId'] as String,
        serverUrl: j['serverUrl'] as String? ?? '',
        completedAt: DateTime.parse(j['completedAt'] as String),
        requestFingerprint: j['requestFingerprint'] as String,
        result: j['result'] as Map<String, dynamic>,
      );
}

/// One design alternative of a project (e.g. "existing", "added lane").
class Variant {
  final String id;
  final String name;
  final Network network;
  final Demand demand;
  final SignalSettings signals;
  final DriverSettings drivers;
  final RunSettings run;
  final StoredResult? lastResult;

  Variant({
    required this.id,
    required this.name,
    Network? network,
    this.demand = const Demand(),
    this.signals = const SignalSettings(),
    this.drivers = const DriverSettings(),
    this.run = const RunSettings(),
    this.lastResult,
  }) : network = network ?? Network.empty;

  Variant copyWith({
    String? id,
    String? name,
    Network? network,
    Demand? demand,
    SignalSettings? signals,
    DriverSettings? drivers,
    RunSettings? run,
    StoredResult? lastResult,
    bool clearResult = false,
  }) =>
      Variant(
        id: id ?? this.id,
        name: name ?? this.name,
        network: network ?? this.network,
        demand: demand ?? this.demand,
        signals: signals ?? this.signals,
        drivers: drivers ?? this.drivers,
        run: run ?? this.run,
        lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'network': network.toJson(),
        'demand': demand.toJson(),
        'signals': signals.toJson(),
        'drivers': drivers.toJson(),
        'run': run.toJson(),
        if (lastResult != null) 'lastResult': lastResult!.toJson(),
      };

  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: j['id'] as String,
        name: j['name'] as String,
        network: Network.fromJson(j['network'] as Map<String, dynamic>),
        demand: Demand.fromJson((j['demand'] as Map<String, dynamic>?) ?? const {}),
        signals: SignalSettings.fromJson((j['signals'] as Map<String, dynamic>?) ?? const {}),
        drivers: DriverSettings.fromJson((j['drivers'] as Map<String, dynamic>?) ?? const {}),
        run: RunSettings.fromJson((j['run'] as Map<String, dynamic>?) ?? const {}),
        lastResult: j['lastResult'] == null ? null : StoredResult.fromJson(j['lastResult'] as Map<String, dynamic>),
      );
}

class Project {
  static const formatVersion = 1;

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Variant> variants;
  final String activeVariantId;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.variants,
    required this.activeVariantId,
  }) : assert(variants.isNotEmpty);

  Variant get active => variants.firstWhere((v) => v.id == activeVariantId, orElse: () => variants.first);

  Project copyWith({String? name, DateTime? updatedAt, List<Variant>? variants, String? activeVariantId}) => Project(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        variants: variants ?? this.variants,
        activeVariantId: activeVariantId ?? this.activeVariantId,
      );

  Project replaceVariant(Variant v) =>
      copyWith(variants: [for (final x in variants) x.id == v.id ? v : x], updatedAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'activeVariantId': activeVariantId,
        'variants': variants.map((v) => v.toJson()).toList(),
      };

  factory Project.fromJson(Map<String, dynamic> j) {
    final variants = (j['variants'] as List).map((v) => Variant.fromJson(v as Map<String, dynamic>)).toList();
    return Project(
      id: j['id'] as String,
      name: j['name'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      variants: variants,
      activeVariantId: j['activeVariantId'] as String? ?? variants.first.id,
    );
  }
}
