import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/features/info/media_info_dialog.dart';

void main() {
  test('formats mpv properties into readable rows', () {
    final s = MediaInfoSections.from({
      'filename': 'Film.mkv',
      'file-format': 'mkv',
      'file-size': '1610612736',
      'duration': '5400.5',
      'video-codec': 'HEVC',
      'video-params/w': '3840',
      'video-params/h': '2160',
      'container-fps': '23.976',
      'video-params/gamma': 'pq',
      'video-bitrate': '25000000',
      'audio-codec': 'E-AC-3',
      'audio-params/channel-count': '6',
      'audio-params/samplerate': '48000',
      'audio-bitrate': '640000',
      'hwdec-current': 'no',
    });
    expect(s.sections['File']!['Size'], '1.5 GB');
    expect(s.sections['File']!['Duration'], '1:30:00');
    expect(s.sections['Video']!['Resolution'], '3840 × 2160');
    expect(s.sections['Video']!['Frame rate'], '23.976 fps');
    expect(s.sections['Video']!['Dynamic range'], 'HDR10 (PQ)');
    expect(s.sections['Video']!['Bitrate'], '25.0 Mb/s');
    expect(s.sections['Video']!['Hardware decoding'], 'Off');
    expect(s.sections['Audio']!['Sample rate'], '48 kHz');
    expect(s.sections['Audio']!['Bitrate'], '640 kb/s');
    expect(s.toPlainText(), contains('Resolution: 3840 × 2160'));
  });
}
