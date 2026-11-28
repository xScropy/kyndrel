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
  String get volumeMuted => 'صامت';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String endsAt(String time) {
    return 'ينتهي $time';
  }

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

  @override
  String get morePip => 'نافذة صغيرة';

  @override
  String get subtitleNotShown => 'تعذّر عرض مسار الترجمة هذا';

  @override
  String get libraryHome => 'الرئيسية';

  @override
  String get libraryVideos => 'الفيديو';

  @override
  String get libraryMusic => 'الموسيقى';

  @override
  String get libraryFolders => 'المجلدات';

  @override
  String get libraryAllVideos => 'كل الفيديوهات';

  @override
  String get librarySearch => 'بحث';

  @override
  String get librarySort => 'ترتيب';

  @override
  String get sortDate => 'تاريخ الإضافة';

  @override
  String get sortName => 'الاسم';

  @override
  String get sortSize => 'الحجم';

  @override
  String get sortLength => 'المدة';

  @override
  String get layoutList => 'قائمة';

  @override
  String get layoutGrid => 'شبكة';

  @override
  String get libraryRefresh => 'تحديث';

  @override
  String get libraryEmptyVideos => 'لم يُعثر على فيديوهات بعد';

  @override
  String get libraryNoMatch => 'لا شيء يطابق بحثك';

  @override
  String get libraryAllowTitle => 'اعرض الفيديوهات والموسيقى على هذا الهاتف';

  @override
  String get libraryAllow => 'السماح بالوصول';

  @override
  String get libraryScanning => 'جارٍ البحث عن الفيديوهات والموسيقى…';

  @override
  String get libraryManageFolders => 'مجلدات المكتبة';

  @override
  String get libraryAddFolder => 'إضافة مجلد';

  @override
  String get libraryRemoveFolder => 'إزالة';

  @override
  String get libraryDefaultFolders =>
      'تُستخدم مجلدات الفيديو والموسيقى لديك حتى تضيف مجلداتك.';

  @override
  String get libraryNew => 'جديد';

  @override
  String get libraryPlay => 'تشغيل';

  @override
  String get libraryEnqueue => 'إضافة إلى قائمة التشغيل';

  @override
  String get libraryOpenFolder => 'إظهار في المجلد';

  @override
  String get libraryDetails => 'التفاصيل';

  @override
  String get detailFolder => 'المجلد';

  @override
  String get detailLength => 'المدة';

  @override
  String get detailResolution => 'الدقة';

  @override
  String get detailVideo => 'الفيديو';

  @override
  String get detailAudio => 'الصوت';

  @override
  String get detailSize => 'الحجم';

  @override
  String get detailModified => 'آخر تعديل';

  @override
  String get detailAdded => 'أضيف';

  @override
  String get detailWatched => 'تمت المشاهدة';

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو',
      many: '$count فيديو',
      few: '$count فيديوهات',
      two: 'فيديوهان',
      one: 'فيديو واحد',
      zero: 'لا فيديوهات',
    );
    return '$_temp0';
  }

  @override
  String get musicSongs => 'الأغاني';

  @override
  String get musicAlbums => 'الألبومات';

  @override
  String get musicArtists => 'الفنانون';

  @override
  String get musicShuffle => 'تشغيل الكل عشوائيًا';

  @override
  String get musicPlayAll => 'تشغيل الكل';

  @override
  String get unknownAlbum => 'ألبوم غير معروف';

  @override
  String get unknownArtist => 'فنان غير معروف';

  @override
  String get libraryEmptyMusic => 'لم يُعثر على موسيقى بعد';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أغنية',
      many: '$count أغنية',
      few: '$count أغانٍ',
      two: 'أغنيتان',
      one: 'أغنية واحدة',
      zero: 'لا أغاني',
    );
    return '$_temp0';
  }

  @override
  String get musicMinimize => 'العودة إلى المكتبة';

  @override
  String get musicNext => 'التالي';

  @override
  String get settingsMusic => 'الموسيقى';

  @override
  String get musicWavesSetting => 'موجات تتبع الموسيقى';

  @override
  String get musicWavesHelp =>
      'موجات برتقالية تحت الأسطوانة تتحرك مع ارتفاع الصوت.';

  @override
  String get reduceMotionSetting => 'حركة أقل';

  @override
  String get reduceMotionHelp => 'تبقى الأسطوانة ثابتة وتتحرك الموجات بهدوء.';

  @override
  String get libraryViewRecent => 'أضيفت مؤخرًا';

  @override
  String get libraryViewPlaylists => 'قوائم التشغيل';

  @override
  String get libraryContinue => 'تابع المشاهدة';

  @override
  String librarySelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر محدد',
      many: '$count عنصرًا محددًا',
      few: '$count عناصر محددة',
      two: 'عنصران محددان',
      one: 'عنصر محدد',
      zero: 'لا شيء محدد',
    );
    return '$_temp0';
  }

  @override
  String get librarySelectAll => 'تحديد الكل';

  @override
  String get libraryAddToPlaylist => 'أضف إلى قائمة تشغيل';

  @override
  String get libraryNewPlaylist => 'قائمة تشغيل جديدة';

  @override
  String get libraryPlaylistName => 'اسم قائمة التشغيل';

  @override
  String get libraryRename => 'إعادة تسمية';

  @override
  String get libraryDelete => 'حذف';

  @override
  String libraryDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نقل $count ملف إلى سلة المهملات؟',
      many: 'نقل $count ملفًا إلى سلة المهملات؟',
      few: 'نقل $count ملفات إلى سلة المهملات؟',
      two: 'نقل الملفين إلى سلة المهملات؟',
      one: 'نقل هذا الملف إلى سلة المهملات؟',
      zero: 'لا ملفات',
    );
    return '$_temp0';
  }

  @override
  String get libraryMove => 'نقل إلى…';

  @override
  String get libraryShare => 'مشاركة';

  @override
  String get libraryMarkWatched => 'تعليم كمُشاهَد';

  @override
  String get libraryMarkUnwatched => 'تعليم كغير مُشاهَد';

  @override
  String get libraryPin => 'تثبيت في الأعلى';

  @override
  String get libraryUnpin => 'إلغاء التثبيت';

  @override
  String get libraryHide => 'إخفاء المجلد';

  @override
  String get libraryUnhide => 'إظهار المجلد';

  @override
  String get libraryShowHidden => 'إظهار المجلدات المخفية';

  @override
  String get libraryMakePrivate => 'جعله خاصًا';

  @override
  String get libraryMakePublic => 'إزالة من الخاص';

  @override
  String get libraryPrivate => 'المجلدات الخاصة';

  @override
  String get libraryLock => 'قفل المجلدات الخاصة';

  @override
  String get libraryPinTitle => 'أدخل رمز PIN';

  @override
  String get librarySetPin => 'اختر رمز PIN (من 4 إلى 8 أرقام)';

  @override
  String get libraryWrongPin => 'رمز PIN غير صحيح';

  @override
  String get libraryPlayAll => 'تشغيل الكل';

  @override
  String get libraryShuffle => 'تشغيل عشوائي';

  @override
  String get libraryDescending => 'الأحدث أو الأكبر أولًا';

  @override
  String get layoutCompact => 'مضغوط';

  @override
  String get libraryGridSmall => 'شبكة صغيرة';

  @override
  String get libraryGridLarge => 'شبكة كبيرة';

  @override
  String get libraryFilterUnwatched => 'غير المُشاهَدة فقط';

  @override
  String get libraryFilterHd => 'دقة عالية فأعلى';

  @override
  String get libraryFilterSubtitles => 'مع ترجمة';

  @override
  String get libraryLastPlayed => 'آخر تشغيل';

  @override
  String get libraryPlaylistEmpty =>
      'لا توجد قوائم تشغيل بعد. حدد مقاطع وأضفها إلى قائمة.';

  @override
  String get librarySmartUnwatched => 'مقاطع لم تُشاهَد';

  @override
  String get librarySmartRecent => 'أضيفت هذا الشهر';

  @override
  String libraryActionFailed(String name) {
    return 'تعذّر ذلك: $name';
  }

  @override
  String get playlistRename => 'إعادة تسمية قائمة التشغيل';

  @override
  String get playlistDelete => 'حذف قائمة التشغيل';

  @override
  String get playlistRemove => 'إزالة من قائمة التشغيل';

  @override
  String get libraryFilters => 'عوامل التصفية';

  @override
  String get libraryFolderActions => 'المجلد';

  @override
  String get libraryBrowse => 'تصفح';

  @override
  String get browseDevice => 'هذا الجهاز';

  @override
  String get browseNetwork => 'الشبكة';

  @override
  String get browseHome => 'المجلد الرئيسي';

  @override
  String get browseRoot => 'القرص كاملًا';

  @override
  String get browseAddServer => 'إضافة خادم';

  @override
  String get browseServerKind => 'النوع';

  @override
  String get browseServerName => 'الاسم';

  @override
  String get browseServerAddress => 'العنوان';

  @override
  String get browseUser => 'اسم المستخدم (اختياري)';

  @override
  String get browsePassword => 'كلمة المرور';

  @override
  String get browseSave => 'حفظ';

  @override
  String get browseRemove => 'إزالة الخادم';

  @override
  String get browseSearching => 'جارٍ البحث عن خوادم الوسائط…';

  @override
  String get browseNoServers => 'لم يُعثر على خوادم وسائط في هذه الشبكة.';

  @override
  String get browseEmpty => 'لا مجلدات أو ملفات قابلة للتشغيل هنا.';

  @override
  String browseFailed(String reason) {
    return 'تعذّر فتح هذا المجلد: $reason';
  }

  @override
  String get browseOpenOnly =>
      'لا يمكن عرض محتوى هذا النوع من الخوادم: تُفتح ملفاته بالعنوان.';

  @override
  String get browseFind => 'بحث في هذا المجلد';

  @override
  String get bookmarks => 'العلامات المرجعية';

  @override
  String get bookmarksEmpty =>
      'لا توجد علامات بعد. اضغط B لإضافة علامة عند الموضع الحالي.';

  @override
  String get bookmarkAdd => 'أضف علامة هنا';

  @override
  String get jumpToTime => 'الانتقال إلى وقت';

  @override
  String get jumpToTimeHint => '‎1:23:45 أو 83:10 أو 90 أو ‎50%';

  @override
  String get decoderTooltip =>
      'فك الترميز: بالعتاد، بالعتاد مع النسخ، أو بالبرمجيات';

  @override
  String get loadAudioFile => 'تحميل ملف صوتي';

  @override
  String get libraryForget => 'إزالة من السجل';

  @override
  String get subtitleLines => 'أسطر الترجمة';

  @override
  String get subtitleLinesUnavailable =>
      'تُعرض الأسطر لملفات الترجمة. حمّل ملفًا أو اختر مسارًا من ملف.';

  @override
  String get copy => 'نسخ';

  @override
  String get quickCommands => 'أوامر سريعة';

  @override
  String get quickCommandsEmpty =>
      'لا أوامر سريعة بعد. أضفها من الإعدادات › متقدم.';

  @override
  String get skipIntro => 'تخطي المقدمة';

  @override
  String get skipCredits => 'تخطي الشارة';

  @override
  String get nextEpisode => 'الحلقة التالية';

  @override
  String get homeSearchHint => 'ابحث في الفيديوهات';

  @override
  String get homeResume => 'استكمال';

  @override
  String get homeStartOver => 'من البداية';

  @override
  String get homeContinueTitle => 'تابع المشاهدة';

  @override
  String get homeRecentlyAdded => 'أُضيفت مؤخرًا';

  @override
  String get homeHistory => 'السجل';

  @override
  String get homeOpenTitle => 'شغّل أي شيء';

  @override
  String get homeOpenSubtitle =>
      'افتح ملفًا أو الصق رابطًا. ستظهر فيديوهاتك هنا أثناء المشاهدة.';

  @override
  String homeLeft(String time) {
    return 'متبقٍ $time';
  }

  @override
  String get homeChip => 'تابع المشاهدة';
}
