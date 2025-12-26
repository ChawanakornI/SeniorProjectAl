import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget customCheckboxRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
  required bool isDark,
}) {
  final textColor = isDark ? Colors.white : Colors.black87;
  final borderColor = isDark ? Colors.white70 : Colors.black12;

  return InkWell(
    onTap: () => onChanged(!value),
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.1,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: BorderSide(
                color: borderColor,
                width: 1.2,
              ),
              activeColor: Colors.white,
              checkColor: Colors.black,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: -4,
                vertical: -4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
