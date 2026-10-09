// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'RoadFlow AI';

  @override
  String get appTagline => 'تصميم الطرق والمحاكاة المرورية المجهرية';

  @override
  String get otherLanguage => 'English';

  @override
  String get projects => 'المشاريع';

  @override
  String get newProject => 'مشروع جديد';

  @override
  String get newProjectDefaultName => 'دراسة جديدة';

  @override
  String get projectName => 'اسم المشروع';

  @override
  String get startFrom => 'البدء من';

  @override
  String get templateBlank => 'لوحة فارغة';

  @override
  String get templateSignalised => 'تقاطع رباعي بإشارات ضوئية';

  @override
  String get templateTJunction => 'تقاطع ثلاثي (توقف على الطريق الفرعي)';

  @override
  String get templateRoundabout => 'دوار';

  @override
  String get templateDemandNote =>
      'تتضمن القوالب سيناريو طلب مروري افتراضيًا (مُعلَّمًا بأنه افتراضي) لتمكين التشغيل الأول. استبدله بأعداد مرصودة في الدراسات الفعلية.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get create => 'إنشاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get clear => 'مسح';

  @override
  String get deleteProject => 'حذف المشروع';

  @override
  String deleteProjectConfirm(String name) {
    return 'حذف \"$name\" وجميع نسخه؟ لا يمكن التراجع عن ذلك.';
  }

  @override
  String get projectLoadFailed => 'تعذّر فتح المشروع.';

  @override
  String get noProjects => 'لا توجد مشاريع بعد';

  @override
  String get noProjectsHint => 'أنشئ مشروعًا لبدء تصميم الطرق والتقاطعات.';

  @override
  String variantsCount(int count) {
    return 'نسخ التصميم: $count';
  }

  @override
  String lastModified(String date) {
    return 'آخر تعديل $date';
  }

  @override
  String get variantExisting => 'الوضع الحالي';

  @override
  String get serverSettings => 'خادم المحاكاة';

  @override
  String get serverExplanation =>
      'يُحفظ التصميم على هذا الجهاز ويعمل دون اتصال. تُنفَّذ المحاكاة على خادم RoadFlow ‏(SUMO). استخدم HTTPS خارج الشبكات الموثوقة.';

  @override
  String get serverUrl => 'عنوان الخادم';

  @override
  String get apiToken => 'رمز الوصول (اختياري)';

  @override
  String get insecureServer =>
      'اتصال غير مشفر (http): تنتقل التصاميم والنتائج دون تشفير. استخدم https خارج الشبكة المحلية الموثوقة.';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String serverOk(String engine, String version) {
    return 'متصل: $engine (الخادم $version)';
  }

  @override
  String serverUnreachable(String error) {
    return 'تعذّر الوصول إلى الخادم: $error';
  }

  @override
  String serverLine(String url) {
    return 'الخادم: $url';
  }

  @override
  String get saved => 'تم الحفظ';

  @override
  String get saving => 'جارٍ الحفظ…';

  @override
  String get saveFailed => 'فشل الحفظ';

  @override
  String get renameProject => 'إعادة تسمية المشروع';

  @override
  String get modeDesign => 'التصميم';

  @override
  String get modeSimulation => 'المحاكاة';

  @override
  String get undo => 'تراجع';

  @override
  String get redo => 'إعادة';

  @override
  String get fitToView => 'ملاءمة العرض';

  @override
  String get hidePanel => 'إخفاء اللوحة';

  @override
  String get showPanel => 'إظهار اللوحة';

  @override
  String get variantActions => 'نسخ التصميم';

  @override
  String get duplicateVariant => 'نسخ كنسخة تصميم جديدة';

  @override
  String get renameVariant => 'إعادة تسمية النسخة';

  @override
  String get deleteVariant => 'حذف النسخة';

  @override
  String variantCopyName(String name) {
    return '$name – بديل';
  }

  @override
  String get cannotDeleteLastVariant =>
      'يحتاج المشروع إلى نسخة واحدة على الأقل.';

  @override
  String get toolSelect => 'تحديد';

  @override
  String get toolRoad => 'طريق';

  @override
  String get toolCurve => 'منحنى';

  @override
  String get toolJunction => 'تقاطع';

  @override
  String get toolMeasure => 'قياس';

  @override
  String get deleteSelection => 'حذف المحدد';

  @override
  String get lanesForwardShort => 'مسارات →';

  @override
  String get lanesBackwardShort => 'مسارات ←';

  @override
  String get speedLimit => 'السرعة المسموحة';

  @override
  String get optAutoJunctions => 'تقاطعات عند التقاطع';

  @override
  String get optGridSnap => 'المحاذاة للشبكة';

  @override
  String get optAngleSnap => 'زوايا 15°';

  @override
  String get optPenOnly => 'الرسم بالقلم فقط';

  @override
  String get templateFourWaySignal => 'رباعي بإشارات';

  @override
  String get templateTStop => 'ثلاثي بتوقف';

  @override
  String get armLength => 'طول الذراع';

  @override
  String get hintTapToPlace => 'انقر على اللوحة لوضع التقاطع';

  @override
  String get hintMeasure => 'انقر نقاطًا لقياس الطول والزوايا والمساحة';

  @override
  String get hintSelect =>
      'انقر للتحديد · اسحب العقد لتحريكها · إصبعان للتحريك والتكبير';

  @override
  String measureLength(String m) {
    return 'الطول $m م';
  }

  @override
  String measureBearing(String deg) {
    return 'الاتجاه $deg°';
  }

  @override
  String measureAngle(String deg) {
    return 'الزاوية $deg°';
  }

  @override
  String measureArea(String m2) {
    return 'المساحة $m2 م²';
  }

  @override
  String get tabProperties => 'الخصائص';

  @override
  String get tabDemand => 'المرور';

  @override
  String get tabSimulation => 'المحاكاة';

  @override
  String get tabResults => 'النتائج';

  @override
  String get propertiesHint =>
      'حدّد طريقًا أو تقاطعًا على اللوحة لتعديله. ارسم الطرق بأداة الطريق أو المنحنى؛ تُنشأ التقاطعات حيث تلتقي الطرق.';

  @override
  String get networkSettings => 'الشبكة';

  @override
  String get drivingSide => 'جهة السير';

  @override
  String get drivingRight => 'اليمين (مثل قطر)';

  @override
  String get drivingLeft => 'اليسار';

  @override
  String get allowUTurns => 'السماح بالالتفاف للخلف في التقاطعات';

  @override
  String get allowUTurnsHint => 'ينطبق على جميع تقاطعات هذه النسخة.';

  @override
  String get newRoadDefaults => 'الإعدادات الافتراضية للطرق الجديدة';

  @override
  String get lanesForward => 'المسارات باتجاه الرسم';

  @override
  String get lanesBackward => 'المسارات بالاتجاه المعاكس';

  @override
  String get laneWidth => 'عرض المسار';

  @override
  String get defaultsNotStandards =>
      'هذه قيم افتراضية للمحرر فقط وليست قيمًا من معايير التصميم. أدخل الأبعاد التي يتطلبها الدليل المعتمد.';

  @override
  String get networkSummary => 'ملخص';

  @override
  String summaryCounts(int nodes, int roads) {
    return '$nodes عقدة · $roads مقطع طريق';
  }

  @override
  String summaryLength(String km) {
    return 'إجمالي طول المحاور: $km كم';
  }

  @override
  String gateTitle(String id) {
    return 'نهاية طريق $id';
  }

  @override
  String nodeTitle(String id) {
    return 'تقاطع $id';
  }

  @override
  String nodeDegree(int n) {
    return 'مقاطع الطرق المتصلة: $n';
  }

  @override
  String get name => 'الاسم';

  @override
  String get elevation => 'المنسوب';

  @override
  String get junctionControl => 'نوع التحكم في التقاطع';

  @override
  String get controlPriority => 'أولوية (إفساح الطريق)';

  @override
  String get controlPriorityStop => 'توقف على الطريق الفرعي';

  @override
  String get controlTrafficLight => 'إشارات ضوئية';

  @override
  String get controlAllwayStop => 'توقف من جميع الاتجاهات';

  @override
  String get controlRightBeforeLeft => 'غير منظم (أولوية اليمين)';

  @override
  String get controlRoundabout => 'دوار';

  @override
  String get helpPriority =>
      'للطريق الرئيسي (الأعلى أولوية أو سرعة أو مسارات) حق الأولوية؛ وتفسح المداخل الفرعية الطريق.';

  @override
  String get helpPriorityStop =>
      'يجب التوقف في المداخل الفرعية ثم الدخول عند قبول فجوة مناسبة.';

  @override
  String get helpTrafficLight =>
      'خطة زمنية ثابتة تُولَّد من إعدادات تبويب المحاكاة؛ وتظهر الخطة المستخدمة في العرض.';

  @override
  String get helpAllwayStop => 'تتوقف جميع المداخل قبل الدخول.';

  @override
  String get helpRightBeforeLeft =>
      'لا يوجد طريق ذو أولوية: الأولوية للقادم من اليمين.';

  @override
  String get helpRoundabout =>
      'الأولوية للحركة الدائرية؛ وتفسح المداخل الطريق. الدوران عكس عقارب الساعة عند السير على اليمين.';

  @override
  String get roundaboutRadius => 'نصف القطر حتى محور الطريق الدائري';

  @override
  String get roundaboutRadiusHelp =>
      'تُوصل الطرق المؤدية عند نقطة تقاطعها مع هذه الدائرة.';

  @override
  String get circulatingLanes => 'المسارات الدائرية';

  @override
  String get circulatingSpeed => 'السرعة المسموحة داخل الدوار';

  @override
  String roadTitle(String id) {
    return 'مقطع طريق $id';
  }

  @override
  String get reverseDirection => 'عكس الاتجاهين';

  @override
  String get splitRoad => 'تقسيم من المنتصف';

  @override
  String roadGeometry(String len, String grade) {
    return 'الطول $len م · الميل $grade%';
  }

  @override
  String get gradeNote =>
      'الميل محسوب من مناسيب العقدتين الطرفيتين. تُمرَّر المناسيب إلى المحاكاة؛ والنموذج ثلاثي الأبعاد يأتي في المرحلة الثالثة.';

  @override
  String get roadPriority => 'تصنيف الطريق في التقاطعات';

  @override
  String get priorityAuto => 'تلقائي';

  @override
  String get priorityMajor => 'رئيسي';

  @override
  String get priorityMinor => 'فرعي';

  @override
  String get directionForward => 'اتجاه الرسم';

  @override
  String get directionBackward => 'الاتجاه المعاكس';

  @override
  String towardNode(String node) {
    return 'الحركة باتجاه $node';
  }

  @override
  String get throughLanes => 'المسارات الأساسية';

  @override
  String get leftTurnBay => 'جيب انعطاف لليسار';

  @override
  String get rightTurnBay => 'جيب انعطاف لليمين';

  @override
  String get lanes => 'المسارات';

  @override
  String get storageLength => 'طول التخزين';

  @override
  String get oneWayInfo =>
      'طريق باتجاه واحد: اجعل عدد مسارات أحد الاتجاهين صفرًا.';

  @override
  String get demandSource => 'مصدر البيانات';

  @override
  String get sourceObserved => 'أعداد مرصودة';

  @override
  String get sourceAssumed => 'سيناريو افتراضي';

  @override
  String get sourceObservedHelp =>
      'استخدمه للأحجام المعدودة ميدانيًا. سجّل تاريخ المسح وفترته وطريقته في الملاحظة؛ وتُعلَّم النتائج بأنها مبنية على طلب مرصود.';

  @override
  String get sourceAssumedHelp =>
      'استخدمه للأحجام الافتراضية أو المتوقعة. تُعلَّم النتائج بأنها مبنية على طلب افتراضي ولا يجوز تقديمها كقياسات.';

  @override
  String get sourceNote => 'ملاحظة المصدر';

  @override
  String get sourceNoteHint => 'مثال: عدّ يدوي، ‎2025-03-04‎، ‏07:00–08:00';

  @override
  String get poissonArrivals => 'وصول عشوائي (بواسون)';

  @override
  String get poissonArrivalsHelp => 'عند الإيقاف: تصل المركبات بفواصل منتظمة.';

  @override
  String get noEntriesYet =>
      'ارسم الطرق أولًا: تدخل الحركة وتخرج من النموذج عند نهايات الطرق (الدوائر الخضراء).';

  @override
  String totalDemand(String flow) {
    return 'إجمالي الطلب الداخل: $flow مركبة/ساعة';
  }

  @override
  String entryFrom(String name) {
    return 'مدخل: $name';
  }

  @override
  String get flowVehPerHour => 'الحجم الداخل';

  @override
  String get vehPerHour => 'مركبة/س';

  @override
  String get vehicleMix => 'تركيبة المركبات';

  @override
  String get cars => 'سيارات';

  @override
  String get trucks => 'شاحنات';

  @override
  String get buses => 'حافلات';

  @override
  String mixMustBe100(String sum) {
    return 'يجب أن يكون مجموع التركيبة 100% (حاليًا $sum%)';
  }

  @override
  String get destinationsTitle => 'نسب الانعطاف / الوجهات';

  @override
  String get equalSplit => 'بالتساوي';

  @override
  String get normalize => 'ضبط إلى 100%';

  @override
  String shareTotal(String sum) {
    return 'المجموع $sum%';
  }

  @override
  String get turnLeft => 'يسار';

  @override
  String get turnThrough => 'مستقيم';

  @override
  String get turnRight => 'يمين';

  @override
  String get turnU => 'التفاف';

  @override
  String get runSimulation => 'تشغيل المحاكاة';

  @override
  String runButton(int n) {
    return 'محاكاة ($n تكرارات)';
  }

  @override
  String get phaseSubmitting => 'جارٍ إرسال التصميم إلى الخادم…';

  @override
  String phaseRunning(String pct, String msg) {
    return 'جارٍ المحاكاة… $pct% $msg';
  }

  @override
  String get stageQueued => 'بانتظار محاكي متاح';

  @override
  String get stageBuilding => 'إنشاء شبكة SUMO';

  @override
  String get stageRunning => 'تشغيل التكرارات';

  @override
  String get stageAnalysing => 'حساب النتائج';

  @override
  String get phaseFetching => 'جارٍ تنزيل النتائج والمسارات…';

  @override
  String get simulationFailed => 'لم تكتمل المحاكاة:';

  @override
  String get simulationDone =>
      'اكتملت المحاكاة. جميع الأرقام ناتجة عن هذا التشغيل.';

  @override
  String get viewResults => 'عرض';

  @override
  String get validateDesign => 'فحص التصميم بواسطة SUMO (دون حركة)';

  @override
  String get validationOk => 'أنشأ SUMO الشبكة دون تحذيرات.';

  @override
  String get validationOkWithWarnings => 'أنشأ SUMO الشبكة مع تحذيرات:';

  @override
  String get runSettings => 'إعدادات التشغيل';

  @override
  String get duration => 'المدة';

  @override
  String get warmup => 'فترة الإحماء';

  @override
  String get warmupHelp =>
      'تملأ فترة الإحماء الشبكة وتُستبعد من جميع الإحصاءات.';

  @override
  String get replications => 'التكرارات';

  @override
  String get baseSeed => 'البذرة العشوائية الأولى';

  @override
  String get replicationsHelp =>
      'يستخدم كل تكرار بذرة مختلفة؛ وتعرض النتائج المتوسط وفترة الثقة 95%. قارن النسخ باستخدام البذور نفسها.';

  @override
  String get timeStep => 'الخطوة الزمنية للمحاكاة';

  @override
  String get recordPlayback => 'تسجيل مواقع المركبات للعرض';

  @override
  String recordPlaybackHelp(String min) {
    return 'أول $min دقيقة من التكرار الأول، تمامًا كما حُسبت.';
  }

  @override
  String get playbackWindow => 'مدة العرض';

  @override
  String get driverBehaviour => 'سلوك السائقين';

  @override
  String get carFollowingModel => 'نموذج تتبع المركبات';

  @override
  String get modelEidm => 'EIDM – نموذج IDM الموسّع (افتراضي)';

  @override
  String get modelIdm => 'IDM – نموذج السائق الذكي';

  @override
  String get modelKrauss => 'Krauss (الافتراضي في SUMO)';

  @override
  String get carFollowingHelp =>
      'يضيف EIDM إلى IDM زمن الاستجابة وأخطاء التقدير وحدود التغير في التسارع. المعاملات هي قيم SUMO الافتراضية إلى أن تُعايَر ببيانات محلية.';

  @override
  String get driverHeterogeneity => 'أنماط سائقين متنوعة';

  @override
  String get driverHeterogeneityHelp =>
      'تنويع الفاصل الزمني والمسافات والتسارع واختيار السرعة وزمن الاستجابة بين السائقين (انتشارات مفترضة).';

  @override
  String get gapAcceptance => 'قبول الفجوات (معامل نفاد الصبر في SUMO، 0–1)';

  @override
  String get gapAcceptanceHelp =>
      'القيمة 0.5 تعيد إنتاج الطاقة الاستيعابية لمداخل إفساح الطريق والدوارات وفق دليل HCM الإصدار السادس في الاختبارات المرجعية؛ أما القيمة الافتراضية في SUMO (0) فتعطي 15–30% منها. عايِرها ببيانات محلية عند توفرها.';

  @override
  String get strictStop => 'توقف كامل إلزامي عند لافتات التوقف';

  @override
  String get strictStopHelp =>
      'عند الإيقاف (افتراضي): تستخدم المداخل المتحكم بها بالتوقف سلوك قبول الفجوات المعاير ميدانيًا كما في HCM. عند التشغيل: تتوقف كل مركبة عند الخط، ما يجعل التصريف في SUMO نحو 45% من المعدلات المرصودة.';

  @override
  String get reactionMin => 'أدنى زمن استجابة';

  @override
  String get reactionMax => 'أقصى زمن استجابة';

  @override
  String get signalTiming => 'توقيت الإشارات';

  @override
  String get signalTimingHelp =>
      'خطة زمنية ثابتة تُولَّد لجميع التقاطعات ذات الإشارات. تعديل كل طور على حدة يأتي في المرحلة الثانية.';

  @override
  String get cycleTime => 'زمن الدورة';

  @override
  String get autoYellow => 'زمن الأصفر حسب سرعة الاقتراب (SUMO)';

  @override
  String get yellowTime => 'زمن الأصفر';

  @override
  String get allRedTime => 'زمن الأحمر الشامل';

  @override
  String get leftGreen => 'زمن الأخضر المحمي للانعطاف يسارًا';

  @override
  String get leftGreenHelp =>
      'يُستخدم حيث توجد مسارات انعطاف يسار؛ 0 = بدون طور محمي.';

  @override
  String get phaseLayout => 'ترتيب الأطوار';

  @override
  String get layoutOpposites => 'المداخل المتقابلة معًا';

  @override
  String get layoutIncoming => 'مدخل واحد في كل طور';

  @override
  String get noResultsYet =>
      'لا توجد نتائج بعد. أدخل بيانات المرور وشغّل المحاكاة من تبويب المحاكاة.';

  @override
  String get resultsStale =>
      'تغيّر التصميم أو الإعدادات بعد هذا التشغيل. أعد التشغيل لتحديث النتائج.';

  @override
  String get reliability => 'الموثوقية';

  @override
  String resultMeta(String date, int n, String duration, String warmup) {
    return 'تشغيل $date · $n تكرارات · مدة $duration، مع استبعاد إحماء $warmup';
  }

  @override
  String get demandWasObserved => 'الطلب: أعداد مرصودة';

  @override
  String get demandWasAssumed => 'الطلب: سيناريو افتراضي (ليس قياسات)';

  @override
  String get kpiDelay => 'متوسط التأخير';

  @override
  String get kpiThroughput => 'عدد المركبات العابرة';

  @override
  String get kpiMaxQueue => 'أطول طابور';

  @override
  String get kpiWorstAvgQueue => 'متوسط الطابور في أسوأ مدخل';

  @override
  String get kpiTravelTime => 'زمن الرحلة';

  @override
  String get kpiSpeed => 'متوسط السرعة';

  @override
  String get kpiStops => 'عدد التوقفات لكل مركبة';

  @override
  String get kpiCompleted => 'المركبات المقاسة';

  @override
  String get unitSecPerVeh => 'ث/مركبة';

  @override
  String get perReplication => 'لكل تكرار';

  @override
  String get ci95 => 'فترة ثقة 95%';

  @override
  String get singleRun => 'تكرار واحد: لا توجد فترة ثقة';

  @override
  String get intersections => 'التقاطعات';

  @override
  String get delay => 'التأخير';

  @override
  String get losNote =>
      'حروف مستوى الخدمة استرشادية: حدود التأخير في دليل HCM الإصدار السادس مطبقة على التأخير المحسوب بالمحاكاة. استخدم المنهجية التي تطلبها الجهة المراجِعة.';

  @override
  String get approaches => 'المداخل';

  @override
  String get approach => 'المدخل';

  @override
  String get losShort => 'م.خ';

  @override
  String get queueAvg => 'متوسط الطابور';

  @override
  String get queueP95 => 'طابور المئين 95';

  @override
  String get queueMax => 'أقصى طابور';

  @override
  String get flow => 'الحجم';

  @override
  String get movements => 'الحركات (من → إلى)';

  @override
  String get fromTo => 'من → إلى';

  @override
  String get vehicles => 'المركبات';

  @override
  String warningsCount(int n, int high) {
    return 'جودة البيانات والتحذيرات ($n، منها $high جوهرية)';
  }

  @override
  String get assumptions => 'الافتراضات المستخدمة في هذا التشغيل';

  @override
  String get definitions => 'تعريفات المؤشرات';

  @override
  String get definitionsLanguageNote =>
      'التعريفات مقدمة من الخادم باللغة الإنجليزية.';

  @override
  String get exportCsv => 'تصدير النتائج (CSV)';

  @override
  String exportedTo(String path) {
    return 'حُفظ في $path';
  }

  @override
  String get playbackNeedsRun => 'شغّل المحاكاة لمشاهدة الحركة المرورية.';

  @override
  String get playbackNotRecorded => 'لم يسجّل هذا التشغيل مواقع المركبات.';

  @override
  String get goToSimulation => 'إعدادات المحاكاة';

  @override
  String get playbackNoTrajectory => 'الشبكة المحاكاة (لا توجد مركبات مسجلة)';

  @override
  String playbackInfo(int n, String from, String to) {
    return 'التكرار 1 من $n · $from–$to · المواقع كما حسبها SUMO تمامًا';
  }

  @override
  String get staleShort => 'قديمة';

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get restart => 'إعادة من البداية';

  @override
  String get stepBack => 'خطوة للخلف';

  @override
  String get stepForward => 'خطوة للأمام';

  @override
  String get playbackSpeed => 'سرعة العرض';

  @override
  String get heatmap => 'خريطة الازدحام الحرارية';

  @override
  String get heatmapTitle => 'متوسط السرعة / السرعة المسموحة';

  @override
  String get noData => 'لا توجد بيانات';

  @override
  String get colorBySpeed => 'تلوين المركبات حسب السرعة';

  @override
  String get followVehicle => 'متابعة';

  @override
  String vehicleSpeed(String kmh) {
    return 'السرعة $kmh كم/س';
  }

  @override
  String get vehicleLeft => 'خارج الشبكة في هذه اللحظة';

  @override
  String get issueNoRoads => 'لا يحتوي التصميم على طرق بعد.';

  @override
  String issueIsolatedNode(String node) {
    return 'العقدة $node غير متصلة وسيتم تجاهلها.';
  }

  @override
  String issueRoundaboutNeedsRoads(String node) {
    return 'الدوار $node يحتاج إلى طريقين متصلين على الأقل.';
  }

  @override
  String issueSignalAtDeadEnd(String node) {
    return 'العقدة $node نهاية طريق ولا يمكن تزويدها بإشارة.';
  }

  @override
  String issueRoadTooShort(String road) {
    return 'الطريق $road أقصر من متر واحد.';
  }

  @override
  String issueBayTooLong(String road, String bay) {
    return 'جيب الانعطاف بطول $bay م لا يتسع في الطريق $road.';
  }

  @override
  String get issueNoGates =>
      'لا توجد نهايات طرق: تحتاج الحركة إلى نهايات طرق للدخول والخروج من النموذج.';

  @override
  String get issueNoDemand => 'لم يتم إدخال أي حركة مرورية بعد (تبويب المرور).';

  @override
  String issueOriginNotGate(String node) {
    return 'حركة داخلة من $node الذي لم يعد نهاية طريق.';
  }

  @override
  String issueOriginNoLanes(String node) {
    return 'لا يوجد مسار يدخل الشبكة عند $node.';
  }

  @override
  String issueMixSum(String node, String sum) {
    return 'مجموع تركيبة المركبات عند $node يساوي $sum% بدلًا من 100%.';
  }

  @override
  String issueShareSum(String node, String sum) {
    return 'مجموع نسب الوجهات من $node يساوي $sum% بدلًا من 100%.';
  }

  @override
  String issueDestinationInvalid(String node, String dest) {
    return 'الحركة من $node متجهة إلى $dest حيث لا يوجد مسار خارج من الشبكة.';
  }

  @override
  String issueSameOriginDestination(String node) {
    return 'لا يمكن أن تعود الحركة من $node إلى نهاية الطريق نفسها.';
  }

  @override
  String get issueWarmupTooLong =>
      'يجب أن تكون فترة الإحماء أقصر من مدة المحاكاة.';

  @override
  String issueFewReplications(String n) {
    return 'عدد التكرارات $n فقط: يُوصى بخمسة على الأقل.';
  }

  @override
  String get issueEidmStep => 'يحتاج EIDM إلى خطوة زمنية 0.5 ث أو أقل.';
}
