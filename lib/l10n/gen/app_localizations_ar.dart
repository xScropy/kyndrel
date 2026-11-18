// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get playTooltip => 'تشغيل (مسافة)';

  @override
  String get pauseTooltip => 'إيقاف مؤقت (مسافة)';

  @override
  String get previousTooltip => 'السابق (P)';

  @override
  String get nextTooltip => 'التالي (N)';

  @override
  String backSeconds(int seconds) {
    return 'رجوع $seconds ث';
  }

  @override
  String forwardSeconds(int seconds) {
    return 'تقديم $seconds ث';
  }

  @override
  String get muteTooltip => 'كتم الصوت (M)';

  @override
  String get unmuteTooltip => 'إلغاء الكتم (M)';

  @override
  String get volume => 'مستوى الصوت';

  @override
  String get fullscreenTooltip => 'ملء الشاشة (F)';

  @override
  String get exitFullscreenTooltip => 'الخروج من ملء الشاشة (F)';

  @override
  String get showTotalTime => 'إظهار المدة الكاملة';

  @override
  String get showRemainingTime => 'إظهار الوقت المتبقي';

  @override
  String get live => 'مباشر';

  @override
  String get back => 'رجوع';

  @override
  String get mediaInfo => 'معلومات الوسائط';

  @override
  String get minimize => 'تصغير';

  @override
  String get maximize => 'تكبير';

  @override
  String get restore => 'استعادة';

  @override
  String get close => 'إغلاق';

  @override
  String get closeEsc => 'إغلاق (Esc)';

  @override
  String get copyLog => 'نسخ السجل';

  @override
  String get fitAndAspect => 'الملاءمة والأبعاد';

  @override
  String get fitHeader => 'الملاءمة';

  @override
  String get zoomHeader => 'التكبير';

  @override
  String get rotateHeader => 'التدوير';

  @override
  String get zoomIn => 'تكبير';

  @override
  String get zoomOut => 'تصغير';

  @override
  String get rotateClockwise => 'تدوير 90° مع عقارب الساعة';

  @override
  String get reset => 'إعادة الضبط';

  @override
  String get openMediaHeader => 'فتح وسائط';

  @override
  String get openFileShortcut => 'فتح ملف…  (Ctrl+O)';

  @override
  String get pastePathOrUrl => 'الصق مسارًا أو رابطًا';

  @override
  String get open => 'فتح';

  @override
  String get dropHint =>
      'أو أفلت ملفًا في أي مكان من النافذة. يفتح ‎Ctrl+N البث والمشاركات ومجلدات WebDAV.';

  @override
  String resumeFrom(String time) {
    return 'المتابعة من $time؟';
  }

  @override
  String get startOver => 'البدء من جديد';

  @override
  String get resume => 'متابعة';

  @override
  String get speedAndSleep => 'السرعة والمؤقت';

  @override
  String speedOsd(String rate) {
    return 'السرعة $rate';
  }

  @override
  String get playbackSpeedHeader => 'سرعة التشغيل';

  @override
  String get sleepTimerHeader => 'مؤقت النوم';

  @override
  String get sleepCancelHint => 'اختر الخيار نفسه مرة أخرى للإلغاء.';

  @override
  String get defaultBadge => 'افتراضي';

  @override
  String get custom => 'مخصص';

  @override
  String get apply => 'تطبيق';

  @override
  String get queueTooltip => 'قائمة التشغيل (Q)';

  @override
  String queueCountTooltip(int count) {
    return 'قائمة التشغيل · $count (Q)';
  }

  @override
  String queueTitle(int count) {
    return 'قائمة التشغيل · $count';
  }

  @override
  String get shuffleOn => 'التشغيل العشوائي مفعّل';

  @override
  String get shuffleOff => 'التشغيل العشوائي متوقف';

  @override
  String get repeatOff => 'التكرار متوقف';

  @override
  String get repeatAll => 'تكرار الكل';

  @override
  String get repeatOne => 'تكرار واحد';

  @override
  String get queueEmpty => 'قائمة التشغيل فارغة.';

  @override
  String get clear => 'مسح';

  @override
  String get folder => 'مجلد';

  @override
  String get add => 'إضافة';

  @override
  String get remove => 'إزالة';

  @override
  String get continueWatching => 'متابعة المشاهدة';

  @override
  String get recent => 'الأخيرة';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get removeFromHistory => 'إزالة من السجل';

  @override
  String get justNow => 'الآن';

  @override
  String get yesterday => 'أمس';

  @override
  String get menuOpenFile => 'فتح ملف…';

  @override
  String get menuOpenFolder => 'فتح مجلد…';

  @override
  String get menuOpenClipboard => 'فتح من الحافظة';

  @override
  String get menuOpenStream => 'فتح بث شبكي…';

  @override
  String get menuEditDetails => 'تعديل التفاصيل…';

  @override
  String get menuScreenshot => 'لقطة شاشة  (Ctrl+S)';

  @override
  String get menuSubtitlesAudio => 'الترجمة والصوت';

  @override
  String get menuEffects => 'مؤثرات الصورة والصوت…';

  @override
  String get menuSettings => 'الإعدادات…';

  @override
  String get dropToPlay => 'أفلت للتشغيل';

  @override
  String get subtitlesAudioTooltip => 'الترجمة والصوت (S)';

  @override
  String get subtitles => 'الترجمة';

  @override
  String get subtitlesHeader => 'الترجمة';

  @override
  String get audioHeader => 'الصوت';

  @override
  String get syncOffset => 'إزاحة المزامنة';

  @override
  String get style => 'النمط';

  @override
  String get off => 'إيقاف';

  @override
  String get subtitleSearchHint => 'العنوان، أو \"Show S01E02\"';

  @override
  String get search => 'بحث';

  @override
  String get findMoreSubtitles => 'البحث عن ترجمات أخرى';

  @override
  String get loadFile => 'تحميل ملف';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsPlayback => 'التشغيل';

  @override
  String get settingsSubtitles => 'الترجمة';

  @override
  String get settingsAudio => 'الصوت';

  @override
  String get settingsEffects => 'المؤثرات';

  @override
  String get settingsVideo => 'الفيديو';

  @override
  String get settingsPicture => 'الصورة';

  @override
  String get settingsShortcuts => 'الاختصارات';

  @override
  String get settingsLibrary => 'المكتبة';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsAdvanced => 'متقدم';

  @override
  String get settingsAbout => 'حول';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get openSourceLicences => 'تراخيص البرمجيات المفتوحة';

  @override
  String get diagnosticsHeader => 'التشخيص';

  @override
  String hardwareDecoding(String hwdec) {
    return 'فك الترميز بالعتاد: $hwdec';
  }

  @override
  String get softwareDecoding => 'فك الترميز بالبرمجيات';

  @override
  String get seekLabel => 'التقديم والإرجاع';

  @override
  String seekValue(String elapsed, String total) {
    return '$elapsed من $total';
  }

  @override
  String get videoSurface => 'الفيديو';

  @override
  String get videoSurfaceHint =>
      'انقر لإظهار عناصر التحكم، وانقر مرتين لملء الشاشة';

  @override
  String updateAvailable(String version) {
    return 'يتوفر Kyndrel $version';
  }

  @override
  String get updateInstall => 'التثبيت وإعادة التشغيل';

  @override
  String get updateDownload => 'تنزيل';

  @override
  String get updateWhatsNew => 'ما الجديد';

  @override
  String get updateLater => 'لاحقًا';

  @override
  String updateDownloading(int percent) {
    return 'جارٍ تنزيل التحديث… $percent٪';
  }

  @override
  String get updateUpToDate => 'Kyndrel محدّث.';

  @override
  String updateFailed(String reason) {
    return 'تعذر التحقق من التحديثات: $reason';
  }

  @override
  String get updateCheckNow => 'التحقق من التحديثات';

  @override
  String get crashTitle => 'توقف Kyndrel بشكل غير متوقع';

  @override
  String get crashBodyExit =>
      'انتهت الجلسة السابقة دون إغلاق طبيعي. هل تريد الإبلاغ عن ذلك؟ سيفتح هذا بلاغًا على GitHub في المتصفح مع الإصدار ونظام التشغيل ونهاية السجل. يمكنك تعديله أو تجاهله قبل الإرسال.';

  @override
  String get crashBodyError =>
      'حدث خطأ في الجلسة السابقة. هل تريد الإبلاغ عنه؟ سيفتح هذا بلاغًا معبأً مسبقًا على GitHub في المتصفح، ولا يُرسل شيء ما لم ترسله أنت.';

  @override
  String get crashReport => 'الإبلاغ على GitHub';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get viewLog => 'عرض السجل';

  @override
  String get logTitle => 'السجل';

  @override
  String get logCopy => 'نسخ';

  @override
  String get logCopied => 'تم نسخ السجل';

  @override
  String get logOpenFolder => 'فتح مجلد السجلات';

  @override
  String get logEmpty => 'لا يوجد شيء في السجل بعد.';

  @override
  String logLevelAndUp(String level) {
    return '$level فأعلى';
  }

  @override
  String get upNext => 'التالي';

  @override
  String upNextIn(int seconds) {
    return 'يبدأ خلال $seconds ث';
  }

  @override
  String get upNextPlayNow => 'تشغيل الآن';

  @override
  String get upNextCancel => 'إلغاء';

  @override
  String get onThisPhone => 'على هذا الهاتف';

  @override
  String get showPhoneVideos => 'عرض الفيديوهات على هذا الهاتف';

  @override
  String get phoneVideosDenied => 'يحتاج Kyndrel إلى إذن لعرض فيديوهاتك.';

  @override
  String get phoneVideosNone => 'لا توجد فيديوهات على هذا الهاتف بعد.';

  @override
  String get allFolders => 'الكل';

  @override
  String get settingsGestures => 'الإيماءات';

  @override
  String get more => 'المزيد';

  @override
  String get moreQueue => 'قائمة التشغيل';

  @override
  String get morePicture => 'الصورة';

  @override
  String get moreTranslate => 'الترجمة الآلية';

  @override
  String get moreSpeed => 'السرعة والمؤقت';

  @override
  String get moreCast => 'البث';

  @override
  String get moreDownload => 'تنزيل';

  @override
  String get rotate => 'تدوير الشاشة';
}
