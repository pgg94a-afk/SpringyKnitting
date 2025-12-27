import 'package:flutter/material.dart';
import '../models/custom_button.dart';

class AddButtonDialog extends StatefulWidget {
  final Function(CustomButton) onButtonAdded;

  const AddButtonDialog({
    super.key,
    required this.onButtonAdded,
  });

  @override
  State<AddButtonDialog> createState() => _AddButtonDialogState();
}

class _AddButtonDialogState extends State<AddButtonDialog> {
  CustomButton? _selectedPreset;
  Color _selectedColor = const Color(0xFFFFE4E1);
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _abbreviationController = TextEditingController();
  final TextEditingController _koreanNameController = TextEditingController();

  final FocusNode _abbreviationFocus = FocusNode();
  final FocusNode _koreanNameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _hexController.text = 'FFE4E1';
  }

  @override
  void dispose() {
    _hexController.dispose();
    _abbreviationController.dispose();
    _koreanNameController.dispose();
    _abbreviationFocus.dispose();
    _koreanNameFocus.dispose();
    super.dispose();
  }

  void _selectPreset(CustomButton preset) {
    setState(() {
      _selectedPreset = preset;
      _abbreviationController.text = preset.abbreviation;
      _koreanNameController.text = preset.koreanName;
    });
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).substring(2).toUpperCase();
  }

  void _addButton() {
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

    widget.onButtonAdded(newButton);
    Navigator.pop(context);
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFF0F3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildButtonPreview(),
                    const SizedBox(height: 24),
                    _buildPresetSelector(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildAddButton(),
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
          '버튼 추가',
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

  Widget _buildButtonPreview() {
    final contrastColor = _getContrastColor(_selectedColor);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 큰 미리보기 버튼 (인풋 내장)
        Expanded(
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(16),
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
                // 약자 입력
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _abbreviationController,
                    focusNode: _abbreviationFocus,
                    maxLength: 5,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: contrastColor,
                    ),
                    decoration: InputDecoration(
                      hintText: '약자',
                      hintStyle: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: contrastColor.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 4),
                // 한글명 입력
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _koreanNameController,
                    focusNode: _koreanNameFocus,
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: contrastColor.withOpacity(0.7),
                    ),
                    decoration: InputDecoration(
                      hintText: '한글명',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: contrastColor.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 색상 선택 버튼
        GestureDetector(
          onTap: _showColorPickerDialog,
          child: Container(
            width: 60,
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF6B6B),
                  Color(0xFFFFE66D),
                  Color(0xFF4ECDC4),
                  Color(0xFF95E1D3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
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
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.palette,
                  size: 32,
                  color: Colors.white,
                ),
                SizedBox(height: 4),
                Text(
                  '색상',
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
      ],
    );
  }

  Widget _buildPresetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프리셋',
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

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _addButton,
        icon: const Icon(Icons.add),
        label: const Text('추가'),
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
