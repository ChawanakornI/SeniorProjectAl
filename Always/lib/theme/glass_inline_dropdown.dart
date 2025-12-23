import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassInlineDropdown extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String hint;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const GlassInlineDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    required this.isDark,
    this.value,
    this.hint = 'Select',
  });

  @override
  State<GlassInlineDropdown> createState() => _GlassInlineDropdownState();
}

class _GlassInlineDropdownState extends State<GlassInlineDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  late final AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0,
      upperBound: 0.5, // 180°
    );
  }

  void _toggleDropdown() {
    HapticFeedback.selectionClick();

    if (_overlay != null) {
      _removeOverlay();
    } else {
      _overlay = _createOverlay();
      Overlay.of(context).insert(_overlay!);
      _arrowController.forward();
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    _arrowController.reverse();
  }

  @override
  void dispose() {
    _removeOverlay();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.6);

    final borderColor = widget.isDark
        ? Colors.white.withOpacity(0.2)
        : Colors.grey.shade300;

    final textColor =
        widget.isDark ? Colors.white : const Color(0xFF282828);

    final hintColor =
        widget.isDark ? Colors.white38 : const Color(0xFF9E9E9E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            onTap: _toggleDropdown,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.value ?? widget.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                widget.value == null ? hintColor : textColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      RotationTransition(
                        turns: _arrowController,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color:
                              widget.isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  OverlayEntry _createOverlay() {
  final renderBox = context.findRenderObject() as RenderBox;
  final size = renderBox.size;
  final offset = renderBox.localToGlobal(Offset.zero);

  final dropdownTop = offset.dy + size.height + 8;

  return OverlayEntry(
    builder: (context) {
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _removeOverlay, // tap outside = close
          child: Stack(
            children: [
              // 🔹 Dropdown only (no background, no dim)
              Positioned(
                top: dropdownTop,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width:
                              MediaQuery.of(context).size.width * 0.85,
                          constraints:
                              const BoxConstraints(maxHeight: 360),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.7),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withOpacity(0.18),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: widget.items.map((item) {
                                final isSelected =
                                    item == widget.value;

                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onChanged(item);
                                    _removeOverlay();
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    margin:
                                        const EdgeInsets.symmetric(
                                            vertical: 4),
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue
                                              .withOpacity(0.25)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.blue
                                                  .withOpacity(0.5),
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                        if (isSelected)
                                          const SizedBox(width: 12),
                                        Text(
                                          item,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

}



  

