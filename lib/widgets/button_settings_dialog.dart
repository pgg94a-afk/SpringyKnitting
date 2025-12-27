import 'package:flutter/material.dart';
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
  CustomButton? _selectedPreset;
  Color _selectedColor = Colors.white;
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _abbreviationController = TextEditingController();
  final TextEditingController _koreanNameController = TextEditingController();

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
    });
  }

  void _removeButtonFromPad(int index) {
    setState(() {
      _padButtons.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _padButtons.removeAt(oldIndex);
      _padButtons.insert(newIndex, item);
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
                    _buildPresetSelector(),
                    const SizedBox(height: 20),
                    _buildButtonPreview(),
                    const SizedBox(height: 16),
                    _buildColorSelector(),
                    const SizedBox(height: 20),
                    _buildAddButton(),
                    const SizedBox(height: 20),
                    _buildCurrentPadSection(),
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
                decoration: InputDecoration(
                  hintText: '약자 (예: K)',
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
                decoration: InputDecoration(
                  hintText: '한글명 (예: 겉뜨기)',
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
        Center(
          child: Container(
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
                Text(
                  _abbreviationController.text.isEmpty
                      ? '?'
                      : _abbreviationController.text,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getContrastColor(_selectedColor),
                  ),
                ),
                if (_koreanNameController.text.isNotEmpty)
                  Text(
                    _koreanNameController.text,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getContrastColor(_selectedColor).withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '버튼 색상',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('#', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            SizedBox(
              width: 100,
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
                onChanged: _updateColorFromHex,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD1DC), width: 2),
                ),
                child: const Icon(Icons.colorize, size: 20, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildColorPalette(),
      ],
    );
  }

  Widget _buildColorPalette() {
    final colors = [
      Colors.white,
      const Color(0xFFFFF5E6), // cream
      const Color(0xFFFFE4E1), // misty rose
      const Color(0xFFE6E6FA), // lavender
      const Color(0xFFE0FFFF), // light cyan
      const Color(0xFFE8F5E9), // light green
      const Color(0xFFFFF8DC), // cornsilk
      const Color(0xFFFFC0CB), // pink
      const Color(0xFFFFB6C1), // light pink
      const Color(0xFFDDA0DD), // plum
      const Color(0xFFADD8E6), // light blue
      const Color(0xFF98FB98), // pale green
      const Color(0xFFFFDAB9), // peach puff
      const Color(0xFFF0E68C), // khaki
      const Color(0xFFD3D3D3), // light gray
      const Color(0xFFFF6B6B), // coral red
      const Color(0xFF4ECDC4), // teal
      const Color(0xFFFFE66D), // yellow
      const Color(0xFF95E1D3), // mint
      const Color(0xFFF38181), // salmon
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = _selectedColor.value == color.value;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
              _hexController.text = _colorToHex(color);
            });
          },
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
          ),
        );
      }).toList(),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
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

  Widget _buildCurrentPadSection() {
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD1DC)),
          ),
          child: _padButtons.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '버튼을 추가해주세요',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : ReorderableWrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _padButtons.asMap().entries.map((entry) {
                    return _buildPadButton(entry.key, entry.value);
                  }).toList(),
                  onReorder: _onReorder,
                ),
        ),
      ],
    );
  }

  Widget _buildPadButton(int index, CustomButton button) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: ValueKey(button.id),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: button.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD1DC), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                button.abbreviation,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getContrastColor(button.color),
                ),
              ),
              Text(
                button.koreanName,
                style: TextStyle(
                  fontSize: 9,
                  color: _getContrastColor(button.color).withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removeButtonFromPad(index),
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

/// 드래그 앤 드롭 가능한 Wrap 위젯
class ReorderableWrap extends StatefulWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final Function(int, int) onReorder;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.onReorder,
    this.spacing = 0,
    this.runSpacing = 0,
  });

  @override
  State<ReorderableWrap> createState() => _ReorderableWrapState();
}

class _ReorderableWrapState extends State<ReorderableWrap> {
  int? _draggingIndex;
  int? _targetIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: Transform.scale(
                scale: 1.1,
                child: child,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: child,
          ),
          onDragStarted: () {
            setState(() {
              _draggingIndex = index;
            });
          },
          onDragEnd: (_) {
            setState(() {
              _draggingIndex = null;
              _targetIndex = null;
            });
          },
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) {
              setState(() {
                _targetIndex = index;
              });
              return details.data != index;
            },
            onLeave: (_) {
              setState(() {
                _targetIndex = null;
              });
            },
            onAcceptWithDetails: (details) {
              widget.onReorder(details.data, index);
              setState(() {
                _targetIndex = null;
              });
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: BoxDecoration(
                  border: _targetIndex == index
                      ? Border.all(color: const Color(0xFFFFB6C1), width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: child,
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

/// 색상 선택 다이얼로그
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final Function(Color) onColorSelected;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _currentColor => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '색상 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // 색상 미리보기
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD1DC), width: 2),
              ),
            ),
            const SizedBox(height: 20),
            // 색상 슬라이더 (Hue)
            Row(
              children: [
                const Text('색상', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _hue,
                      min: 0,
                      max: 360,
                      onChanged: (value) => setState(() => _hue = value),
                    ),
                  ),
                ),
              ],
            ),
            // 채도 슬라이더
            Row(
              children: [
                const Text('채도', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _saturation,
                    min: 0,
                    max: 1,
                    onChanged: (value) => setState(() => _saturation = value),
                  ),
                ),
              ],
            ),
            // 명도 슬라이더
            Row(
              children: [
                const Text('명도', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _value,
                    min: 0,
                    max: 1,
                    onChanged: (value) => setState(() => _value = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onColorSelected(_currentColor);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB6C1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('선택'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
