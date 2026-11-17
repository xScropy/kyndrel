import 'dart:io';
import 'dart:typed_data';

/// OpenSubtitles "moviehash": file size plus the 64-bit little-endian sums of
/// the first and last 64 KiB, as 16 hex digits. Null if the file is smaller
/// than 128 KiB.
Future<String?> computeMovieHash(File file) async {
  const chunk = 64 * 1024;
  final length = await file.length();
  if (length < chunk * 2) return null;
  final raf = await file.open();
  try {
    final head = await raf.read(chunk);
    await raf.setPosition(length - chunk);
    final tail = await raf.read(chunk);
    var hash = BigInt.from(length);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final bytes in [head, tail]) {
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i < chunk; i += 8) {
        final word =
            BigInt.from(data.getUint32(i, Endian.little)) |
            (BigInt.from(data.getUint32(i + 4, Endian.little)) << 32);
        hash = (hash + word) & mask;
      }
    }
    return hash.toRadixString(16).padLeft(16, '0');
  } finally {
    await raf.close();
  }
}
