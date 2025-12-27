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
    required this.onEmptySlotTap,
    required this.onButtonsReordered,
    required this.onButtonDeleted,
  });

  @override
  State<StitchPad> createState() => _StitchPadState();
}

class _StitchPadState extends State<StitchPad> {
  bool _isEditMode = false;
  int? _draggingIndex;
  int? _targetIndex;
  List<CustomButton>? _previewButtons;

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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEditButton(),
          const SizedBox(height: 8),
          _buildMainSection(),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: _toggleEditMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isEditMode ? const Color(0xFFFFB6C1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD1DC),
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
      ],
    );
  }

  Widget _buildMainSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final rightSectionWidth = 40.0;
        final leftSectionWidth = availableWidth - rightSectionWidth - StitchPad.buttonSpacing;

        final buttonSize = ((leftSectionWidth - (StitchPad.buttonSpacing * (StitchPad.gridColumns - 1))) / StitchPad.gridColumns)
            .clamp(StitchPad.minButtonSize, StitchPad.maxButtonSize);

        final actualLeftWidth = (buttonSize * StitchPad.gridColumns) + (StitchPad.buttonSpacing * (StitchPad.gridColumns - 1));

        final totalHeight = (buttonSize * StitchPad.gridRows) + (StitchPad.buttonSpacing * (StitchPad.gridRows - 1));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: actualLeftWidth,
              height: totalHeight,
              child: _buildButtonGrid(buttonSize),
            ),
            const SizedBox(width: StitchPad.buttonSpacing),
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
    final displayButtons = _previewButtons ?? widget.buttons;

    return Column(
      children: List.generate(StitchPad.gridRows, (rowIndex) {
        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < StitchPad.gridRows - 1 ? StitchPad.buttonSpacing : 0),
          child: Row(
            children: List.generate(StitchPad.gridColumns, (colIndex) {
              final buttonIndex = rowIndex * StitchPad.gridColumns + colIndex;
              final isLast = colIndex == StitchPad.gridColumns - 1;

              return Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : StitchPad.buttonSpacing),
                child: buttonIndex < displayButtons.length
                    ? _isEditMode
                        ? _buildEditableButton(displayButtons[buttonIndex], buttonIndex, buttonSize)
                        : _buildStitchButton(displayButtons[buttonIndex], buttonSize)
                    : _buildEmptySlot(buttonSize),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildEditableButton(CustomButton button, int index, double size) {
    final originalIndex = widget.buttons.indexOf(button);
    final isDragging = _draggingIndex != null && originalIndex == _draggingIndex;

    return LongPressDraggable<int>(
      data: originalIndex,
      delay: const Duration(milliseconds: 100),
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size * 1.1,
          height: size * 1.1,
          decoration: BoxDecoration(
            color: button.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB6C1), width: 2),
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
      childWhenDragging: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFB6C1).withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFB6C1),
            width: 2,
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
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: button.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
                  ),
                  child: _buildButtonContent(button, size),
                ),
              ),
              if (!isDragging)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => widget.onButtonDeleted(originalIndex),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
                color: _getContrastColor(button.color).withOpacity(0.7),
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStitchButton(CustomButton button, double size) {
    return GestureDetector(
      onTap: () => widget.onButtonTap(button),
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
        child: _buildButtonContent(button, size),
      ),
    );
  }

  Widget _buildEmptySlot(double size) {
    return GestureDetector(
      onTap: widget.onEmptySlotTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD1DC).withOpacity(0.5),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: size * 0.4,
            color: const Color(0xFFFFB6C1).withOpacity(0.6),
          ),
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
        const SizedBox(height: StitchPad.buttonSpacing),
        Expanded(
          child: _buildAddRowButton(),
        ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: widget.onDelete,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
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
              size: 18,
              color: Color(0xFFFF6B6B),
            ),
            Text(
              '삭제',
              style: TextStyle(
                fontSize: 9,
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
      onTap: widget.onAddRow,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFFFD1DC),
            width: 1,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: Color(0xFFFFB6C1),
            ),
            Text(
              '단추가',
              style: TextStyle(
                fontSize: 9,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
