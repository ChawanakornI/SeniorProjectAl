import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass.dart';

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

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Transparent tap-to-close layer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Positioned dropdown using follower
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height - 1),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: size.width, 
                      constraints: const BoxConstraints(maxHeight: 360),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        border: Border.all(
                          color: widget.isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.shade300,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.items.map((item) {
                            final isSelected = item == widget.value;
                            final textColor = widget.isDark ? Colors.white : const Color(0xFF282828);

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onChanged(item);
                                _removeOverlay();
                              },
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (widget.isDark 
                                          ? Colors.white.withOpacity(0.15)
                                          : Colors.grey.shade200)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: widget.isDark 
                                            ? Colors.white70 
                                            : Colors.grey.shade700,
                                      ),
                                    if (isSelected) const SizedBox(width: 10),
                                    Text(
                                      item,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: textColor,
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
          ],
        );
      },
    );
  }

}



  

