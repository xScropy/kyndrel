import 'dart:convert';

/// 64-bit FNV-1a of [text] as 16 hex digits. Stable across runs; used for
/// cache file names (thumbnails, translations). Not cryptographic.
String fnv1a64(String text) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in utf8.encode(text)) {
    hash = ((hash ^ BigInt.from(b)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
