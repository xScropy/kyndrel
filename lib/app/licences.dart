import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds what Flutter doesn't list on its own to Settings › About ›
/// Open-source licences (task 5.8): the bundled fonts' OFL texts and the
/// libmpv/FFmpeg notice. See ATTRIBUTION.md for the full audit.
void registerBundledLicences() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Inter',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Noto Sans Arabic',
    ], await rootBundle.loadString('assets/fonts/NotoSansArabic-OFL.txt'));
    yield const LicenseEntryWithLineBreaks(['libmpv', 'FFmpeg'], mpvNotice);
  });
}

const mpvNotice = '''
Kyndrel plays media with libmpv (https://mpv.io) and FFmpeg
(https://ffmpeg.org).

Windows builds bundle libmpv from media-kit/libmpv-win32-video-build
(release 2023-09-24), a GPL-2.0-or-later build of mpv and FFmpeg.
macOS builds bundle libmpv-darwin-build v0.6.0 ("video-default"), an
LGPL-2.1-or-later build. The Linux AppImage bundles Ubuntu 24.04's
libmpv2 and FFmpeg libraries (GPL-2.0-or-later); the .deb uses the
system's libmpv.

The corresponding source code for these builds is available from
https://github.com/media-kit/libmpv-win32-video-build,
https://github.com/media-kit/libmpv-darwin-build and Ubuntu's source
packages (mpv, ffmpeg). Kyndrel itself is GPL-3.0:
https://github.com/xScropy/kyndrel. Details: ATTRIBUTION.md.''';
