import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_button.dart';

class ButtonSettingsDialog extends StatefulWidget {
  final List<CustomButton> currentButtons;
  final Function(List<CustomButton>) onButtonsChanged;

  const ButtonSettingsDialog({
    super.key,
    required this.currentButtons,
    required this.onButtonsChanged,
  });

  @override
  State<ButtonSettingsDialog> createState() => _ButtonSettingsDialogState();
}

class _ButtonSettingsDialogState extends State<ButtonSettingsDialog> {
  late List<CustomButton> _padButtons;
  List<CustomButton>? _previewButtons;
  int? _draggingIndex;
  int? _targetIndex;

  CustomButton? _selectedPreset;
  Color _selectedColor = const Color(0xFFE5E4E3);
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _abbreviationController = TextEditingController();
  final TextEditingController _koreanNameController = TextEditingController();

  // Liquid Glass 색상 정의
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _accentColor = Color(0xFF6B7280);
  static const Color _selectedAccent = Color(0xFF6B7280);
  static const Color _deleteColor = Color(0xFFEF4444);

  static const double buttonSize = 55.0;
  static const double buttonSpacing = 8.0;
  static const int gridColumns = 3;
  static const double sideButtonWidth = 55.0;

  @override
  void initState() {
    super.initState();
    _padButtons = List.from(widget.currentButtons);
    _hexController.text = 'E5E4E3';
  }

  @override
  void dispose() {
    _hexController.dispose();
    _abbreviationController.dispose();
    _koreanNameController.dispose();
    super.dispose();
  }

  void _selectPreset(CustomButton preset) {
    setState(() {
      _selectedPreset = preset;
      _abbreviationController.text = preset.abbreviation;
      _koreanNameController.text = preset.koreanName;
    });
  }

  void _updateColorFromHex(String hex) {
    hex = hex.replaceAll('#', '').toUpperCase();
    if (hex.length == 6) {
      try {
        final color = Color(int.parse('FF$hex', radix: 16));
        setState(() {
          _selectedColor = color;
        });
      } catch (_) {}
    }
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).substring(2).toUpperCase();
  }

  void _addButtonToPad() {
    if (_abbreviationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('버튼 약자를 입력해주세요'),
          backgroundColor: _accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final newButton = CustomButton(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      abbreviation: _abbreviationController.text,
      koreanName: _koreanNameController.text.isEmpty
          ? _abbreviationController.text
          : _koreanNameController.text,
      color: _selectedColor,
    );

    setState(() {
      _padButtons.add(newButton);
      _abbreviationController.clear();
      _koreanNameController.clear();
      _selectedPreset = null;
      _selectedColor = const Color(0xFFE5E4E3);
      _hexController.text = 'E5E4E3';
    });
  }

  void _removeButtonFromPad(int index) {
    setState(() {
      _padButtons.removeAt(index);
    });
  }

  void _onDragStart(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingIndex = index;
      _targetIndex = index;
      _previewButtons = List.from(_padButtons);
    });
  }

  void _onDragUpdate(int newTargetIndex) {
    if (_draggingIndex == null || newTargetIndex == _targetIndex) return;
    if (newTargetIndex < 0 || newTargetIndex >= _padButtons.length) return;

    setState(() {
      _targetIndex = newTargetIndex;
      _previewButtons = List.from(_padButtons);
      final item = _previewButtons!.removeAt(_draggingIndex!);
      _previewButtons!.insert(newTargetIndex, item);
    });
  }

  void _onDragEnd(bool accepted) {
    if (_draggingIndex != null && _targetIndex != null && _targetIndex != _draggingIndex) {
      setState(() {
        final item = _padButtons.removeAt(_draggingIndex!);
        _padButtons.insert(_targetIndex!, item);
      });
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCurrentPadSection(),
                        const SizedBox(height: 20),
                        _buildButtonPreview(),
                        const SizedBox(height: 16),
                        _buildAddButton(),
                        const SizedBox(height: 20),
                        _buildPresetSelector(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '버튼 설정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black54, size: 20),
        ),
      ],
    );
  }

  Widget _buildCurrentPadSection() {
    final displayButtons = _previewButtons ?? _padButtons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '현재 패드',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '길게 눌러서 위치 변경 | X 버튼으로 삭제',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              child: _buildPadGrid(displayButtons),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPadGrid(List<CustomButton> displayButtons) {
    if (displayButtons.isEmpty) {
      return Row(
        children: [
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '버튼을 추가해주세요',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ),
          const SizedBox(width: buttonSpacing),
          SizedBox(
            width: sideButtonWidth,
            child: _buildSideButtons(),
          ),
        ],
      );
    }

    final rowCount = (displayButtons.length / gridColumns).ceil();
    final totalHeight = (buttonSize * rowCount) + (buttonSpacing * (rowCount - 1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(rowCount, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex < rowCount - 1 ? buttonSpacing : 0),
                child: Row(
                  children: List.generate(gridColumns, (colIndex) {
                    final buttonIndex = rowIndex * gridColumns + colIndex;

                    if (buttonIndex >= displayButtons.length) {
                      return Expanded(child: Container());
                    }

                    final button = displayButtons[buttonIndex];
                    final originalIndex = _padButtons.indexOf(button);
                    final isDragging = _draggingIndex != null && originalIndex == _draggingIndex;
                    final isTargetPosition = _previewButtons != null && buttonIndex == _targetIndex;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: colIndex < gridColumns - 1 ? buttonSpacing : 0),
                        child: _buildDraggableButton(
                          button,
                          originalIndex,
                          buttonIndex,
                          isDragging,
                          isTargetPosition,
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: buttonSpacing),
        SizedBox(
          width: sideButtonWidth,
          height: totalHeight,
          child: _buildSideButtons(),
        ),
      ],
    );
  }

  Widget _buildDraggableButton(
    CustomButton button,
    int originalIndex,
    int displayIndex,
    bool isDragging,
    bool isTargetPosition,
  ) {
    return LongPressDraggable<int>(
      data: originalIndex,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: buttonSize * 1.1,
          height: buttonSize * 1.1,
          decoration: BoxDecoration(
            color: button.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _selectedAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _buildButtonContent(button),
        ),
      ),
      childWhenDragging: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: buttonSize,
            decoration: BoxDecoration(
              color: _selectedAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedAccent.withOpacity(0.5),
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
            _onDragUpdate(displayIndex);
          }
          return details.data != originalIndex;
        },
        onAcceptWithDetails: (details) {},
        onLeave: (_) {},
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: buttonSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isHovering || isTargetPosition
                  ? Border.all(color: _selectedAccent, width: 2)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isDragging ? 0.0 : 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        width: double.infinity,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: button.color.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: _buildButtonContent(button),
                      ),
                    ),
                  ),
                ),
                if (!isDragging)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _removeButtonFromPad(originalIndex),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _deleteColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _deleteColor.withOpacity(0.3),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildButtonContent(CustomButton button) {
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getContrastColor(button.color),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              button.koreanName,
              style: TextStyle(
                fontSize: 8,
                color: _getContrastColor(button.color).withOpacity(0.85),
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideButtons() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
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
                      size: 20,
                      color: _deleteColor,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '삭제',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: buttonSpacing),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 1.5,
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      _selectedAccent,
                      const Color(0xFF8B5CF6),
                      const Color(0xFFEC4899),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.palette,
                        size: 20,
                        color: Colors.white,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
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

  Widget _buildButtonPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '버튼 미리보기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _abbreviationController,
                maxLength: 5,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: '약자 (최대 5자)',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _selectedAccent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _koreanNameController,
                maxLength: 8,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: '한글명 (최대 8자)',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _selectedAccent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _abbreviationController.text.isEmpty
                                ? '?'
                                : _abbreviationController.text,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getContrastColor(_selectedColor),
                            ),
                          ),
                        ),
                      ),
                      if (_koreanNameController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _koreanNameController.text,
                              style: TextStyle(
                                fontSize: 11,
                                color: _getContrastColor(_selectedColor).withOpacity(0.85),
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _showColorPickerDialog,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _selectedAccent.withOpacity(0.8),
                          const Color(0xFF8B5CF6).withOpacity(0.8),
                          const Color(0xFFEC4899).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showColorPickerDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.1),
      builder: (context) => _ColorPickerPopup(
        initialColor: _selectedColor,
        onColorSelected: (color) {
          setState(() {
            _selectedColor = color;
            _hexController.text = _colorToHex(color);
          });
        },
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _addButtonToPad,
        icon: const Icon(Icons.add),
        label: const Text('버튼추가'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '버튼 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ButtonPresets.all.map((preset) {
            final isSelected = _selectedPreset?.id == preset.id;
            return GestureDetector(
              onTap: () => _selectPreset(preset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedAccent.withOpacity(0.9)
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? _selectedAccent.withOpacity(0.3)
                            : Colors.white.withOpacity(0.8),
                        width: 1.5,
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
                              preset.abbreviation,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
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
                              preset.koreanName,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? Colors.white70 : Colors.black54,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          widget.onButtonsChanged(_padButtons);
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          '저장',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 색상 선택 팝업
class _ColorPickerPopup extends StatefulWidget {
  final Color initialColor;
  final Function(Color) onColorSelected;

  const _ColorPickerPopup({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerPopup> createState() => _ColorPickerPopupState();
}

class _ColorPickerPopupState extends State<_ColorPickerPopup> {
  late Color _selectedColor;
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;

  static const Color _selectedAccent = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).substring(2).toUpperCase();
  }

  void _updateFromHex(String hex) {
    hex = hex.replaceAll('#', '').toUpperCase();
    if (hex.length == 6) {
      try {
        final color = Color(int.parse('FF$hex', radix: 16));
        final hsv = HSVColor.fromColor(color);
        setState(() {
          _selectedColor = color;
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      } catch (_) {}
    }
  }

  void _updateFromHSV() {
    final color = HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();
    setState(() {
      _selectedColor = color;
      _hexController.text = _colorToHex(color);
    });
  }

  void _updateFromPosition(double dx, double dy, double width, double height) {
    setState(() {
      _saturation = (dx / width).clamp(0.0, 1.0);
      _value = (1 - dy / height).clamp(0.0, 1.0);
      _updateFromHSV();
    });
  }

  void _updateHue(double dy, double height) {
    setState(() {
      _hue = (dy / height * 360).clamp(0.0, 360.0);
      _updateFromHSV();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '색상 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          const Text('#', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _hexController,
                              decoration: InputDecoration(
                                hintText: 'FFFFFF',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _selectedAccent),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              maxLength: 6,
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              onChanged: _updateFromHex,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 2D 색상 피커
                Row(
                  children: [
                    // Saturation-Value 그리드
                    Expanded(
                      child: GestureDetector(
                        onPanDown: (details) {
                          _updateFromPosition(
                            details.localPosition.dx,
                            details.localPosition.dy,
                            MediaQuery.of(context).size.width - 100,
                            250,
                          );
                        },
                        onPanUpdate: (details) {
                          _updateFromPosition(
                            details.localPosition.dx,
                            details.localPosition.dy,
                            MediaQuery.of(context).size.width - 100,
                            250,
                          );
                        },
                        child: Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                HSVColor.fromAHSV(1, _hue, 1, 1).toColor(),
                              ],
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black,
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: _saturation * (MediaQuery.of(context).size.width - 100) - 10,
                                  top: (1 - _value) * 250 - 10,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hue 바
                    GestureDetector(
                      onPanDown: (details) {
                        _updateHue(details.localPosition.dy, 250);
                      },
                      onPanUpdate: (details) {
                        _updateHue(details.localPosition.dy, 250);
                      },
                      child: Container(
                        width: 30,
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0000FF),
                              Color(0xFFFF00FF),
                              Color(0xFFFF0000),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: (_hue / 360 * 250) - 2,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onColorSelected(_selectedColor);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
