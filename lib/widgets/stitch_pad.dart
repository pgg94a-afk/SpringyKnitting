import 'package:flutter/material.dart';
import '../models/custom_button.dart';

class StitchPad extends StatelessWidget {
  final List<CustomButton> buttons;
  final Function(CustomButton) onButtonTap;
  final VoidCallback onAddRow;
  final VoidCallback onDelete;
  final VoidCallback onSettingsTap;

  static const int gridColumns = 3;
  static const int gridRows = 3;
  static const double buttonSpacing = 8.0;
  static const double minButtonSize = 50.0;
  static const double maxButtonSize = 70.0;

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
          _buildMainSection(),
          const SizedBox(height: 12),
          _buildAddRowButton(),
        ],
      ),
    );
  }

  Widget _buildMainSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // 8:2 비율 계산 (오른쪽에 여백 포함)
        final rightSectionWidth = 70.0; // 삭제/세팅 버튼 너비
        final leftSectionWidth = availableWidth - rightSectionWidth - buttonSpacing;

        // 3x3 그리드에 맞는 버튼 크기 계산
        final buttonSize = ((leftSectionWidth - (buttonSpacing * (gridColumns - 1))) / gridColumns)
            .clamp(minButtonSize, maxButtonSize);

        // 실제 왼쪽 섹션 너비 (버튼 크기 기반)
        final actualLeftWidth = (buttonSize * gridColumns) + (buttonSpacing * (gridColumns - 1));

        // 버튼 높이 (3행 기준)
        final totalHeight = (buttonSize * gridRows) + (buttonSpacing * (gridRows - 1));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 버튼 패드 (3x3)
            SizedBox(
              width: actualLeftWidth,
              height: totalHeight,
              child: _buildButtonGrid(buttonSize),
            ),
            const SizedBox(width: buttonSpacing),
            // 오른쪽: 삭제/세팅 버튼
            Expanded(
              child: SizedBox(
                height: totalHeight,
                child: _buildSideButtons(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButtonGrid(double buttonSize) {
    return Column(
      children: List.generate(gridRows, (rowIndex) {
        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < gridRows - 1 ? buttonSpacing : 0),
          child: Row(
            children: List.generate(gridColumns, (colIndex) {
              final buttonIndex = rowIndex * gridColumns + colIndex;
              final isLast = colIndex == gridColumns - 1;

              return Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : buttonSpacing),
                child: buttonIndex < buttons.length
                    ? _buildStitchButton(buttons[buttonIndex], buttonSize)
                    : _buildEmptySlot(buttonSize),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildStitchButton(CustomButton button, double size) {
    return GestureDetector(
      onTap: () => onButtonTap(button),
      child: Container(
        width: size,
        height: size,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  button.abbreviation,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _getContrastColor(button.color),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  button.koreanName,
                  style: TextStyle(
                    fontSize: 10,
                    color: _getContrastColor(button.color).withOpacity(0.7),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD1DC).withOpacity(0.5),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildSideButtons() {
    return Column(
      children: [
        Expanded(
          child: _buildDeleteButton(),
        ),
        const SizedBox(height: buttonSpacing),
        Expanded(
          child: _buildSettingsButton(),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: onDelete,
      child: Container(
        width: double.infinity,
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
              size: 28,
              color: Color(0xFFFF6B6B),
            ),
            SizedBox(height: 4),
            Text(
              '삭제',
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

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: onSettingsTap,
      child: Container(
        width: double.infinity,
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
              SizedBox(height: 4),
              Text(
                '설정',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
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
