import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kyndrel/core/player/intro_detector.dart';

/// Task 8.9: finding the shared opening of two episodes.
void main() {
  final random = math.Random(7);

  /// A random "scene" hash with plenty of set and clear bits.
  int scene() {
    var h = 0;
    for (var i = 0; i < 64; i++) {
      h = (h << 1) | (random.nextBool() ? 1 : 0);
    }
    return h;
  }

  test('similar pictures hash close, different ones far', () {
    final a = img.Image(width: 64, height: 36);
    for (var x = 0; x < 64; x++) {
      for (var y = 0; y < 36; y++) {
        a.setPixelRgb(x, y, x * 4, y * 7, (x * y) % 255);
      }
    }
    final b = img.adjustColor(a.clone(), brightness: 1.05);
    final c = img.flipHorizontal(a.clone());
    final ha = differenceHash(a);
    expect(hammingDistance(ha, differenceHash(b)), lessThanOrEqualTo(6));
    expect(hammingDistance(ha, differenceHash(c)), greaterThan(20));
    expect(hammingDistance(0xFF, 0x0F), 4);
  });

  test('the shared opening is found at different offsets', () {
    // A 30-frame opening (every 2 s: 60 s) after a 10-frame cold open in
    // episode A and right at the start in episode B.
    final intro = [for (var i = 0; i < 30; i++) scene()];
    final a = [
      for (var i = 0; i < 10; i++) scene(),
      ...intro,
      for (var i = 0; i < 110; i++) scene(),
    ];
    final b = [...intro, for (var i = 0; i < 120; i++) scene()];
    final run = longestSharedRun(a, b)!;
    expect((run.a, run.b, run.length), (10, 0, 30));

    const step = Duration(seconds: 2);
    final (ra, rb) = findIntroAndCredits(a, b, stepA: step, stepB: step);
    expect(ra.introStart, const Duration(seconds: 20));
    expect(ra.introEnd, const Duration(seconds: 80));
    expect(rb.introStart, Duration.zero);
    expect(rb.introEnd, const Duration(seconds: 60));
  });

  test('closing credits; black frames never match; too short is no intro', () {
    final credits = [for (var i = 0; i < 15; i++) scene()];
    final a = [for (var i = 0; i < 135; i++) scene(), ...credits];
    final b = [
      for (var i = 0; i < 125; i++) scene(),
      ...credits,
      for (var i = 0; i < 5; i++) scene(),
    ];
    const step = Duration(seconds: 2);
    final (ra, rb) = findIntroAndCredits(a, b, stepA: step, stepB: step);
    expect(ra.creditsStart, const Duration(seconds: 270));
    expect(rb.creditsStart, const Duration(seconds: 250));
    expect(ra.introEnd, isNull);

    // Black frames (hash 0) everywhere: no "match".
    final black = List<int?>.filled(60, 0);
    expect(longestSharedRun(black, black), isNull);

    // Three matching frames 2 s apart: 6 s, not an intro.
    final short = [for (var i = 0; i < 3; i++) scene()];
    final (sa, _) = findIntroAndCredits(
      [...short, for (var i = 0; i < 50; i++) scene()],
      [...short, for (var i = 0; i < 50; i++) scene()],
      stepA: step,
      stepB: step,
    );
    expect(sa.introEnd, isNull);
  });

  test('chapter names', () {
    for (final n in ['Intro', 'Opening', 'OP', 'Opening Credits']) {
      expect(introChapter.hasMatch(n), isTrue, reason: n);
    }
    for (final n in ['Credits', 'Ending', 'ED', 'End Credits']) {
      expect(creditsChapter.hasMatch(n), isTrue, reason: n);
    }
    expect(introChapter.hasMatch('Chapter 1'), isFalse);
  });
}
