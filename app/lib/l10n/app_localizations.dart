import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RoadFlow AI'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Road design and microscopic traffic simulation'**
  String get appTagline;

  /// No description provided for @otherLanguage.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get otherLanguage;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @newProjectDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Untitled study'**
  String get newProjectDefaultName;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectName;

  /// No description provided for @startFrom.
  ///
  /// In en, this message translates to:
  /// **'Start from'**
  String get startFrom;

  /// No description provided for @templateBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank canvas'**
  String get templateBlank;

  /// No description provided for @templateSignalised.
  ///
  /// In en, this message translates to:
  /// **'4-arm signalised intersection'**
  String get templateSignalised;

  /// No description provided for @templateTJunction.
  ///
  /// In en, this message translates to:
  /// **'T-junction (stop on minor road)'**
  String get templateTJunction;

  /// No description provided for @templateRoundabout.
  ///
  /// In en, this message translates to:
  /// **'Roundabout'**
  String get templateRoundabout;

  /// No description provided for @templateDemandNote.
  ///
  /// In en, this message translates to:
  /// **'Templates include an assumed demand scenario (labelled as assumed) so a first run is possible. Replace it with observed counts for real studies.'**
  String get templateDemandNote;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @deleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get deleteProject;

  /// No description provided for @deleteProjectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" and all its variants? This cannot be undone.'**
  String deleteProjectConfirm(String name);

  /// No description provided for @projectLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The project could not be opened.'**
  String get projectLoadFailed;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjects;

  /// No description provided for @noProjectsHint.
  ///
  /// In en, this message translates to:
  /// **'Create a project to start designing roads and intersections.'**
  String get noProjectsHint;

  /// No description provided for @variantsCount.
  ///
  /// In en, this message translates to:
  /// **'Design variants: {count}'**
  String variantsCount(int count);

  /// No description provided for @lastModified.
  ///
  /// In en, this message translates to:
  /// **'Modified {date}'**
  String lastModified(String date);

  /// No description provided for @variantExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get variantExisting;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Simulation server'**
  String get serverSettings;

  /// No description provided for @serverExplanation.
  ///
  /// In en, this message translates to:
  /// **'Design work is stored on this device and works offline. Simulations run on the RoadFlow server (SUMO). Use HTTPS outside a trusted network.'**
  String get serverExplanation;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverUrl;

  /// No description provided for @apiToken.
  ///
  /// In en, this message translates to:
  /// **'Access token (optional)'**
  String get apiToken;

  /// No description provided for @insecureServer.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted (http) connection: designs and results travel in clear text. Use https outside a trusted local network.'**
  String get insecureServer;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @serverOk.
  ///
  /// In en, this message translates to:
  /// **'Connected: {engine} (server {version})'**
  String serverOk(String engine, String version);

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server: {error}'**
  String serverUnreachable(String error);

  /// No description provided for @serverLine.
  ///
  /// In en, this message translates to:
  /// **'Server: {url}'**
  String serverLine(String url);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed'**
  String get saveFailed;

  /// No description provided for @renameProject.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get renameProject;

  /// No description provided for @modeDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get modeDesign;

  /// No description provided for @modeSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get modeSimulation;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @fitToView.
  ///
  /// In en, this message translates to:
  /// **'Fit to view'**
  String get fitToView;

  /// No description provided for @hidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide panel'**
  String get hidePanel;

  /// No description provided for @showPanel.
  ///
  /// In en, this message translates to:
  /// **'Show panel'**
  String get showPanel;

  /// No description provided for @variantActions.
  ///
  /// In en, this message translates to:
  /// **'Design variants'**
  String get variantActions;

  /// No description provided for @duplicateVariant.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as new variant'**
  String get duplicateVariant;

  /// No description provided for @renameVariant.
  ///
  /// In en, this message translates to:
  /// **'Rename variant'**
  String get renameVariant;

  /// No description provided for @deleteVariant.
  ///
  /// In en, this message translates to:
  /// **'Delete variant'**
  String get deleteVariant;

  /// No description provided for @variantCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} – alternative'**
  String variantCopyName(String name);

  /// No description provided for @cannotDeleteLastVariant.
  ///
  /// In en, this message translates to:
  /// **'A project needs at least one variant.'**
  String get cannotDeleteLastVariant;

  /// No description provided for @toolSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get toolSelect;

  /// No description provided for @toolRoad.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get toolRoad;

  /// No description provided for @toolCurve.
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get toolCurve;

  /// No description provided for @toolJunction.
  ///
  /// In en, this message translates to:
  /// **'Junction'**
  String get toolJunction;

  /// No description provided for @toolMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get toolMeasure;

  /// No description provided for @deleteSelection.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelection;

  /// No description provided for @lanesForwardShort.
  ///
  /// In en, this message translates to:
  /// **'Lanes →'**
  String get lanesForwardShort;

  /// No description provided for @lanesBackwardShort.
  ///
  /// In en, this message translates to:
  /// **'Lanes ←'**
  String get lanesBackwardShort;

  /// No description provided for @speedLimit.
  ///
  /// In en, this message translates to:
  /// **'Speed limit'**
  String get speedLimit;

  /// No description provided for @optAutoJunctions.
  ///
  /// In en, this message translates to:
  /// **'Junctions at crossings'**
  String get optAutoJunctions;

  /// No description provided for @optGridSnap.
  ///
  /// In en, this message translates to:
  /// **'Grid snap'**
  String get optGridSnap;

  /// No description provided for @optAngleSnap.
  ///
  /// In en, this message translates to:
  /// **'15° angles'**
  String get optAngleSnap;

  /// No description provided for @optPenOnly.
  ///
  /// In en, this message translates to:
  /// **'Draw with pen only'**
  String get optPenOnly;

  /// No description provided for @templateFourWaySignal.
  ///
  /// In en, this message translates to:
  /// **'4-arm, signals'**
  String get templateFourWaySignal;

  /// No description provided for @templateTStop.
  ///
  /// In en, this message translates to:
  /// **'T-junction, stop'**
  String get templateTStop;

  /// No description provided for @armLength.
  ///
  /// In en, this message translates to:
  /// **'Arm length'**
  String get armLength;

  /// No description provided for @hintTapToPlace.
  ///
  /// In en, this message translates to:
  /// **'Tap the canvas to place'**
  String get hintTapToPlace;

  /// No description provided for @hintMeasure.
  ///
  /// In en, this message translates to:
  /// **'Tap points to measure length, angles and area'**
  String get hintMeasure;

  /// No description provided for @hintSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select · drag nodes to move · two fingers to pan and zoom'**
  String get hintSelect;

  /// No description provided for @measureLength.
  ///
  /// In en, this message translates to:
  /// **'Length {m} m'**
  String measureLength(String m);

  /// No description provided for @measureBearing.
  ///
  /// In en, this message translates to:
  /// **'Bearing {deg}°'**
  String measureBearing(String deg);

  /// No description provided for @measureAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle {deg}°'**
  String measureAngle(String deg);

  /// No description provided for @measureArea.
  ///
  /// In en, this message translates to:
  /// **'Area {m2} m²'**
  String measureArea(String m2);

  /// No description provided for @tabProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get tabProperties;

  /// No description provided for @tabDemand.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get tabDemand;

  /// No description provided for @tabSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get tabSimulation;

  /// No description provided for @tabResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get tabResults;

  /// No description provided for @propertiesHint.
  ///
  /// In en, this message translates to:
  /// **'Select a road or junction on the canvas to edit it. Draw roads with the Road or Curve tool; junctions are created where roads meet.'**
  String get propertiesHint;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkSettings;

  /// No description provided for @drivingSide.
  ///
  /// In en, this message translates to:
  /// **'Driving side'**
  String get drivingSide;

  /// No description provided for @drivingRight.
  ///
  /// In en, this message translates to:
  /// **'Right-hand (e.g. Qatar)'**
  String get drivingRight;

  /// No description provided for @drivingLeft.
  ///
  /// In en, this message translates to:
  /// **'Left-hand'**
  String get drivingLeft;

  /// No description provided for @allowUTurns.
  ///
  /// In en, this message translates to:
  /// **'Allow U-turns at junctions'**
  String get allowUTurns;

  /// No description provided for @allowUTurnsHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to every junction in this variant.'**
  String get allowUTurnsHint;

  /// No description provided for @newRoadDefaults.
  ///
  /// In en, this message translates to:
  /// **'New road defaults'**
  String get newRoadDefaults;

  /// No description provided for @lanesForward.
  ///
  /// In en, this message translates to:
  /// **'Lanes in drawing direction'**
  String get lanesForward;

  /// No description provided for @lanesBackward.
  ///
  /// In en, this message translates to:
  /// **'Lanes in opposite direction'**
  String get lanesBackward;

  /// No description provided for @laneWidth.
  ///
  /// In en, this message translates to:
  /// **'Lane width'**
  String get laneWidth;

  /// No description provided for @defaultsNotStandards.
  ///
  /// In en, this message translates to:
  /// **'Editor defaults only: they are not design-standard values. Enter the dimensions required by the applicable manual.'**
  String get defaultsNotStandards;

  /// No description provided for @networkSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get networkSummary;

  /// No description provided for @summaryCounts.
  ///
  /// In en, this message translates to:
  /// **'{nodes} nodes · {roads} road segments'**
  String summaryCounts(int nodes, int roads);

  /// No description provided for @summaryLength.
  ///
  /// In en, this message translates to:
  /// **'Total centreline length: {km} km'**
  String summaryLength(String km);

  /// No description provided for @gateTitle.
  ///
  /// In en, this message translates to:
  /// **'Road end {id}'**
  String gateTitle(String id);

  /// No description provided for @nodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Junction {id}'**
  String nodeTitle(String id);

  /// No description provided for @nodeDegree.
  ///
  /// In en, this message translates to:
  /// **'Connected road segments: {n}'**
  String nodeDegree(int n);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevation;

  /// No description provided for @junctionControl.
  ///
  /// In en, this message translates to:
  /// **'Junction control'**
  String get junctionControl;

  /// No description provided for @controlPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority (give way)'**
  String get controlPriority;

  /// No description provided for @controlPriorityStop.
  ///
  /// In en, this message translates to:
  /// **'Stop on minor road'**
  String get controlPriorityStop;

  /// No description provided for @controlTrafficLight.
  ///
  /// In en, this message translates to:
  /// **'Traffic signals'**
  String get controlTrafficLight;

  /// No description provided for @controlAllwayStop.
  ///
  /// In en, this message translates to:
  /// **'All-way stop'**
  String get controlAllwayStop;

  /// No description provided for @controlRightBeforeLeft.
  ///
  /// In en, this message translates to:
  /// **'Uncontrolled (right before left)'**
  String get controlRightBeforeLeft;

  /// No description provided for @controlRoundabout.
  ///
  /// In en, this message translates to:
  /// **'Roundabout'**
  String get controlRoundabout;

  /// No description provided for @helpPriority.
  ///
  /// In en, this message translates to:
  /// **'The major road (higher priority / speed / lanes) has right of way; minor approaches yield.'**
  String get helpPriority;

  /// No description provided for @helpPriorityStop.
  ///
  /// In en, this message translates to:
  /// **'Minor approaches must stop, then enter when a gap is accepted.'**
  String get helpPriorityStop;

  /// No description provided for @helpTrafficLight.
  ///
  /// In en, this message translates to:
  /// **'Fixed-time plan generated from the Simulate tab settings; the plan used is shown in playback.'**
  String get helpTrafficLight;

  /// No description provided for @helpAllwayStop.
  ///
  /// In en, this message translates to:
  /// **'Every approach stops before entering.'**
  String get helpAllwayStop;

  /// No description provided for @helpRightBeforeLeft.
  ///
  /// In en, this message translates to:
  /// **'No priority road: traffic from the right goes first.'**
  String get helpRightBeforeLeft;

  /// No description provided for @helpRoundabout.
  ///
  /// In en, this message translates to:
  /// **'Circulating traffic has priority; entries yield. Counter-clockwise for right-hand traffic.'**
  String get helpRoundabout;

  /// No description provided for @roundaboutRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius to circulating centreline'**
  String get roundaboutRadius;

  /// No description provided for @roundaboutRadiusHelp.
  ///
  /// In en, this message translates to:
  /// **'Approach roads are connected where they cross this circle.'**
  String get roundaboutRadiusHelp;

  /// No description provided for @circulatingLanes.
  ///
  /// In en, this message translates to:
  /// **'Circulating lanes'**
  String get circulatingLanes;

  /// No description provided for @circulatingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Circulating speed limit'**
  String get circulatingSpeed;

  /// No description provided for @roadTitle.
  ///
  /// In en, this message translates to:
  /// **'Road segment {id}'**
  String roadTitle(String id);

  /// No description provided for @reverseDirection.
  ///
  /// In en, this message translates to:
  /// **'Swap directions'**
  String get reverseDirection;

  /// No description provided for @splitRoad.
  ///
  /// In en, this message translates to:
  /// **'Split in the middle'**
  String get splitRoad;

  /// No description provided for @roadGeometry.
  ///
  /// In en, this message translates to:
  /// **'Length {len} m · grade {grade} %'**
  String roadGeometry(String len, String grade);

  /// No description provided for @gradeNote.
  ///
  /// In en, this message translates to:
  /// **'Grade from end-node elevations. Elevations are passed to the simulation; the visual 3D model comes in phase 3.'**
  String get gradeNote;

  /// No description provided for @roadPriority.
  ///
  /// In en, this message translates to:
  /// **'Road hierarchy at junctions'**
  String get roadPriority;

  /// No description provided for @priorityAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get priorityAuto;

  /// No description provided for @priorityMajor.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get priorityMajor;

  /// No description provided for @priorityMinor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get priorityMinor;

  /// No description provided for @directionForward.
  ///
  /// In en, this message translates to:
  /// **'Drawing direction'**
  String get directionForward;

  /// No description provided for @directionBackward.
  ///
  /// In en, this message translates to:
  /// **'Opposite direction'**
  String get directionBackward;

  /// No description provided for @towardNode.
  ///
  /// In en, this message translates to:
  /// **'Traffic toward {node}'**
  String towardNode(String node);

  /// No description provided for @throughLanes.
  ///
  /// In en, this message translates to:
  /// **'Through lanes'**
  String get throughLanes;

  /// No description provided for @leftTurnBay.
  ///
  /// In en, this message translates to:
  /// **'Left-turn bay'**
  String get leftTurnBay;

  /// No description provided for @rightTurnBay.
  ///
  /// In en, this message translates to:
  /// **'Right-turn bay'**
  String get rightTurnBay;

  /// No description provided for @lanes.
  ///
  /// In en, this message translates to:
  /// **'Lanes'**
  String get lanes;

  /// No description provided for @storageLength.
  ///
  /// In en, this message translates to:
  /// **'Storage length'**
  String get storageLength;

  /// No description provided for @oneWayInfo.
  ///
  /// In en, this message translates to:
  /// **'One-way road: set the lane count of one direction to zero.'**
  String get oneWayInfo;

  /// No description provided for @demandSource.
  ///
  /// In en, this message translates to:
  /// **'Data source'**
  String get demandSource;

  /// No description provided for @sourceObserved.
  ///
  /// In en, this message translates to:
  /// **'Observed counts'**
  String get sourceObserved;

  /// No description provided for @sourceAssumed.
  ///
  /// In en, this message translates to:
  /// **'Assumed scenario'**
  String get sourceAssumed;

  /// No description provided for @sourceObservedHelp.
  ///
  /// In en, this message translates to:
  /// **'Use for volumes counted in the field. Record the survey date, period and method in the note; results are labelled as based on observed demand.'**
  String get sourceObservedHelp;

  /// No description provided for @sourceAssumedHelp.
  ///
  /// In en, this message translates to:
  /// **'Use for hypothetical or forecast volumes. Results are labelled as based on assumed demand and must not be presented as measurements.'**
  String get sourceAssumedHelp;

  /// No description provided for @sourceNote.
  ///
  /// In en, this message translates to:
  /// **'Source note'**
  String get sourceNote;

  /// No description provided for @sourceNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. manual count, 2025-03-04, 07:00–08:00'**
  String get sourceNoteHint;

  /// No description provided for @poissonArrivals.
  ///
  /// In en, this message translates to:
  /// **'Random (Poisson) arrivals'**
  String get poissonArrivals;

  /// No description provided for @poissonArrivalsHelp.
  ///
  /// In en, this message translates to:
  /// **'Off: vehicles arrive at evenly spaced intervals.'**
  String get poissonArrivalsHelp;

  /// No description provided for @noEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'Draw roads first: traffic enters and leaves the model at road ends (green circles).'**
  String get noEntriesYet;

  /// No description provided for @totalDemand.
  ///
  /// In en, this message translates to:
  /// **'Total entering demand: {flow} veh/h'**
  String totalDemand(String flow);

  /// No description provided for @entryFrom.
  ///
  /// In en, this message translates to:
  /// **'Entry: {name}'**
  String entryFrom(String name);

  /// No description provided for @flowVehPerHour.
  ///
  /// In en, this message translates to:
  /// **'Entering flow'**
  String get flowVehPerHour;

  /// No description provided for @vehPerHour.
  ///
  /// In en, this message translates to:
  /// **'veh/h'**
  String get vehPerHour;

  /// No description provided for @vehicleMix.
  ///
  /// In en, this message translates to:
  /// **'Vehicle mix'**
  String get vehicleMix;

  /// No description provided for @cars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get cars;

  /// No description provided for @trucks.
  ///
  /// In en, this message translates to:
  /// **'Trucks'**
  String get trucks;

  /// No description provided for @buses.
  ///
  /// In en, this message translates to:
  /// **'Buses'**
  String get buses;

  /// No description provided for @mixMustBe100.
  ///
  /// In en, this message translates to:
  /// **'Mix must total 100% (now {sum}%)'**
  String mixMustBe100(String sum);

  /// No description provided for @destinationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Turning / destination shares'**
  String get destinationsTitle;

  /// No description provided for @equalSplit.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get equalSplit;

  /// No description provided for @normalize.
  ///
  /// In en, this message translates to:
  /// **'Scale to 100%'**
  String get normalize;

  /// No description provided for @shareTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {sum}%'**
  String shareTotal(String sum);

  /// No description provided for @turnLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get turnLeft;

  /// No description provided for @turnThrough.
  ///
  /// In en, this message translates to:
  /// **'Through'**
  String get turnThrough;

  /// No description provided for @turnRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get turnRight;

  /// No description provided for @turnU.
  ///
  /// In en, this message translates to:
  /// **'U-turn'**
  String get turnU;

  /// No description provided for @runSimulation.
  ///
  /// In en, this message translates to:
  /// **'Run simulation'**
  String get runSimulation;

  /// No description provided for @runButton.
  ///
  /// In en, this message translates to:
  /// **'Simulate ({n} replications)'**
  String runButton(int n);

  /// No description provided for @phaseSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending design to the server…'**
  String get phaseSubmitting;

  /// No description provided for @phaseRunning.
  ///
  /// In en, this message translates to:
  /// **'Simulating… {pct}% {msg}'**
  String phaseRunning(String pct, String msg);

  /// No description provided for @stageQueued.
  ///
  /// In en, this message translates to:
  /// **'waiting for a free simulator'**
  String get stageQueued;

  /// No description provided for @stageBuilding.
  ///
  /// In en, this message translates to:
  /// **'building the SUMO network'**
  String get stageBuilding;

  /// No description provided for @stageRunning.
  ///
  /// In en, this message translates to:
  /// **'running replications'**
  String get stageRunning;

  /// No description provided for @stageAnalysing.
  ///
  /// In en, this message translates to:
  /// **'computing results'**
  String get stageAnalysing;

  /// No description provided for @phaseFetching.
  ///
  /// In en, this message translates to:
  /// **'Downloading results and trajectories…'**
  String get phaseFetching;

  /// No description provided for @simulationFailed.
  ///
  /// In en, this message translates to:
  /// **'The simulation did not complete:'**
  String get simulationFailed;

  /// No description provided for @simulationDone.
  ///
  /// In en, this message translates to:
  /// **'Simulation finished. All figures come from this run.'**
  String get simulationDone;

  /// No description provided for @viewResults.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewResults;

  /// No description provided for @validateDesign.
  ///
  /// In en, this message translates to:
  /// **'Check design with SUMO (no traffic)'**
  String get validateDesign;

  /// No description provided for @validationOk.
  ///
  /// In en, this message translates to:
  /// **'SUMO built the network without warnings.'**
  String get validationOk;

  /// No description provided for @validationOkWithWarnings.
  ///
  /// In en, this message translates to:
  /// **'SUMO built the network with warnings:'**
  String get validationOkWithWarnings;

  /// No description provided for @runSettings.
  ///
  /// In en, this message translates to:
  /// **'Run settings'**
  String get runSettings;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @warmup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get warmup;

  /// No description provided for @warmupHelp.
  ///
  /// In en, this message translates to:
  /// **'Warm-up fills the network and is excluded from all statistics.'**
  String get warmupHelp;

  /// No description provided for @replications.
  ///
  /// In en, this message translates to:
  /// **'Replications'**
  String get replications;

  /// No description provided for @baseSeed.
  ///
  /// In en, this message translates to:
  /// **'First random seed'**
  String get baseSeed;

  /// No description provided for @replicationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Each replication uses a different seed; results show the mean and 95% confidence interval. Compare variants with the same seeds.'**
  String get replicationsHelp;

  /// No description provided for @timeStep.
  ///
  /// In en, this message translates to:
  /// **'Simulation time step'**
  String get timeStep;

  /// No description provided for @recordPlayback.
  ///
  /// In en, this message translates to:
  /// **'Record vehicle positions for playback'**
  String get recordPlayback;

  /// No description provided for @recordPlaybackHelp.
  ///
  /// In en, this message translates to:
  /// **'First {min} min of replication 1, exactly as simulated.'**
  String recordPlaybackHelp(String min);

  /// No description provided for @playbackWindow.
  ///
  /// In en, this message translates to:
  /// **'Playback window'**
  String get playbackWindow;

  /// No description provided for @driverBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Driver behaviour'**
  String get driverBehaviour;

  /// No description provided for @carFollowingModel.
  ///
  /// In en, this message translates to:
  /// **'Car-following model'**
  String get carFollowingModel;

  /// No description provided for @modelEidm.
  ///
  /// In en, this message translates to:
  /// **'EIDM – Extended IDM (default)'**
  String get modelEidm;

  /// No description provided for @modelIdm.
  ///
  /// In en, this message translates to:
  /// **'IDM – Intelligent Driver Model'**
  String get modelIdm;

  /// No description provided for @modelKrauss.
  ///
  /// In en, this message translates to:
  /// **'Krauss (SUMO default)'**
  String get modelKrauss;

  /// No description provided for @carFollowingHelp.
  ///
  /// In en, this message translates to:
  /// **'EIDM adds reaction time, estimation errors and jerk limits to IDM. Parameters are SUMO defaults until calibrated with local data.'**
  String get carFollowingHelp;

  /// No description provided for @driverHeterogeneity.
  ///
  /// In en, this message translates to:
  /// **'Different driver profiles'**
  String get driverHeterogeneity;

  /// No description provided for @driverHeterogeneityHelp.
  ///
  /// In en, this message translates to:
  /// **'Varies headway, gaps, acceleration, speed choice and reaction time between drivers (assumed spreads).'**
  String get driverHeterogeneityHelp;

  /// No description provided for @gapAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Gap acceptance (SUMO impatience, 0–1)'**
  String get gapAcceptance;

  /// No description provided for @gapAcceptanceHelp.
  ///
  /// In en, this message translates to:
  /// **'0.5 reproduces HCM 6th Ed. give-way and roundabout entry capacities in the benchmark suite; SUMO\'s own default (0) gives 15–30% of them. Calibrate with local data when available.'**
  String get gapAcceptanceHelp;

  /// No description provided for @strictStop.
  ///
  /// In en, this message translates to:
  /// **'Strict full stop at stop signs'**
  String get strictStop;

  /// No description provided for @strictStopHelp.
  ///
  /// In en, this message translates to:
  /// **'Off (default): stop-controlled approaches use field-calibrated gap behaviour, as in HCM. On: every vehicle halts at the line, which in SUMO discharges at about 45% of observed rates.'**
  String get strictStopHelp;

  /// No description provided for @reactionMin.
  ///
  /// In en, this message translates to:
  /// **'Reaction time min'**
  String get reactionMin;

  /// No description provided for @reactionMax.
  ///
  /// In en, this message translates to:
  /// **'Reaction time max'**
  String get reactionMax;

  /// No description provided for @signalTiming.
  ///
  /// In en, this message translates to:
  /// **'Signal timing'**
  String get signalTiming;

  /// No description provided for @signalTimingHelp.
  ///
  /// In en, this message translates to:
  /// **'Fixed-time plan generated for all signalised junctions. Phase-by-phase editing comes in phase 2.'**
  String get signalTimingHelp;

  /// No description provided for @cycleTime.
  ///
  /// In en, this message translates to:
  /// **'Cycle time'**
  String get cycleTime;

  /// No description provided for @autoYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow time from approach speed (SUMO)'**
  String get autoYellow;

  /// No description provided for @yellowTime.
  ///
  /// In en, this message translates to:
  /// **'Yellow time'**
  String get yellowTime;

  /// No description provided for @allRedTime.
  ///
  /// In en, this message translates to:
  /// **'All-red time'**
  String get allRedTime;

  /// No description provided for @leftGreen.
  ///
  /// In en, this message translates to:
  /// **'Protected left-turn green'**
  String get leftGreen;

  /// No description provided for @leftGreenHelp.
  ///
  /// In en, this message translates to:
  /// **'Used where left-turn lanes exist; 0 = no protected left phase.'**
  String get leftGreenHelp;

  /// No description provided for @phaseLayout.
  ///
  /// In en, this message translates to:
  /// **'Phase layout'**
  String get phaseLayout;

  /// No description provided for @layoutOpposites.
  ///
  /// In en, this message translates to:
  /// **'Opposing approaches together'**
  String get layoutOpposites;

  /// No description provided for @layoutIncoming.
  ///
  /// In en, this message translates to:
  /// **'One approach at a time (split phasing)'**
  String get layoutIncoming;

  /// No description provided for @noResultsYet.
  ///
  /// In en, this message translates to:
  /// **'No results yet. Set up traffic and run a simulation from the Simulate tab.'**
  String get noResultsYet;

  /// No description provided for @resultsStale.
  ///
  /// In en, this message translates to:
  /// **'The design or settings changed after this run. Run again to update the results.'**
  String get resultsStale;

  /// No description provided for @reliability.
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get reliability;

  /// No description provided for @resultMeta.
  ///
  /// In en, this message translates to:
  /// **'Run {date} · {n} replications · {duration} simulated, {warmup} warm-up excluded'**
  String resultMeta(String date, int n, String duration, String warmup);

  /// No description provided for @demandWasObserved.
  ///
  /// In en, this message translates to:
  /// **'Demand: observed counts'**
  String get demandWasObserved;

  /// No description provided for @demandWasAssumed.
  ///
  /// In en, this message translates to:
  /// **'Demand: assumed scenario (not measurements)'**
  String get demandWasAssumed;

  /// No description provided for @kpiDelay.
  ///
  /// In en, this message translates to:
  /// **'Average delay'**
  String get kpiDelay;

  /// No description provided for @kpiThroughput.
  ///
  /// In en, this message translates to:
  /// **'Throughput'**
  String get kpiThroughput;

  /// No description provided for @kpiMaxQueue.
  ///
  /// In en, this message translates to:
  /// **'Longest queue'**
  String get kpiMaxQueue;

  /// No description provided for @kpiWorstAvgQueue.
  ///
  /// In en, this message translates to:
  /// **'Average queue, worst approach'**
  String get kpiWorstAvgQueue;

  /// No description provided for @kpiTravelTime.
  ///
  /// In en, this message translates to:
  /// **'Travel time'**
  String get kpiTravelTime;

  /// No description provided for @kpiSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get kpiSpeed;

  /// No description provided for @kpiStops.
  ///
  /// In en, this message translates to:
  /// **'Stops per vehicle'**
  String get kpiStops;

  /// No description provided for @kpiCompleted.
  ///
  /// In en, this message translates to:
  /// **'Vehicles measured'**
  String get kpiCompleted;

  /// No description provided for @unitSecPerVeh.
  ///
  /// In en, this message translates to:
  /// **'s/veh'**
  String get unitSecPerVeh;

  /// No description provided for @perReplication.
  ///
  /// In en, this message translates to:
  /// **'per replication'**
  String get perReplication;

  /// No description provided for @ci95.
  ///
  /// In en, this message translates to:
  /// **'95% CI'**
  String get ci95;

  /// No description provided for @singleRun.
  ///
  /// In en, this message translates to:
  /// **'single replication: no interval'**
  String get singleRun;

  /// No description provided for @intersections.
  ///
  /// In en, this message translates to:
  /// **'Intersections'**
  String get intersections;

  /// No description provided for @delay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get delay;

  /// No description provided for @losNote.
  ///
  /// In en, this message translates to:
  /// **'LOS letters are indicative: HCM 6th Edition delay thresholds applied to simulated delay. Use the methodology required by the reviewing authority.'**
  String get losNote;

  /// No description provided for @approaches.
  ///
  /// In en, this message translates to:
  /// **'Approaches'**
  String get approaches;

  /// No description provided for @approach.
  ///
  /// In en, this message translates to:
  /// **'Approach'**
  String get approach;

  /// No description provided for @losShort.
  ///
  /// In en, this message translates to:
  /// **'LOS'**
  String get losShort;

  /// No description provided for @queueAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg queue'**
  String get queueAvg;

  /// No description provided for @queueP95.
  ///
  /// In en, this message translates to:
  /// **'95th % queue'**
  String get queueP95;

  /// No description provided for @queueMax.
  ///
  /// In en, this message translates to:
  /// **'Max queue'**
  String get queueMax;

  /// No description provided for @flow.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get flow;

  /// No description provided for @movements.
  ///
  /// In en, this message translates to:
  /// **'Movements (origin → destination)'**
  String get movements;

  /// No description provided for @fromTo.
  ///
  /// In en, this message translates to:
  /// **'From → to'**
  String get fromTo;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @warningsCount.
  ///
  /// In en, this message translates to:
  /// **'Data quality and warnings ({n}, {high} serious)'**
  String warningsCount(int n, int high);

  /// No description provided for @assumptions.
  ///
  /// In en, this message translates to:
  /// **'Assumptions used in this run'**
  String get assumptions;

  /// No description provided for @definitions.
  ///
  /// In en, this message translates to:
  /// **'Metric definitions'**
  String get definitions;

  /// No description provided for @definitionsLanguageNote.
  ///
  /// In en, this message translates to:
  /// **'Definitions are provided by the server in English.'**
  String get definitionsLanguageNote;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export results (CSV)'**
  String get exportCsv;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportedTo(String path);

  /// No description provided for @playbackNeedsRun.
  ///
  /// In en, this message translates to:
  /// **'Run a simulation to watch the traffic.'**
  String get playbackNeedsRun;

  /// No description provided for @playbackNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'This run did not record vehicle positions.'**
  String get playbackNotRecorded;

  /// No description provided for @goToSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation settings'**
  String get goToSimulation;

  /// No description provided for @playbackNoTrajectory.
  ///
  /// In en, this message translates to:
  /// **'Simulated network (no recorded vehicles)'**
  String get playbackNoTrajectory;

  /// No description provided for @playbackInfo.
  ///
  /// In en, this message translates to:
  /// **'Replication 1 of {n} · {from}–{to} · positions exactly as computed by SUMO'**
  String playbackInfo(int n, String from, String to);

  /// No description provided for @staleShort.
  ///
  /// In en, this message translates to:
  /// **'outdated'**
  String get staleShort;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @stepBack.
  ///
  /// In en, this message translates to:
  /// **'Step back'**
  String get stepBack;

  /// No description provided for @stepForward.
  ///
  /// In en, this message translates to:
  /// **'Step forward'**
  String get stepForward;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @heatmap.
  ///
  /// In en, this message translates to:
  /// **'Congestion heat map'**
  String get heatmap;

  /// No description provided for @heatmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Mean speed / speed limit'**
  String get heatmapTitle;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'no data'**
  String get noData;

  /// No description provided for @colorBySpeed.
  ///
  /// In en, this message translates to:
  /// **'Colour vehicles by speed'**
  String get colorBySpeed;

  /// No description provided for @followVehicle.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followVehicle;

  /// No description provided for @vehicleSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed {kmh} km/h'**
  String vehicleSpeed(String kmh);

  /// No description provided for @vehicleLeft.
  ///
  /// In en, this message translates to:
  /// **'Not in the network at this time'**
  String get vehicleLeft;

  /// No description provided for @issueNoRoads.
  ///
  /// In en, this message translates to:
  /// **'The design has no roads yet.'**
  String get issueNoRoads;

  /// No description provided for @issueIsolatedNode.
  ///
  /// In en, this message translates to:
  /// **'Node {node} is not connected and will be ignored.'**
  String issueIsolatedNode(String node);

  /// No description provided for @issueRoundaboutNeedsRoads.
  ///
  /// In en, this message translates to:
  /// **'Roundabout {node} needs at least two connected roads.'**
  String issueRoundaboutNeedsRoads(String node);

  /// No description provided for @issueSignalAtDeadEnd.
  ///
  /// In en, this message translates to:
  /// **'Node {node} is a road end and cannot be signalised.'**
  String issueSignalAtDeadEnd(String node);

  /// No description provided for @issueRoadTooShort.
  ///
  /// In en, this message translates to:
  /// **'Road {road} is shorter than 1 m.'**
  String issueRoadTooShort(String road);

  /// No description provided for @issueBayTooLong.
  ///
  /// In en, this message translates to:
  /// **'Turn bay of {bay} m does not fit on road {road}.'**
  String issueBayTooLong(String road, String bay);

  /// No description provided for @issueNoGates.
  ///
  /// In en, this message translates to:
  /// **'No road ends: traffic needs road ends to enter and leave the model.'**
  String get issueNoGates;

  /// No description provided for @issueNoDemand.
  ///
  /// In en, this message translates to:
  /// **'No traffic entered yet (Traffic tab).'**
  String get issueNoDemand;

  /// No description provided for @issueOriginNotGate.
  ///
  /// In en, this message translates to:
  /// **'Traffic entering at {node}, which is no longer a road end.'**
  String issueOriginNotGate(String node);

  /// No description provided for @issueOriginNoLanes.
  ///
  /// In en, this message translates to:
  /// **'No lane enters the network at {node}.'**
  String issueOriginNoLanes(String node);

  /// No description provided for @issueMixSum.
  ///
  /// In en, this message translates to:
  /// **'Vehicle mix at {node} totals {sum}% instead of 100%.'**
  String issueMixSum(String node, String sum);

  /// No description provided for @issueShareSum.
  ///
  /// In en, this message translates to:
  /// **'Destination shares from {node} total {sum}% instead of 100%.'**
  String issueShareSum(String node, String sum);

  /// No description provided for @issueDestinationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Traffic from {node} goes to {dest}, where no lane leaves the network.'**
  String issueDestinationInvalid(String node, String dest);

  /// No description provided for @issueSameOriginDestination.
  ///
  /// In en, this message translates to:
  /// **'Traffic from {node} cannot return to the same road end.'**
  String issueSameOriginDestination(String node);

  /// No description provided for @issueWarmupTooLong.
  ///
  /// In en, this message translates to:
  /// **'Warm-up must be shorter than the simulation duration.'**
  String get issueWarmupTooLong;

  /// No description provided for @issueFewReplications.
  ///
  /// In en, this message translates to:
  /// **'Only {n} replication(s): at least 5 are recommended.'**
  String issueFewReplications(String n);

  /// No description provided for @issueEidmStep.
  ///
  /// In en, this message translates to:
  /// **'EIDM needs a time step of 0.5 s or less.'**
  String get issueEidmStep;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
