import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:kyndrel/core/player/storyboard.dart';

/// Finds a show's opening and closing credits by comparing two episodes'
/// storyboards (task 8.9), the way streaming services find "Skip intro":
/// the same pictures, in the same order, in both episodes.

/// A 64-bit difference hash of [image]: 9×8 grey, each bit says whether a
/// pixel is brighter than its right neighbour. Near-identical pictures have
/// hashes a few bits apart.
int differenceHash(img.Image image) {
  final small = img.grayscale(
    img.copyResize(
      image,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    ),
  );
  var hash = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final a = small.getPixel(x, y).r;
      final b = small.getPixel(x + 1, y).r;
      hash = (hash << 1) | (a > b ? 1 : 0);
    }
  }
  return hash;
}

int hammingDistance(int a, int b) {
  var x = a ^ b;
  var n = 0;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}

/// Flat pictures (black, white, a title card on one colour) match anything:
/// they don't count.
bool _distinct(int hash) {
  final bits = hammingDistance(hash, 0);
  return bits >= 6 && bits <= 58;
}

/// Hashes of every frame of [level] of [board], null where there is none.
/// Decodes the sheets in a background isolate.
Future<List<int?>> storyboardHashes(Storyboard board, int level) {
  final l = board.levels[level];
  final sheets = <int, String>{
    for (final s in l.sheets) s: board.sheetPath(level, s),
  };
  final count = l.spec.count;
  final cols = l.spec.cols;
  final rows = l.spec.rows;
  final failed = l.failed;
  return Isolate.run(() {
    final out = List<int?>.filled(count, null);
    sheets.forEach((s, path) {
      img.Image? sheet;
      try {
        sheet = img.decodeJpg(File(path).readAsBytesSync());
      } on Object {
        sheet = null;
      }
      if (sheet == null) return;
      final w = sheet.width ~/ cols;
      final h = sheet.height ~/ rows;
      for (var cell = 0; cell < cols * rows; cell++) {
        final i = s * cols * rows + cell;
        if (i >= count || failed.contains(i)) continue;
        out[i] = differenceHash(
          img.copyCrop(
            sheet,
            x: (cell % cols) * w,
            y: (cell ~/ cols) * h,
            width: w,
            height: h,
          ),
        );
      }
    });
    return out;
  });
}

/// The longest run of frames that match between [a] and [b] at any
/// alignment: (start in a, start in b, length), or null below [minRun].
/// Frames are a match when their hashes are at most [maxDistance] bits
/// apart; flat frames never match.
({int a, int b, int length})? longestSharedRun(
  List<int?> a,
  List<int?> b, {
  int maxDistance = 10,
  int minRun = 3,
}) {
  ({int a, int b, int length})? best;
  // Every shift of b against a.
  for (var shift = -(b.length - 1); shift < a.length; shift++) {
    var run = 0;
    for (var i = 0; i < a.length; i++) {
      final j = i - shift;
      final ha = a[i];
      final hb = j >= 0 && j < b.length ? b[j] : null;
      final match =
          ha != null &&
          hb != null &&
          _distinct(ha) &&
          _distinct(hb) &&
          hammingDistance(ha, hb) <= maxDistance;
      if (match) {
        run++;
        if (run >= minRun && (best == null || run > best.length)) {
          best = (a: i - run + 1, b: j - run + 1, length: run);
        }
      } else {
        run = 0;
      }
    }
  }
  return best;
}

/// What was found for one episode.
@immutable
class IntroRange {
  const new({this.introStart, this.introEnd, this.creditsStart});

  final Duration? introStart;
  final Duration? introEnd;

  /// Where the closing credits begin.
  final Duration? creditsStart;

  bool get isEmpty => introEnd == null && creditsStart == null;
}

/// Shortest and longest believable opening.
const minIntro = Duration(seconds: 15);
const maxIntro = Duration(minutes: 3);

/// The shared opening (first 40 %) and closing (last 30 %) of two
/// episodes' frame hashes, [stepA] and [stepB] apart: the ranges in a and in
/// b.
(IntroRange, IntroRange) findIntroAndCredits(
  List<int?> a,
  List<int?> b, {
  required Duration stepA,
  required Duration stepB,
}) {
  IntroRange? introA;
  IntroRange? introB;
  final headA = (a.length * 0.4).ceil();
  final headB = (b.length * 0.4).ceil();
  final head = longestSharedRun(a.sublist(0, headA), b.sublist(0, headB));
  if (head != null) {
    final length = stepA * head.length;
    if (length >= minIntro && length <= maxIntro) {
      introA = IntroRange(
        introStart: stepA * head.a,
        introEnd: stepA * (head.a + head.length),
      );
      introB = IntroRange(
        introStart: stepB * head.b,
        introEnd: stepB * (head.b + head.length),
      );
    }
  }
  final tailA = (a.length * 0.7).floor();
  final tailB = (b.length * 0.7).floor();
  final tail = longestSharedRun(a.sublist(tailA), b.sublist(tailB));
  Duration? creditsA;
  Duration? creditsB;
  if (tail != null && stepA * tail.length >= const Duration(seconds: 20)) {
    creditsA = stepA * (tailA + tail.a);
    creditsB = stepB * (tailB + tail.b);
  }
  return (
    IntroRange(
      introStart: introA?.introStart,
      introEnd: introA?.introEnd,
      creditsStart: creditsA,
    ),
    IntroRange(
      introStart: introB?.introStart,
      introEnd: introB?.introEnd,
      creditsStart: creditsB,
    ),
  );
}

/// Chapters that are an opening or credits, by name.
final introChapter = RegExp(
  r'^(intro|opening|op|opening credits|title sequence)\b',
  caseSensitive: false,
);
final creditsChapter = RegExp(
  r'^(credits|ending|ed|end credits|outro|closing credits)\b',
  caseSensitive: false,
);
