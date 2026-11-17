import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/features/playback/open/open_actions.dart';

void main() {
  test('looksOpenable accepts URLs and absolute paths only', () {
    for (final ok in [
      'https://example.com/video.mp4',
      'rtsp://camera.local/stream',
      'file:///home/me/a.mkv',
      '/home/me/a.mkv',
      r'C:\Videos\a.mkv',
      'D:/a.mp4',
      r'\\nas\share\a.mkv',
      '~/a.mkv',
    ]) {
      expect(OpenActions.looksOpenable(ok), isTrue, reason: ok);
    }
    for (final bad in ['', 'hello world', 'a.mkv', 'line1\nline2']) {
      expect(OpenActions.looksOpenable(bad), isFalse, reason: bad);
    }
  });
}
