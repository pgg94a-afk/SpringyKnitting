import 'package:flutter/material.dart';
import '../models/custom_button.dart';

class StitchPad extends StatelessWidget {
  final List<CustomButton> buttons;
  final Function(CustomButton) onButtonTap;
  final VoidCallback onAddRow;
  final VoidCallback onDelete;
  final VoidCallback onSettingsTap;

  const StitchPad({
    super.key,
    required this.buttons,
    required this.onButtonTap,
    required this.onAddRow,
    required this.onDelete,
    required this.onSettingsTap,
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
          _buildButtonsRow(),
          const SizedBox(height: 12),
          _buildAddRowButton(),
        ],
      ),
    );
  }

  Widget _buildButtonsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...buttons.map((button) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildStitchButton(button),
          )),
          _buildDeleteButton(),
          const SizedBox(width: 12),
          _buildSettingsButton(),
        ],
      ),
    );
  }

  Widget _buildStitchButton(CustomButton button) {
    return GestureDetector(
      onTap: () => onButtonTap(button),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: button.color,
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
              button.abbreviation,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getContrastColor(button.color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              button.koreanName,
              style: TextStyle(
                fontSize: 11,
                color: _getContrastColor(button.color).withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: onDelete,
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
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.backspace_outlined,
              size: 24,
              color: Color(0xFFFF6B6B),
            ),
            SizedBox(height: 2),
            Text(
              '삭제',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: onSettingsTap,
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
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFF6B6B),
              Color(0xFFFFE66D),
              Color(0xFF4ECDC4),
              Color(0xFF95E1D3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.palette,
                size: 28,
                color: Colors.white,
              ),
            ],
          ),
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
