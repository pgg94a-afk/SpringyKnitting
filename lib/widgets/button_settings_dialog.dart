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
  List<CustomButton>? _previewButtons; // 드래그 중 미리보기용
  int? _draggingIndex;
  int? _targetIndex;

  CustomButton? _selectedPreset;
  Color _selectedColor = Colors.white;
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _abbreviationController = TextEditingController();
  final TextEditingController _koreanNameController = TextEditingController();

  static const double buttonSize = 55.0;
  static const double buttonSpacing = 8.0;
  static const int gridColumns = 3;
  static const double sideButtonWidth = 55.0;

  @override
  void initState() {
    super.initState();
    _padButtons = List.from(widget.currentButtons);
    _hexController.text = 'FFFFFF';
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
        const SnackBar(content: Text('버튼 약자를 입력해주세요')),
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
      _selectedColor = Colors.white;
      _hexController.text = 'FFFFFF';
    });
  }

  void _removeButtonFromPad(int index) {
    setState(() {
      _padButtons.removeAt(index);
    });
  }

  // 드래그 시작
  void _onDragStart(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingIndex = index;
      _targetIndex = index;
      _previewButtons = List.from(_padButtons);
    });
  }

  // 드래그 중 타겟 위치 업데이트 (실시간 미리보기)
  void _onDragUpdate(int newTargetIndex) {
    if (_draggingIndex == null || newTargetIndex == _targetIndex) return;
    if (newTargetIndex < 0 || newTargetIndex >= _padButtons.length) return;

    setState(() {
      _targetIndex = newTargetIndex;
      // 미리보기 리스트 재구성
      _previewButtons = List.from(_padButtons);
      final item = _previewButtons!.removeAt(_draggingIndex!);
      _previewButtons!.insert(newTargetIndex, item);
    });
  }

  // 드래그 완료
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

  // 드래그 취소
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
      backgroundColor: const Color(0xFFFFF0F3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
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
          child: const Icon(Icons.close, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildCurrentPadSection() {
    // 드래그 중이면 미리보기 리스트, 아니면 실제 리스트
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD1DC)),
          ),
          child: _buildPadGrid(displayButtons),
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
        // 왼쪽: 버튼 그리드
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
                    // 실제 인덱스 찾기 (미리보기에서의 위치가 아닌 원본 인덱스)
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
        // 오른쪽: 삭제/세팅 버튼
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: buttonSize * 1.1,
          height: buttonSize * 1.1,
          decoration: BoxDecoration(
            color: button.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFB6C1), width: 2),
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
      childWhenDragging: Container(
        height: buttonSize,
        decoration: BoxDecoration(
          color: const Color(0xFFFFB6C1).withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFFFB6C1),
            width: 2,
            style: BorderStyle.solid,
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
        onAcceptWithDetails: (details) {
          // 드래그 완료는 onDragEnd에서 처리
        },
        onLeave: (_) {},
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: buttonSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isHovering || isTargetPosition
                  ? Border.all(color: const Color(0xFFFFB6C1), width: 2)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isDragging ? 0.0 : 1.0,
                  child: Container(
                    width: double.infinity,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      color: button.color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
                    ),
                    child: _buildButtonContent(button),
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
                color: _getContrastColor(button.color).withOpacity(0.7),
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
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: Color(0xFFFF6B6B),
                ),
                SizedBox(height: 2),
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
        ),
        const SizedBox(height: buttonSpacing),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD1DC),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                            color: _getContrastColor(_selectedColor).withOpacity(0.7),
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _showColorPickerDialog,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF6B6B),
                      Color(0xFFFFE66D),
                      Color(0xFF4ECDC4),
                      Color(0xFF95E1D3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFD1DC),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
          ],
        ),
      ],
    );
  }

  void _showColorPickerDialog() {
    showDialog(
      context: context,
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
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _addButtonToPad,
        icon: const Icon(Icons.add),
        label: const Text('버튼추가'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB6C1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFB6C1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFD1DC),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      preset.abbreviation,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      preset.koreanName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
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
          backgroundColor: const Color(0xFFFFB6C1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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

  static const List<Color> _paletteColors = [
    Colors.white,
    Color(0xFFFFF5E6),
    Color(0xFFFFE4E1),
    Color(0xFFE6E6FA),
    Color(0xFFE0FFFF),
    Color(0xFFE8F5E9),
    Color(0xFFFFF8DC),
    Color(0xFFFFC0CB),
    Color(0xFFFFB6C1),
    Color(0xFFDDA0DD),
    Color(0xFFADD8E6),
    Color(0xFF98FB98),
    Color(0xFFFFDAB9),
    Color(0xFFF0E68C),
    Color(0xFFD3D3D3),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFF95E1D3),
    Color(0xFFF38181),
  ];

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

  void _selectPaletteColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _selectedColor = color;
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = _colorToHex(color);
    });
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFF0F3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD1DC), width: 2),
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
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFFFD1DC)),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paletteColors.map((color) {
                  final isSelected = _selectedColor.value == color.value;
                  return GestureDetector(
                    onTap: () => _selectPaletteColor(color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFB6C1) : const Color(0xFFFFD1DC),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: _getContrastColor(color))
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 40, child: Text('색상', style: TextStyle(fontSize: 12))),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 12,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            activeTrackColor: HSVColor.fromAHSV(1, _hue, 1, 1).toColor(),
                            inactiveTrackColor: Colors.grey[300],
                          ),
                          child: Slider(
                            value: _hue,
                            min: 0,
                            max: 360,
                            onChanged: (value) {
                              _hue = value;
                              _updateFromHSV();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 40, child: Text('채도', style: TextStyle(fontSize: 12))),
                      Expanded(
                        child: Slider(
                          value: _saturation,
                          min: 0,
                          max: 1,
                          activeColor: const Color(0xFFFFB6C1),
                          onChanged: (value) {
                            _saturation = value;
                            _updateFromHSV();
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 40, child: Text('명도', style: TextStyle(fontSize: 12))),
                      Expanded(
                        child: Slider(
                          value: _value,
                          min: 0,
                          max: 1,
                          activeColor: const Color(0xFFFFB6C1),
                          onChanged: (value) {
                            _value = value;
                            _updateFromHSV();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  backgroundColor: const Color(0xFFFFB6C1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
    );
  }
}
