import 'package:flutter/material.dart';
import '../models/stitch.dart';

class StitchPad extends StatelessWidget {
  final Function(StitchType) onStitchTap;
  final VoidCallback onAddRow;

  const StitchPad({
    super.key,
    required this.onStitchTap,
    required this.onAddRow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStitchButton(StitchType.knit),
              const SizedBox(width: 12),
              _buildStitchButton(StitchType.purl),
            ],
          ),
          const SizedBox(height: 12),
          _buildAddRowButton(),
        ],
      ),
    );
  }

  Widget _buildStitchButton(StitchType type) {
    final stitch = Stitch(type);
    return GestureDetector(
      onTap: () => onStitchTap(type),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD1DC),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              stitch.abbreviation,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stitch.koreanName,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRowButton() {
    return GestureDetector(
      onTap: onAddRow,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD1DC),
            width: 1,
          ),
        ),
        child: const Column(
          children: [
            Text(
              'Add Row',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '단 추가',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
