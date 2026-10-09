// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RoadFlow AI';

  @override
  String get appTagline => 'Road design and microscopic traffic simulation';

  @override
  String get otherLanguage => 'العربية';

  @override
  String get projects => 'Projects';

  @override
  String get newProject => 'New project';

  @override
  String get newProjectDefaultName => 'Untitled study';

  @override
  String get projectName => 'Project name';

  @override
  String get startFrom => 'Start from';

  @override
  String get templateBlank => 'Blank canvas';

  @override
  String get templateSignalised => '4-arm signalised intersection';

  @override
  String get templateTJunction => 'T-junction (stop on minor road)';

  @override
  String get templateRoundabout => 'Roundabout';

  @override
  String get templateDemandNote =>
      'Templates include an assumed demand scenario (labelled as assumed) so a first run is possible. Replace it with observed counts for real studies.';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get clear => 'Clear';

  @override
  String get deleteProject => 'Delete project';

  @override
  String deleteProjectConfirm(String name) {
    return 'Delete \"$name\" and all its variants? This cannot be undone.';
  }

  @override
  String get projectLoadFailed => 'The project could not be opened.';

  @override
  String get noProjects => 'No projects yet';

  @override
  String get noProjectsHint =>
      'Create a project to start designing roads and intersections.';

  @override
  String variantsCount(int count) {
    return 'Design variants: $count';
  }

  @override
  String lastModified(String date) {
    return 'Modified $date';
  }

  @override
  String get variantExisting => 'Existing';

  @override
  String get serverSettings => 'Simulation server';

  @override
  String get serverExplanation =>
      'Design work is stored on this device and works offline. Simulations run on the RoadFlow server (SUMO). Use HTTPS outside a trusted network.';

  @override
  String get serverUrl => 'Server address';

  @override
  String get apiToken => 'Access token (optional)';

  @override
  String get insecureServer =>
      'Unencrypted (http) connection: designs and results travel in clear text. Use https outside a trusted local network.';

  @override
  String get testConnection => 'Test connection';

  @override
  String serverOk(String engine, String version) {
    return 'Connected: $engine (server $version)';
  }

  @override
  String serverUnreachable(String error) {
    return 'Cannot reach the server: $error';
  }

  @override
  String serverLine(String url) {
    return 'Server: $url';
  }

  @override
  String get saved => 'Saved';

  @override
  String get saving => 'Saving…';

  @override
  String get saveFailed => 'Saving failed';

  @override
  String get renameProject => 'Rename project';

  @override
  String get modeDesign => 'Design';

  @override
  String get modeSimulation => 'Simulation';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get fitToView => 'Fit to view';

  @override
  String get hidePanel => 'Hide panel';

  @override
  String get showPanel => 'Show panel';

  @override
  String get variantActions => 'Design variants';

  @override
  String get duplicateVariant => 'Duplicate as new variant';

  @override
  String get renameVariant => 'Rename variant';

  @override
  String get deleteVariant => 'Delete variant';

  @override
  String variantCopyName(String name) {
    return '$name – alternative';
  }

  @override
  String get cannotDeleteLastVariant => 'A project needs at least one variant.';

  @override
  String get toolSelect => 'Select';

  @override
  String get toolRoad => 'Road';

  @override
  String get toolCurve => 'Curve';

  @override
  String get toolJunction => 'Junction';

  @override
  String get toolMeasure => 'Measure';

  @override
  String get deleteSelection => 'Delete selected';

  @override
  String get lanesForwardShort => 'Lanes →';

  @override
  String get lanesBackwardShort => 'Lanes ←';

  @override
  String get speedLimit => 'Speed limit';

  @override
  String get optAutoJunctions => 'Junctions at crossings';

  @override
  String get optGridSnap => 'Grid snap';

  @override
  String get optAngleSnap => '15° angles';

  @override
  String get optPenOnly => 'Draw with pen only';

  @override
  String get templateFourWaySignal => '4-arm, signals';

  @override
  String get templateTStop => 'T-junction, stop';

  @override
  String get armLength => 'Arm length';

  @override
  String get hintTapToPlace => 'Tap the canvas to place';

  @override
  String get hintMeasure => 'Tap points to measure length, angles and area';

  @override
  String get hintSelect =>
      'Tap to select · drag nodes to move · two fingers to pan and zoom';

  @override
  String measureLength(String m) {
    return 'Length $m m';
  }

  @override
  String measureBearing(String deg) {
    return 'Bearing $deg°';
  }

  @override
  String measureAngle(String deg) {
    return 'Angle $deg°';
  }

  @override
  String measureArea(String m2) {
    return 'Area $m2 m²';
  }

  @override
  String get tabProperties => 'Properties';

  @override
  String get tabDemand => 'Traffic';

  @override
  String get tabSimulation => 'Simulate';

  @override
  String get tabResults => 'Results';

  @override
  String get propertiesHint =>
      'Select a road or junction on the canvas to edit it. Draw roads with the Road or Curve tool; junctions are created where roads meet.';

  @override
  String get networkSettings => 'Network';

  @override
  String get drivingSide => 'Driving side';

  @override
  String get drivingRight => 'Right-hand (e.g. Qatar)';

  @override
  String get drivingLeft => 'Left-hand';

  @override
  String get allowUTurns => 'Allow U-turns at junctions';

  @override
  String get allowUTurnsHint => 'Applies to every junction in this variant.';

  @override
  String get newRoadDefaults => 'New road defaults';

  @override
  String get lanesForward => 'Lanes in drawing direction';

  @override
  String get lanesBackward => 'Lanes in opposite direction';

  @override
  String get laneWidth => 'Lane width';

  @override
  String get defaultsNotStandards =>
      'Editor defaults only: they are not design-standard values. Enter the dimensions required by the applicable manual.';

  @override
  String get networkSummary => 'Summary';

  @override
  String summaryCounts(int nodes, int roads) {
    return '$nodes nodes · $roads road segments';
  }

  @override
  String summaryLength(String km) {
    return 'Total centreline length: $km km';
  }

  @override
  String gateTitle(String id) {
    return 'Road end $id';
  }

  @override
  String nodeTitle(String id) {
    return 'Junction $id';
  }

  @override
  String nodeDegree(int n) {
    return 'Connected road segments: $n';
  }

  @override
  String get name => 'Name';

  @override
  String get elevation => 'Elevation';

  @override
  String get junctionControl => 'Junction control';

  @override
  String get controlPriority => 'Priority (give way)';

  @override
  String get controlPriorityStop => 'Stop on minor road';

  @override
  String get controlTrafficLight => 'Traffic signals';

  @override
  String get controlAllwayStop => 'All-way stop';

  @override
  String get controlRightBeforeLeft => 'Uncontrolled (right before left)';

  @override
  String get controlRoundabout => 'Roundabout';

  @override
  String get helpPriority =>
      'The major road (higher priority / speed / lanes) has right of way; minor approaches yield.';

  @override
  String get helpPriorityStop =>
      'Minor approaches must stop, then enter when a gap is accepted.';

  @override
  String get helpTrafficLight =>
      'Fixed-time plan generated from the Simulate tab settings; the plan used is shown in playback.';

  @override
  String get helpAllwayStop => 'Every approach stops before entering.';

  @override
  String get helpRightBeforeLeft =>
      'No priority road: traffic from the right goes first.';

  @override
  String get helpRoundabout =>
      'Circulating traffic has priority; entries yield. Counter-clockwise for right-hand traffic.';

  @override
  String get roundaboutRadius => 'Radius to circulating centreline';

  @override
  String get roundaboutRadiusHelp =>
      'Approach roads are connected where they cross this circle.';

  @override
  String get circulatingLanes => 'Circulating lanes';

  @override
  String get circulatingSpeed => 'Circulating speed limit';

  @override
  String roadTitle(String id) {
    return 'Road segment $id';
  }

  @override
  String get reverseDirection => 'Swap directions';

  @override
  String get splitRoad => 'Split in the middle';

  @override
  String roadGeometry(String len, String grade) {
    return 'Length $len m · grade $grade %';
  }

  @override
  String get gradeNote =>
      'Grade from end-node elevations. Elevations are passed to the simulation; the visual 3D model comes in phase 3.';

  @override
  String get roadPriority => 'Road hierarchy at junctions';

  @override
  String get priorityAuto => 'Automatic';

  @override
  String get priorityMajor => 'Major';

  @override
  String get priorityMinor => 'Minor';

  @override
  String get directionForward => 'Drawing direction';

  @override
  String get directionBackward => 'Opposite direction';

  @override
  String towardNode(String node) {
    return 'Traffic toward $node';
  }

  @override
  String get throughLanes => 'Through lanes';

  @override
  String get leftTurnBay => 'Left-turn bay';

  @override
  String get rightTurnBay => 'Right-turn bay';

  @override
  String get lanes => 'Lanes';

  @override
  String get storageLength => 'Storage length';

  @override
  String get oneWayInfo =>
      'One-way road: set the lane count of one direction to zero.';

  @override
  String get demandSource => 'Data source';

  @override
  String get sourceObserved => 'Observed counts';

  @override
  String get sourceAssumed => 'Assumed scenario';

  @override
  String get sourceObservedHelp =>
      'Use for volumes counted in the field. Record the survey date, period and method in the note; results are labelled as based on observed demand.';

  @override
  String get sourceAssumedHelp =>
      'Use for hypothetical or forecast volumes. Results are labelled as based on assumed demand and must not be presented as measurements.';

  @override
  String get sourceNote => 'Source note';

  @override
  String get sourceNoteHint => 'e.g. manual count, 2025-03-04, 07:00–08:00';

  @override
  String get poissonArrivals => 'Random (Poisson) arrivals';

  @override
  String get poissonArrivalsHelp =>
      'Off: vehicles arrive at evenly spaced intervals.';

  @override
  String get noEntriesYet =>
      'Draw roads first: traffic enters and leaves the model at road ends (green circles).';

  @override
  String totalDemand(String flow) {
    return 'Total entering demand: $flow veh/h';
  }

  @override
  String entryFrom(String name) {
    return 'Entry: $name';
  }

  @override
  String get flowVehPerHour => 'Entering flow';

  @override
  String get vehPerHour => 'veh/h';

  @override
  String get vehicleMix => 'Vehicle mix';

  @override
  String get cars => 'Cars';

  @override
  String get trucks => 'Trucks';

  @override
  String get buses => 'Buses';

  @override
  String mixMustBe100(String sum) {
    return 'Mix must total 100% (now $sum%)';
  }

  @override
  String get destinationsTitle => 'Turning / destination shares';

  @override
  String get equalSplit => 'Equal';

  @override
  String get normalize => 'Scale to 100%';

  @override
  String shareTotal(String sum) {
    return 'Total $sum%';
  }

  @override
  String get turnLeft => 'Left';

  @override
  String get turnThrough => 'Through';

  @override
  String get turnRight => 'Right';

  @override
  String get turnU => 'U-turn';

  @override
  String get runSimulation => 'Run simulation';

  @override
  String runButton(int n) {
    return 'Simulate ($n replications)';
  }

  @override
  String get phaseSubmitting => 'Sending design to the server…';

  @override
  String phaseRunning(String pct, String msg) {
    return 'Simulating… $pct% $msg';
  }

  @override
  String get stageQueued => 'waiting for a free simulator';

  @override
  String get stageBuilding => 'building the SUMO network';

  @override
  String get stageRunning => 'running replications';

  @override
  String get stageAnalysing => 'computing results';

  @override
  String get phaseFetching => 'Downloading results and trajectories…';

  @override
  String get simulationFailed => 'The simulation did not complete:';

  @override
  String get simulationDone =>
      'Simulation finished. All figures come from this run.';

  @override
  String get viewResults => 'View';

  @override
  String get validateDesign => 'Check design with SUMO (no traffic)';

  @override
  String get validationOk => 'SUMO built the network without warnings.';

  @override
  String get validationOkWithWarnings =>
      'SUMO built the network with warnings:';

  @override
  String get runSettings => 'Run settings';

  @override
  String get duration => 'Duration';

  @override
  String get warmup => 'Warm-up';

  @override
  String get warmupHelp =>
      'Warm-up fills the network and is excluded from all statistics.';

  @override
  String get replications => 'Replications';

  @override
  String get baseSeed => 'First random seed';

  @override
  String get replicationsHelp =>
      'Each replication uses a different seed; results show the mean and 95% confidence interval. Compare variants with the same seeds.';

  @override
  String get timeStep => 'Simulation time step';

  @override
  String get recordPlayback => 'Record vehicle positions for playback';

  @override
  String recordPlaybackHelp(String min) {
    return 'First $min min of replication 1, exactly as simulated.';
  }

  @override
  String get playbackWindow => 'Playback window';

  @override
  String get driverBehaviour => 'Driver behaviour';

  @override
  String get carFollowingModel => 'Car-following model';

  @override
  String get modelEidm => 'EIDM – Extended IDM (default)';

  @override
  String get modelIdm => 'IDM – Intelligent Driver Model';

  @override
  String get modelKrauss => 'Krauss (SUMO default)';

  @override
  String get carFollowingHelp =>
      'EIDM adds reaction time, estimation errors and jerk limits to IDM. Parameters are SUMO defaults until calibrated with local data.';

  @override
  String get driverHeterogeneity => 'Different driver profiles';

  @override
  String get driverHeterogeneityHelp =>
      'Varies headway, gaps, acceleration, speed choice and reaction time between drivers (assumed spreads).';

  @override
  String get gapAcceptance => 'Gap acceptance (SUMO impatience, 0–1)';

  @override
  String get gapAcceptanceHelp =>
      '0.5 reproduces HCM 6th Ed. give-way and roundabout entry capacities in the benchmark suite; SUMO\'s own default (0) gives 15–30% of them. Calibrate with local data when available.';

  @override
  String get strictStop => 'Strict full stop at stop signs';

  @override
  String get strictStopHelp =>
      'Off (default): stop-controlled approaches use field-calibrated gap behaviour, as in HCM. On: every vehicle halts at the line, which in SUMO discharges at about 45% of observed rates.';

  @override
  String get reactionMin => 'Reaction time min';

  @override
  String get reactionMax => 'Reaction time max';

  @override
  String get signalTiming => 'Signal timing';

  @override
  String get signalTimingHelp =>
      'Fixed-time plan generated for all signalised junctions. Phase-by-phase editing comes in phase 2.';

  @override
  String get cycleTime => 'Cycle time';

  @override
  String get autoYellow => 'Yellow time from approach speed (SUMO)';

  @override
  String get yellowTime => 'Yellow time';

  @override
  String get allRedTime => 'All-red time';

  @override
  String get leftGreen => 'Protected left-turn green';

  @override
  String get leftGreenHelp =>
      'Used where left-turn lanes exist; 0 = no protected left phase.';

  @override
  String get phaseLayout => 'Phase layout';

  @override
  String get layoutOpposites => 'Opposing approaches together';

  @override
  String get layoutIncoming => 'One approach at a time (split phasing)';

  @override
  String get noResultsYet =>
      'No results yet. Set up traffic and run a simulation from the Simulate tab.';

  @override
  String get resultsStale =>
      'The design or settings changed after this run. Run again to update the results.';

  @override
  String get reliability => 'Reliability';

  @override
  String resultMeta(String date, int n, String duration, String warmup) {
    return 'Run $date · $n replications · $duration simulated, $warmup warm-up excluded';
  }

  @override
  String get demandWasObserved => 'Demand: observed counts';

  @override
  String get demandWasAssumed => 'Demand: assumed scenario (not measurements)';

  @override
  String get kpiDelay => 'Average delay';

  @override
  String get kpiThroughput => 'Throughput';

  @override
  String get kpiMaxQueue => 'Longest queue';

  @override
  String get kpiWorstAvgQueue => 'Average queue, worst approach';

  @override
  String get kpiTravelTime => 'Travel time';

  @override
  String get kpiSpeed => 'Average speed';

  @override
  String get kpiStops => 'Stops per vehicle';

  @override
  String get kpiCompleted => 'Vehicles measured';

  @override
  String get unitSecPerVeh => 's/veh';

  @override
  String get perReplication => 'per replication';

  @override
  String get ci95 => '95% CI';

  @override
  String get singleRun => 'single replication: no interval';

  @override
  String get intersections => 'Intersections';

  @override
  String get delay => 'Delay';

  @override
  String get losNote =>
      'LOS letters are indicative: HCM 6th Edition delay thresholds applied to simulated delay. Use the methodology required by the reviewing authority.';

  @override
  String get approaches => 'Approaches';

  @override
  String get approach => 'Approach';

  @override
  String get losShort => 'LOS';

  @override
  String get queueAvg => 'Avg queue';

  @override
  String get queueP95 => '95th % queue';

  @override
  String get queueMax => 'Max queue';

  @override
  String get flow => 'Flow';

  @override
  String get movements => 'Movements (origin → destination)';

  @override
  String get fromTo => 'From → to';

  @override
  String get vehicles => 'Vehicles';

  @override
  String warningsCount(int n, int high) {
    return 'Data quality and warnings ($n, $high serious)';
  }

  @override
  String get assumptions => 'Assumptions used in this run';

  @override
  String get definitions => 'Metric definitions';

  @override
  String get definitionsLanguageNote =>
      'Definitions are provided by the server in English.';

  @override
  String get exportCsv => 'Export results (CSV)';

  @override
  String exportedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get playbackNeedsRun => 'Run a simulation to watch the traffic.';

  @override
  String get playbackNotRecorded =>
      'This run did not record vehicle positions.';

  @override
  String get goToSimulation => 'Simulation settings';

  @override
  String get playbackNoTrajectory => 'Simulated network (no recorded vehicles)';

  @override
  String playbackInfo(int n, String from, String to) {
    return 'Replication 1 of $n · $from–$to · positions exactly as computed by SUMO';
  }

  @override
  String get staleShort => 'outdated';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get restart => 'Restart';

  @override
  String get stepBack => 'Step back';

  @override
  String get stepForward => 'Step forward';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get heatmap => 'Congestion heat map';

  @override
  String get heatmapTitle => 'Mean speed / speed limit';

  @override
  String get noData => 'no data';

  @override
  String get colorBySpeed => 'Colour vehicles by speed';

  @override
  String get followVehicle => 'Follow';

  @override
  String vehicleSpeed(String kmh) {
    return 'Speed $kmh km/h';
  }

  @override
  String get vehicleLeft => 'Not in the network at this time';

  @override
  String get issueNoRoads => 'The design has no roads yet.';

  @override
  String issueIsolatedNode(String node) {
    return 'Node $node is not connected and will be ignored.';
  }

  @override
  String issueRoundaboutNeedsRoads(String node) {
    return 'Roundabout $node needs at least two connected roads.';
  }

  @override
  String issueSignalAtDeadEnd(String node) {
    return 'Node $node is a road end and cannot be signalised.';
  }

  @override
  String issueRoadTooShort(String road) {
    return 'Road $road is shorter than 1 m.';
  }

  @override
  String issueBayTooLong(String road, String bay) {
    return 'Turn bay of $bay m does not fit on road $road.';
  }

  @override
  String get issueNoGates =>
      'No road ends: traffic needs road ends to enter and leave the model.';

  @override
  String get issueNoDemand => 'No traffic entered yet (Traffic tab).';

  @override
  String issueOriginNotGate(String node) {
    return 'Traffic entering at $node, which is no longer a road end.';
  }

  @override
  String issueOriginNoLanes(String node) {
    return 'No lane enters the network at $node.';
  }

  @override
  String issueMixSum(String node, String sum) {
    return 'Vehicle mix at $node totals $sum% instead of 100%.';
  }

  @override
  String issueShareSum(String node, String sum) {
    return 'Destination shares from $node total $sum% instead of 100%.';
  }

  @override
  String issueDestinationInvalid(String node, String dest) {
    return 'Traffic from $node goes to $dest, where no lane leaves the network.';
  }

  @override
  String issueSameOriginDestination(String node) {
    return 'Traffic from $node cannot return to the same road end.';
  }

  @override
  String get issueWarmupTooLong =>
      'Warm-up must be shorter than the simulation duration.';

  @override
  String issueFewReplications(String n) {
    return 'Only $n replication(s): at least 5 are recommended.';
  }

  @override
  String get issueEidmStep => 'EIDM needs a time step of 0.5 s or less.';
}
