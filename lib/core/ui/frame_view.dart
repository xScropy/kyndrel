import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:material_ui/material_ui.dart';

/// Decoded storyboard sheets and frames, most recently used kept (task 8.2).
///
/// One decode of a sheet serves every frame in it, so scrubbing across a
/// sheet decodes nothing. Images are shared as clones: a widget disposes
/// its own handle, the cache disposes the original when it evicts it.
class FrameImageCache {
  new({this.maxBytes = defaultMaxBytes});

  /// About four 1600×900 sheets.
  static const int defaultMaxBytes = 24 * 1024 * 1024;

  final int maxBytes;
  final _images = <String, ui.Image>{};
  final _loading = <String, Future<ui.Image?>>{};
  int _bytes = 0;

  int get bytes => _bytes;
  int get length => _images.length;

  /// Whether [path] is decoded or being decoded.
  bool has(String path) =>
      _images.containsKey(path) || _loading.containsKey(path);

  /// Starts decoding [path] for later (scrubbing towards it).
  void prefetch(String path) {
    if (has(path)) return;
    unawaited(load(path).then((image) => image?.dispose()));
  }

  /// A handle to the decoded [path] if it is in memory (the caller disposes
  /// it), else null.
  ui.Image? peek(String path) {
    final image = _images.remove(path);
    if (image == null) return null;
    _images[path] = image; // Most recently used.
    return image.clone();
  }

  /// Decodes [path] (once, however many ask) and returns a handle the
  /// caller disposes; null if it can't be read.
  Future<ui.Image?> load(String path) async {
    final hit = peek(path);
    if (hit != null) return hit;
    final image = await _loading.putIfAbsent(path, () => _decode(path));
    if (image == null) return null;
    return _images.containsKey(path) ? peek(path) : image.clone();
  }

  Future<ui.Image?> _decode(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      _images[path] = image;
      _bytes += _size(image);
      _evict();
      return image;
    } on Object {
      return null;
    } finally {
      unawaited(Future.microtask(() => _loading.remove(path)));
    }
  }

  static int _size(ui.Image i) => i.width * i.height * 4;

  void _evict() {
    while (_bytes > maxBytes && _images.length > 1) {
      final key = _images.keys.first;
      final image = _images.remove(key)!;
      _bytes -= _size(image);
      image.dispose();
    }
  }

  /// Frees every image (memory pressure, tests).
  void clear() {
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
    _bytes = 0;
  }
}

/// Decodes the sheets around [at] before the finger gets there (task 8.3):
/// the sheet under it and its neighbours, in every level that has them.
void prefetchSheets(FrameImageCache cache, Storyboard board, Duration at) {
  for (final l in board.levels) {
    final sheet = l.spec.sheetOf(l.spec.indexAt(at));
    for (final s in [sheet, sheet + 1, sheet - 1]) {
      if (l.sheets.contains(s)) {
        cache.prefetch(board.sheetPath(l.spec.index, s));
      }
    }
  }
}

final frameImageCacheProvider = Provider<FrameImageCache>((ref) {
  final cache = FrameImageCache();
  ref.onDispose(cache.clear);
  return cache;
});

/// Shows a [FrameRef]: a whole picture, or one cell of a sprite sheet cut
/// out on the GPU, covering its box. Keeps the previous picture until the
/// new one is decoded, so scrubbing never flashes empty. When the exact
/// frame replaces a storyboard cell (the finger rested), it fades in.
class FrameView extends ConsumerStatefulWidget {
  const new({
    required this.frame,
    this.width,
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final FrameRef frame;
  final double? width;
  final double aspectRatio;

  @override
  ConsumerState<FrameView> createState() => _FrameViewState();
}

class _FrameViewState extends ConsumerState<FrameView> {
  /// How long the exact frame takes to fade in over the storyboard cell.
  static const fade = Duration(milliseconds: 150);

  ui.Image? _image;
  FrameRef? _shown;
  int _request = 0;

  /// The storyboard cell the exact frame fades in over.
  ui.Image? _under;
  FrameRef? _underFrame;

  @override
  void initState() {
    super.initState();
    _show(widget.frame);
  }

  @override
  void didUpdateWidget(FrameView old) {
    super.didUpdateWidget(old);
    if (old.frame != widget.frame) _show(widget.frame);
  }

  void _show(FrameRef frame) {
    final id = ++_request;
    final cache = ref.read(frameImageCacheProvider);
    final hit = cache.peek(frame.path);
    if (hit != null) {
      _set(hit, frame);
      return;
    }
    unawaited(
      cache.load(frame.path).then((image) {
        if (!mounted || id != _request) {
          image?.dispose();
          return;
        }
        if (image != null) setState(() => _set(image, frame));
      }),
    );
  }

  void _set(ui.Image image, FrameRef frame) {
    _clearUnder();
    final old = _image;
    final oldFrame = _shown;
    // A sheet cell giving way to a whole picture: the sharper frame of the
    // same moment. Fade it in rather than snap.
    if (old != null && oldFrame?.cell != null && frame.cell == null) {
      _under = old;
      _underFrame = oldFrame;
    } else {
      old?.dispose();
    }
    _image = image;
    _shown = frame;
  }

  void _clearUnder() {
    _under?.dispose();
    _under = null;
    _underFrame = null;
  }

  @override
  void dispose() {
    _image?.dispose();
    _clearUnder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final shown = _shown;
    return SizedBox(
      width: widget.width,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: image == null || shown == null
            ? const ColoredBox(color: KyndrelColors.surface)
            : _under == null
            ? CustomPaint(painter: _FramePainter(image, shown))
            : TweenAnimationBuilder<double>(
                key: ValueKey(shown),
                tween: Tween(begin: 0, end: 1),
                duration: fade,
                onEnd: () => setState(_clearUnder),
                builder: (context, t, _) => CustomPaint(
                  painter: _FramePainter(
                    image,
                    shown,
                    under: _under,
                    underFrame: _underFrame,
                    opacity: t,
                  ),
                ),
              ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  new(this.image, this.frame, {this.under, this.underFrame, this.opacity = 1});

  final ui.Image image;
  final FrameRef frame;
  final ui.Image? under;
  final FrameRef? underFrame;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final u = under;
    final uf = underFrame;
    if (u != null && uf != null && opacity < 1) _draw(canvas, size, u, uf, 1);
    _draw(canvas, size, image, frame, opacity);
  }

  static void _draw(
    Canvas canvas,
    Size size,
    ui.Image image,
    FrameRef frame,
    double opacity,
  ) {
    var src = frame.sourceRect(image.width.toDouble(), image.height.toDouble());
    // Cover: crop the frame to the box's shape.
    final want = size.width / size.height;
    final have = src.width / src.height;
    if (have > want) {
      final w = src.height * want;
      src = Rect.fromLTWH(
        src.left + (src.width - w) / 2,
        src.top,
        w,
        src.height,
      );
    } else if (have < want) {
      final h = src.width / want;
      src = Rect.fromLTWH(
        src.left,
        src.top + (src.height - h) / 2,
        src.width,
        h,
      );
    }
    canvas.drawImageRect(
      image,
      src,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.image != image ||
      old.frame != frame ||
      old.opacity != opacity ||
      old.under != under;
}
