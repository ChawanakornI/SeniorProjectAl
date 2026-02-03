import 'dart:io';
// import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'api_config.dart';

/// Annotate Screen
/// ✅ Pen / Eraser (BlendMode.clear)
/// ✅ Bounding box tool
/// ✅ Undo / Redo (works for BOTH strokes + boxes, per image)
/// ✅ Bin (clear current image)
/// ✅ Color palette (FULL, not reduced)
/// ✅ Brush size + opacity
/// ✅ Class dropdown
/// ✅ Zoom in/out (image + brush + boxes scale together)
/// ✅ Next/Prev buttons INSIDE image
class AnnotateScreen extends StatefulWidget {
  final String caseId;
  final List<String> imagePaths;
  final int initialIndex;

  const AnnotateScreen({
    super.key,
    required this.caseId,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  @override
  State<AnnotateScreen> createState() => _AnnotateScreenState();
}

enum _ToolMode { pen, eraser, box }

class _AnnotateScreenState extends State<AnnotateScreen> {
  // ===== Controls =====
  double brushSize = 18;
  double brushOpacity = 0.85;
  Color selectedColor = const Color(0xFFEE5351);

  String? selectedClass;
  final List<String> classes = const [
    'mel',
    'bcc',
    'akiec',
    'bkl',
    'nv',
    'df',
    'vasc',
    'unknown',
  ];

  _ToolMode mode = _ToolMode.pen;
  double zoom = 1.0;

  // ===== Paging (manual) =====
  late int index;

  bool get hasImages => widget.imagePaths.isNotEmpty;

  // ===== Per-image data =====
  final Map<int, List<_Stroke>> _strokes = {};
  final Map<int, List<_BBox>> _boxes = {};

  List<_Stroke> get strokes => _strokes.putIfAbsent(index, () => <_Stroke>[]);
  List<_BBox> get boxes => _boxes.putIfAbsent(index, () => <_BBox>[]);

  // ===== Undo/Redo history (per image, combined) =====
  final Map<int, List<_HistoryEntry>> _history = {};
  final Map<int, List<_HistoryEntry>> _redo = {};

  List<_HistoryEntry> get history =>
      _history.putIfAbsent(index, () => <_HistoryEntry>[]);
  List<_HistoryEntry> get redo =>
      _redo.putIfAbsent(index, () => <_HistoryEntry>[]);

  bool get canUndo => history.isNotEmpty;
  bool get canRedo => redo.isNotEmpty;

  // ===== Box selection =====
  int? selectedBoxIndex;

  bool _isNetworkPath(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool _isBackendRelativePath(String path) {
    if (path.isEmpty) return false;
    if (_isNetworkPath(path)) return false;
    if (path.startsWith('/')) return false;
    return path.contains('/') && !path.contains('\\');
  }

  String _resolveImagePath(String path) {
    if (_isBackendRelativePath(path)) {
      return '${ApiConfig.baseUrl}/images/$path';
    }
    return path;
  }

  Widget _missingImagePlaceholder() {
    return Container(
      color: const Color(0xFF1F1F1F),
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white54),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (hasImages) {
      index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    } else {
      index = 0;
    }
  }

  // ===== Navigation =====
  void _next() {
    if (!hasImages) return;
    if (index < widget.imagePaths.length - 1) {
      setState(() {
        index++;
        selectedBoxIndex = null;
      });
    }
  }

  void _prev() {
    if (!hasImages) return;
    if (index > 0) {
      setState(() {
        index--;
        selectedBoxIndex = null;
      });
    }
  }

  // ===== History helpers =====
  void _pushHistory(_HistoryEntry entry) {
    history.add(entry);
    redo.clear();
  }

  void _undo() {
    if (!canUndo) return;
    final last = history.removeLast();
    last.undo(strokes: strokes, boxes: boxes);
    redo.add(last);
    setState(() {});
  }

  void _redoAction() {
    if (!canRedo) return;
    final last = redo.removeLast();
    last.redo(strokes: strokes, boxes: boxes);
    history.add(last);
    setState(() {});
  }

  void _clearAllCurrent() {
    if (!hasImages) return;
    strokes.clear();
    boxes.clear();
    history.clear();
    redo.clear();
    selectedBoxIndex = null;
    setState(() {});
  }

  // ===== Save (example) =====
  void _onSave() {
    if (selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class before saving.')),
      );
      return;
    }

    // (bridge-frontend-backend): Serialize strokes and boxes before returning
    // previously, passed raw _Stroke and _BBox objects which can't be JSON encoded.
    Navigator.pop(context, {
      'caseId': widget.caseId,
      'class': selectedClass,
      'imageIndex': index,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'boxes': boxes.map((b) => b.toJson()).toList(),
      'zoom': zoom,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262626),
        elevation: 0,
        title: const Text(
          'Annotate',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _onSave,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== Image area =====
              if (hasImages) _imageCard() else _emptyState(),
              const SizedBox(height: 14),

              // ===== Toolbar =====
              _toolbar(),
              const SizedBox(height: 18),

              // ===== Brush controls =====
              _panel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Brush size'),
                      const SizedBox(height: 8),
                      _whiteSlider(
                        value: brushSize,
                        min: 1,
                        max: 60,
                        onChanged: (v) => setState(() => brushSize = v),
                      ),
                      const SizedBox(height: 14),
                      const _SectionTitle('Brush opacity'),
                      const SizedBox(height: 8),
                      _whiteSlider(
                        value: brushOpacity,
                        min: 0.05,
                        max: 1.0,
                        onChanged: (v) => setState(() => brushOpacity = v),
                      ),
                      const SizedBox(height: 14),
                      const _SectionTitle('Color'),
                      const SizedBox(height: 12),
                      _FigmaPaletteFromPdf(
                        selected: selectedColor,
                        onPick: (c) => setState(() => selectedColor = c),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ===== Classes =====
              _panel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Classes'),
                      const SizedBox(height: 14),
                      _ClassDropdown(
                        value: selectedClass,
                        items: classes,
                        onChanged: (v) => setState(() => selectedClass = v),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tip: choose class before saving.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI =================

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          'No image to annotate',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _imageCard() {
    final overlayColor = selectedColor.withValues(alpha: brushOpacity);
    final resolvedPath = _resolveImagePath(widget.imagePaths[index]);
    final isNetworkImage = _isNetworkPath(resolvedPath);
    final baseImage = resolvedPath.isEmpty
        ? _missingImagePlaceholder()
        : isNetworkImage
            ? Image.network(
                resolvedPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _missingImagePlaceholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
              )
            : Image.file(
                File(resolvedPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _missingImagePlaceholder(),
              );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 15,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Scale image + overlays together
                  Transform.scale(
                    scale: zoom,
                    alignment: Alignment.center,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        baseImage,

                        // Brush layer (pen/eraser)
                        if (mode == _ToolMode.pen || mode == _ToolMode.eraser)
                          _DrawLayer(
                            strokes: strokes,
                            color: overlayColor,
                            size: brushSize,
                            isEraser: mode == _ToolMode.eraser,
                            onCommitStroke: (s) {
                              _pushHistory(_HistoryEntry.stroke(s));
                              setState(() {});
                            },
                          ),

                        // Box layer
                        _BBoxLayer(
                          enabled: mode == _ToolMode.box,
                          boxes: boxes,
                          selectedIndex: selectedBoxIndex,
                          onSelect: (i) => setState(() => selectedBoxIndex = i),
                          onCommitBox: (b) {
                            _pushHistory(_HistoryEntry.box(b));
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  // Page indicator
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _pill('${index + 1}/${widget.imagePaths.length}'),
                  ),

                  // Prev button (inside image)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navBtn(
                        Icons.chevron_left,
                        enabled: index > 0,
                        onTap: _prev,
                      ),
                    ),
                  ),

                  // Next button (inside image)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navBtn(
                        Icons.chevron_right,
                        enabled: index < widget.imagePaths.length - 1,
                        onTap: _next,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              const SizedBox(width: 8),

              _toolIcon(Icons.undo, _undo, enabled: canUndo),
              const SizedBox(width: 6),
              _toolIcon(Icons.redo, _redoAction, enabled: canRedo),
              const SizedBox(width: 6),
              _toolIcon(Icons.delete_outline, _clearAllCurrent),
              const SizedBox(width: 10),
              _pill('img ${index + 1}/${widget.imagePaths.length}'),
              const SizedBox(width: 10),

              _toolIcon(Icons.edit, () => setState(() => mode = _ToolMode.pen),
                  active: mode == _ToolMode.pen),
              const SizedBox(width: 6),
              _toolIcon(Icons.auto_fix_high, () => setState(() => mode = _ToolMode.eraser),
                  active: mode == _ToolMode.eraser),
              const SizedBox(width: 6),
              _toolIcon(Icons.crop_square_rounded, () => setState(() => mode = _ToolMode.box),
                  active: mode == _ToolMode.box),
              const SizedBox(width: 10),

              _toolIcon(Icons.remove, () {
                setState(() => zoom = (zoom - 0.1).clamp(0.5, 3.0));
              }),
              const SizedBox(width: 6),
              _pill('${(zoom * 100).round()}%'),
              const SizedBox(width: 6),
              _toolIcon(Icons.add, () {
                setState(() => zoom = (zoom + 0.1).clamp(0.5, 3.0));
              }),

              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolIcon(
    IconData icon,
    VoidCallback onTap, {
    bool active = false,
    bool enabled = true,
  }) {
    final opacity = enabled ? 1.0 : 0.35;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 44,
          height: 34,
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0.18 : 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.80),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _pill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        t,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _navBtn(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// ====================== Models ======================

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double size;
  final bool isEraser;

  _Stroke({
    required this.points,
    required this.color,
    required this.size,
    required this.isEraser,
  });

  // (bridge-frontend-backend): Add JSON serialization for backend storage
  // Convert this stroke data to JSON format that can be sent to the backend.
  // Points: List<Offset> -> List<List<double>> as [[dx1, dy1], [dx2, dy2], ...]
  // Color: Color -> int using color.value
  // Size and isEraser are already primitive types
  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => [p.dx, p.dy]).toList(),
      'color': color.value,
      'size': size,
      'isEraser': isEraser,
    };
  }
}

class _BBox {
  Rect rect;
  _BBox(this.rect);

  // (bridge-frontend-backend): Add JSON serialization for backend storage
  // Convert bounding box rectangle to JSON format.
  // Rect -> {left, top, width, height} or {x, y, w, h}
    Map<String, dynamic> toJson() {
      return {
        'left': rect.left,
        'top': rect.top,
        'width': rect.width,
        'height': rect.height,
      };
    }
}

class _HistoryEntry {
  final _Stroke? stroke;
  final _BBox? box;

  _HistoryEntry._({this.stroke, this.box});

  factory _HistoryEntry.stroke(_Stroke s) => _HistoryEntry._(stroke: s);
  factory _HistoryEntry.box(_BBox b) => _HistoryEntry._(box: b);

  void undo({required List<_Stroke> strokes, required List<_BBox> boxes}) {
    if (stroke != null) {
      strokes.remove(stroke);
    } else if (box != null) {
      boxes.remove(box);
    }
  }

  void redo({required List<_Stroke> strokes, required List<_BBox> boxes}) {
    if (stroke != null) {
      strokes.add(stroke!);
    } else if (box != null) {
      boxes.add(box!);
    }
  }
}

/// ====================== Brush Layer ======================

class _DrawLayer extends StatefulWidget {
  final List<_Stroke> strokes;
  final Color color;
  final double size;
  final bool isEraser;
  final ValueChanged<_Stroke> onCommitStroke;

  const _DrawLayer({
    required this.strokes,
    required this.color,
    required this.size,
    required this.isEraser,
    required this.onCommitStroke,
  });

  @override
  State<_DrawLayer> createState() => _DrawLayerState();
}

class _DrawLayerState extends State<_DrawLayer> {
  _Stroke? _current;

  void _start(Offset p) {
    final s = _Stroke(
      points: [p],
      color: widget.color,
      size: widget.size,
      isEraser: widget.isEraser,
    );
    _current = s;
    widget.strokes.add(s);
    setState(() {});
  }

  void _update(Offset p) {
    if (_current == null) return;
    _current!.points.add(p);
    setState(() {});
  }

  void _end() {
    final s = _current;
    _current = null;
    if (s != null) widget.onCommitStroke(s);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _start(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _end(),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StrokePainter(widget.strokes),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<_Stroke> strokes;
  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    // Needed for BlendMode.clear to work
    canvas.saveLayer(Offset.zero & size, Paint());

    for (final s in strokes) {
      if (s.points.length < 2) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.size
        ..isAntiAlias = true;

      if (s.isEraser) {
        paint.blendMode = BlendMode.clear;
        paint.color = const Color(0x00000000);
      } else {
        paint.blendMode = BlendMode.srcOver;
        paint.color = s.color;
      }

      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

/// ====================== Bounding Box Layer ======================

class _BBoxLayer extends StatefulWidget {
  final bool enabled;
  final List<_BBox> boxes;
  final int? selectedIndex;
  final ValueChanged<int?> onSelect;
  final ValueChanged<_BBox> onCommitBox;

  const _BBoxLayer({
    required this.enabled,
    required this.boxes,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCommitBox,
  });

  @override
  State<_BBoxLayer> createState() => _BBoxLayerState();
}

class _BBoxLayerState extends State<_BBoxLayer> {
  Offset? _start;
  Rect? _draft;

  int? _hit(Offset p) {
    for (int i = widget.boxes.length - 1; i >= 0; i--) {
      if (widget.boxes[i].rect.contains(p)) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      // still paint boxes even if not enabled (so you can see them)
      return IgnorePointer(
        ignoring: true,
        child: CustomPaint(
          painter: _BBoxPainter(
            boxes: widget.boxes,
            selected: widget.selectedIndex,
            draft: null,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (d) {
        final hit = _hit(d.localPosition);
        widget.onSelect(hit);
        setState(() {});
      },
      onPanStart: (d) {
        final hit = _hit(d.localPosition);
        widget.onSelect(hit);
        if (hit == null) {
          _start = d.localPosition;
          _draft = Rect.fromPoints(_start!, _start!);
        }
        setState(() {});
      },
      onPanUpdate: (d) {
        if (_start != null) {
          _draft = Rect.fromPoints(_start!, d.localPosition);
          setState(() {});
        }
      },
      onPanEnd: (_) {
        if (_draft != null && _draft!.width.abs() > 10 && _draft!.height.abs() > 10) {
          final b = _BBox(_draft!);
          widget.boxes.add(b);
          widget.onCommitBox(b);
        }
        _start = null;
        _draft = null;
        setState(() {});
      },
      child: CustomPaint(
        painter: _BBoxPainter(
          boxes: widget.boxes,
          selected: widget.selectedIndex,
          draft: _draft,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BBoxPainter extends CustomPainter {
  final List<_BBox> boxes;
  final int? selected;
  final Rect? draft;

  _BBoxPainter({
    required this.boxes,
    required this.selected,
    required this.draft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.greenAccent;

    for (int i = 0; i < boxes.length; i++) {
      final isSel = selected == i;
      paint.color = isSel ? Colors.yellowAccent : Colors.greenAccent;
      canvas.drawRect(boxes[i].rect, paint);
    }

    if (draft != null) {
      paint.color = Colors.white;
      canvas.drawRect(draft!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BBoxPainter oldDelegate) => true;
}

/// ====================== Shared widgets ======================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}

Widget _whiteSlider({
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
}) {
  return SliderTheme(
    data: SliderThemeData(
      trackHeight: 6,
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.35),
      thumbColor: Colors.white,
      overlayColor: Colors.white.withValues(alpha: 0.10),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    child: Slider(value: value, min: min, max: max, onChanged: onChanged),
  );
}

/// ---------- Palette from your PDF (FULL) ----------
class _FigmaPaletteFromPdf extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onPick;
  const _FigmaPaletteFromPdf({required this.selected, required this.onPick});

  static const int cols = 20;

  static const List<List<int>> kPaletteHex = [
    // ✅ แต่ละแถว “ต้องมี 20 ตัว” เท่านั้น
    [
      0xFFFACDD4, 0xFFF9BBD2, 0xFFE0BEDB, 0xFFDFBEDB, 0xFFD1C4E0,
      0xFFC5CAE7, 0xFFBEDEF5, 0xFFB4E4FB, 0xFFB4E3F1, 0xFFB6E2ED,
      0xFFB3E0DD, 0xFFC8E5C9, 0xFFDCECC8, 0xFFF1F4C6, 0xFFF3F5C4,
      0xFFFCF9C6, 0xFFFEEEB3, 0xFFFFE0B1, 0xFFFBCBBD, 0xFFD9CCCB,
    ],
    [
      0xFFF09A9B, 0xFFF38FB3, 0xFFC994C4, 0xFFC894C4, 0xFFB39DCC,
      0xFFA1A8D6, 0xFF96C8ED, 0xFF83D3F6, 0xFF87D3E8, 0xFF88D4E2,
      0xFF80CBC4, 0xFFA5D4A6, 0xFFC4E0A6, 0xFFE3EB9D, 0xFFE9EE9E,
      0xFFFCF6A0, 0xFFFDE082, 0xFFFECD81, 0xFFF8AA93, 0xFFBDAAA5,
    ],
    [
      0xFFE77373, 0xFFF16393, 0xFFAD6BAE, 0xFFAD6CAE, 0xFF9275B5,
      0xFF7A86C2, 0xFF70B2E2, 0xFF54C3F0, 0xFF57C6E1, 0xFF58C7DA,
      0xFF48B8AC, 0xFF81C884, 0xFFADD57F, 0xFFE3EB9D, 0xFFEAEC96,
      0xFFFCF477, 0xFFFDD54F, 0xFFFDB64E, 0xFFF58867, 0xFFA2897F,
    ],
    [
      0xFFEE5351, 0xFFEE407B, 0xFF9C51A1, 0xFF9B51A0, 0xFF775DA7,
      0xFF5D6BB2, 0xFF549FD8, 0xFF40B4E7, 0xFF39BDDB, 0xFF35C2D6,
      0xFF29A79B, 0xFF65BC6B, 0xFF9DCD67, 0xFFD2E158, 0xFFDCE358,
      0xFFFAEF57, 0xFFFFC928, 0xFFFAA629, 0xFFF37046, 0xFF8E6F63,
    ],
    [
      0xFFF04438, 0xFFEA1A65, 0xFF923D98, 0xFF913E98, 0xFF66489E,
      0xFF4455A5, 0xFF478ECC, 0xFF34A5DD, 0xFF22B5D7, 0xFF1BBDD4,
      0xFF14988B, 0xFF48B04F, 0xFF8AC44B, 0xFFCFDD38, 0xFFD8E037,
      0xFFF9ED37, 0xFFFEC110, 0xFFF8981D, 0xFFF1582E, 0xFF7B5548,
    ],
    [
      0xFFE73835, 0xFFD91A60, 0xFF883994, 0xFF863A95, 0xFF5E449B,
      0xFF3E4DA0, 0xFF3C83C5, 0xFF2698D4, 0xFF19A6C8, 0xFF14ABC3,
      0xFF108A7D, 0xFF42A147, 0xFF7BB443, 0xFFC0CB31, 0xFFCCCE33,
      0xFFFBD836, 0xFFFCB215, 0xFFF68C1E, 0xFFEF5122, 0xFF6D4D43,
    ],
    [
      0xFFD62D30, 0xFFC31F5C, 0xFF793194, 0xFF783294, 0xFF543D98,
      0xFF31429A, 0xFF2774BA, 0xFF2187C9, 0xFF1C91B2, 0xFF1998A7,
      0xFF0B7A6A, 0xFF329042, 0xFF68A143, 0xFFB0B534, 0xFFC0B833,
      0xFFFCC02A, 0xFFFA9F1B, 0xFFF57C1F, 0xFFE64C26, 0xFF5F4137,
    ],
    [
      0xFFC7292A, 0xFFAE1E59, 0xFF692D92, 0xFF692D91, 0xFF4A3594,
      0xFF283993, 0xFF2866B1, 0xFF0678BE, 0xFF09819F, 0xFF0C8590,
      0xFF0E685C, 0xFF2D7D3E, 0xFF568A3F, 0xFF9E9F37, 0xFFB1A133,
      0xFFFAA821, 0xFFF78F1E, 0xFFEF6D22, 0xFFDA4527, 0xFF50352F,
    ],
    [
      0xFFB72025, 0xFF891951, 0xFF4C2D8A, 0xFF4B2E8A, 0xFF362F8C,
      0xFF2D2F7A, 0xFF16489F, 0xFF08589D, 0xFF0D5E79, 0xFF0E6165,
      0xFF0C4E42, 0xFF1C6031, 0xFF336A33, 0xFF82782F, 0xFF9B7A2D,
      0xFFF58020, 0xFFF37022, 0xFFE65126, 0xFFBE3926, 0xFF3E2622,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final rows = kPaletteHex.length;

    assert(
      kPaletteHex.every((r) => r.length == cols),
      'Each palette row must have exactly 20 colors.',
    );

    return LayoutBuilder(
      builder: (context, c) {
        // ขนาดช่อง (กว้าง/20) -> ทำให้เป็น “สี่เหลี่ยม”
        final cell = (c.maxWidth / cols).floorToDouble();

        // ✅ ปรับตรงนี้เพื่อ “ทำให้ใหญ่ขึ้น” เหมือน Figma
        // 1.0 = เต็มเซลล์, 1.15 = สูงขึ้นอีกนิด
        const cellScaleY = 1.15;

        return SizedBox(
          height: (cell * rows) * cellScaleY,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              mainAxisExtent: cell * cellScaleY, // ✅ ทำให้ช่องสูง/ใหญ่ขึ้น
            ),
            itemCount: rows * cols,
            itemBuilder: (context, i) {
              final r = i ~/ cols;
              final col = i % cols;
              final color = Color(kPaletteHex[r][col]);
              final isSel = color.value == selected.value;

              return GestureDetector(
                onTap: () => onPick(color),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.10),
                      width: 0.6,
                    ),
                  ),
                  child: isSel
                      ? Container(
                          margin: const EdgeInsets.all(1.2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
/// ---------- Dropdown ----------
class _ClassDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _ClassDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF2B2B2B),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      hint: const Text(
        'Select class',
        style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
      ),
      items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: onChanged,
    );
  }
}
