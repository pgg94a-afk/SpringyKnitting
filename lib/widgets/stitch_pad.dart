import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_button.dart';

class StitchPad extends StatefulWidget {
  final List<CustomButton> buttons;
  final Function(CustomButton) onButtonTap;
  final VoidCallback onAddRow;
  final VoidCallback onDelete;
  final VoidCallback onEmptySlotTap;
  final Function(List<CustomButton>) onButtonsReordered;
  final Function(int) onButtonDeleted;
  final VoidCallback? onCollapse;

  static const int gridRows = 2;
  static const int gridColumns = 3;
  static const double buttonSpacing = 8.0;
  static const double minButtonSize = 55.0;
  static const double maxButtonSize = 80.0;
  static const double rightSectionWidth = 70.0;

  const StitchPad({
    super.key,
    required this.buttons,
    required this.onButtonTap,
    required this.onAddRow,
    required this.onDelete,
    required this.onEmptySlotTap,
    required this.onButtonsReordered,
    required this.onButtonDeleted,
    this.onCollapse,
  });

  @override
  State<StitchPad> createState() => _StitchPadState();
}

class _StitchPadState extends State<StitchPad> {
  bool _isEditMode = false;
  bool _isCollapsed = false;
  int? _draggingIndex;
  int? _targetIndex;
  List<CustomButton>? _previewButtons;

  // Liquid Glass 색상 정의
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _glassBorder = Color(0xFFE5E4E3);
  static const Color _accentColor = Color(0xFF6B7280);
  static const Color _deleteColor = Color(0xFFEF4444);

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _draggingIndex = null;
        _targetIndex = null;
        _previewButtons = null;
      }
    });
  }

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _isEditMode = false;
      }
    });
    widget.onCollapse?.call();
  }

  void _onDragStart(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingIndex = index;
      _targetIndex = index;
      _previewButtons = List.from(widget.buttons);
    });
  }

  void _onDragUpdate(int newTargetIndex) {
    if (_draggingIndex == null || newTargetIndex == _targetIndex) return;
    if (newTargetIndex < 0 || newTargetIndex >= widget.buttons.length) return;

    setState(() {
      _targetIndex = newTargetIndex;
      _previewButtons = List.from(widget.buttons);
      final item = _previewButtons!.removeAt(_draggingIndex!);
      _previewButtons!.insert(newTargetIndex, item);
    });
  }

  void _onDragEnd(bool accepted) {
    if (_draggingIndex != null && _targetIndex != null && _targetIndex != _draggingIndex) {
      final newList = List<CustomButton>.from(widget.buttons);
      final item = newList.removeAt(_draggingIndex!);
      newList.insert(_targetIndex!, item);
      widget.onButtonsReordered(newList);
    }
    setState(() {
      _draggingIndex = null;
      _targetIndex = null;
      _previewButtons = null;
    });
  }

  void _onDragCancel() {
    setState(() {
      _draggingIndex = null;
      _targetIndex = null;
      _previewButtons = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < -5) {
          // 위로 스와이프 - 펼치기
          if (_isCollapsed) {
            setState(() {
              _isCollapsed = false;
            });
          }
        } else if (details.delta.dy > 5) {
          // 아래로 스와이프 - 접기
          if (!_isCollapsed) {
            setState(() {
              _isCollapsed = true;
              _isEditMode = false;
            });
          }
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, _isCollapsed ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.9),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 핸들러 바
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildHeaderButtons(),
                if (!_isCollapsed) ...[
                  const SizedBox(height: 8),
                  _buildKeypadSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 편집 버튼 (접혀있을 때는 숨김)
        if (!_isCollapsed)
          GestureDetector(
            onTap: _toggleEditMode,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isEditMode
                        ? _accentColor.withOpacity(0.9)
                        : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isEditMode ? Icons.check : Icons.edit,
                        size: 14,
                        color: _isEditMode ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEditMode ? '완료' : '편집',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isEditMode ? Colors.white : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeypadSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final leftSectionWidth = availableWidth - StitchPad.rightSectionWidth - StitchPad.buttonSpacing;

        // 3x3 고정 레이아웃
        double buttonSize = ((leftSectionWidth - (StitchPad.buttonSpacing * (StitchPad.gridColumns - 1))) / StitchPad.gridColumns);
        buttonSize = buttonSize.clamp(StitchPad.minButtonSize, StitchPad.maxButtonSize);

        // 실제 키패드 그리드 너비 계산 (버튼이 clamp되면 실제 너비가 달라짐)
        final actualGridWidth = (buttonSize * StitchPad.gridColumns) + (StitchPad.buttonSpacing * (StitchPad.gridColumns - 1));
        final totalHeight = (buttonSize * StitchPad.gridRows) + (StitchPad.buttonSpacing * (StitchPad.gridRows - 1));

        // 키패드와 사이드 버튼
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: actualGridWidth,
              height: totalHeight,
              child: _buildButtonGrid(buttonSize, StitchPad.gridColumns),
            ),
            const SizedBox(width: StitchPad.buttonSpacing),
            // 사이드 버튼을 남은 공간에 채움
            Expanded(
              child: SizedBox(
                height: totalHeight,
                child: _buildSideButtons(buttonSize),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButtonGrid(double buttonSize, int gridColumns) {
    final displayButtons = _previewButtons ?? widget.buttons;
    final totalSlots = gridColumns * StitchPad.gridRows;

    return Column(
      children: List.generate(StitchPad.gridRows, (rowIndex) {
        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < StitchPad.gridRows - 1 ? StitchPad.buttonSpacing : 0),
          child: Row(
            children: List.generate(gridColumns, (colIndex) {
              final buttonIndex = rowIndex * gridColumns + colIndex;
              final isLast = colIndex == gridColumns - 1;

              return Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : StitchPad.buttonSpacing),
                child: buttonIndex < displayButtons.length
                    ? _buildEditableButton(displayButtons[buttonIndex], buttonIndex, buttonSize, gridColumns)
                    : _buildEmptySlot(buttonSize),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildEditableButton(CustomButton button, int index, double size, int gridColumns) {
    final originalIndex = widget.buttons.indexOf(button);
    final isDragging = _draggingIndex != null && originalIndex == _draggingIndex;

    return LongPressDraggable<int>(
      data: originalIndex,
      delay: const Duration(milliseconds: 100),
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: size * 1.1,
          height: size * 1.1,
          decoration: BoxDecoration(
            color: button.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accentColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _buildButtonContent(button, size),
        ),
      ),
      childWhenDragging: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accentColor.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        ),
      ),
      onDragStarted: () => _onDragStart(originalIndex),
      onDragEnd: (details) => _onDragEnd(details.wasAccepted),
      onDraggableCanceled: (_, __) => _onDragCancel(),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          if (details.data != originalIndex) {
            _onDragUpdate(index);
          }
          return details.data != originalIndex;
        },
        onAcceptWithDetails: (details) {},
        builder: (context, candidateData, rejectedData) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isDragging ? 0.0 : 1.0,
                child: GestureDetector(
                  onTap: !_isEditMode ? () => widget.onButtonTap(button) : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: button.color.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: _buildButtonContent(button, size),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isEditMode && !isDragging)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => widget.onButtonDeleted(originalIndex),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildButtonContent(CustomButton button, double size) {
    return Column(
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
                color: _getContrastColor(button.color).withOpacity(0.85),
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildEmptySlot(double size) {
    return GestureDetector(
      onTap: widget.onEmptySlotTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                size: size * 0.4,
                color: _accentColor.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildSideButtons(double buttonSize) {
    return Column(
      children: [
        SizedBox(
          height: buttonSize,
          child: _buildDeleteButton(),
        ),
        const SizedBox(height: StitchPad.buttonSpacing),
        SizedBox(
          height: buttonSize,
          child: _buildAddRowButton(),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: widget.onDelete,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: _deleteColor,
                ),
                const SizedBox(height: 2),
                const Text(
                  '삭제',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddRowButton() {
    return GestureDetector(
      onTap: widget.onAddRow,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 22,
                  color: _accentColor,
                ),
                const SizedBox(height: 2),
                const Text(
                  '단추가',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
