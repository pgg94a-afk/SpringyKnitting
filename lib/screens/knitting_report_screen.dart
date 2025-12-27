import 'package:flutter/material.dart';
import '../models/stitch.dart';
import '../models/custom_button.dart';
import '../widgets/stitch_pad.dart';
import '../widgets/add_button_dialog.dart';
import 'youtube_list_screen.dart';

class KnittingReportScreen extends StatefulWidget {
  const KnittingReportScreen({super.key});

  @override
  State<KnittingReportScreen> createState() => _KnittingReportScreenState();
}

class _KnittingReportScreenState extends State<KnittingReportScreen> {
  final List<List<Stitch>> _rows = [[]];
  int _currentRowIndex = 0;
  int _currentNavIndex = 0;
  final Map<int, ScrollController> _scrollControllers = {};

  // 기본 버튼 목록 (K, P)
  List<CustomButton> _padButtons = [
    ButtonPresets.knit,
    ButtonPresets.purl,
  ];

  ScrollController _getScrollController(int index) {
    if (!_scrollControllers.containsKey(index)) {
      _scrollControllers[index] = ScrollController();
    }
    return _scrollControllers[index]!;
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addStitch(CustomButton button) {
    setState(() {
      _rows[_currentRowIndex].add(Stitch.fromButton(button));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _scrollControllers[_currentRowIndex];
      if (controller != null && controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addRow() {
    setState(() {
      _rows.add([]);
      _currentRowIndex = _rows.length - 1;
    });
  }

  void _removeLastStitch() {
    setState(() {
      if (_rows[_currentRowIndex].isNotEmpty) {
        _rows[_currentRowIndex].removeLast();
      }
    });
  }

  void _deleteRow(int index) {
    if (_rows.length <= 1) return;

    setState(() {
      _scrollControllers[index]?.dispose();
      _scrollControllers.remove(index);
      _rows.removeAt(index);

      // Reindex scroll controllers
      final newControllers = <int, ScrollController>{};
      for (var i = 0; i < _rows.length; i++) {
        if (_scrollControllers.containsKey(i > index ? i + 1 : i)) {
          newControllers[i] = _scrollControllers[i > index ? i + 1 : i]!;
        }
      }
      _scrollControllers.clear();
      _scrollControllers.addAll(newControllers);

      if (_currentRowIndex >= _rows.length) {
        _currentRowIndex = _rows.length - 1;
      } else if (_currentRowIndex > index) {
        _currentRowIndex--;
      }
    });
  }

  void _clearRow(int index) {
    setState(() {
      _rows[index].clear();
    });
  }

  void _showAddButton() {
    showDialog(
      context: context,
      builder: (context) => AddButtonDialog(
        onButtonAdded: (button) {
          setState(() {
            _padButtons.add(button);
          });
        },
      ),
    );
  }

  void _onButtonsReordered(List<CustomButton> newButtons) {
    setState(() {
      _padButtons = newButtons;
    });
  }

  void _onButtonDeleted(int index) {
    setState(() {
      _padButtons.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _buildCurrentTab(),
            ),
            if (_currentNavIndex == 0)
              StitchPad(
                buttons: _padButtons,
                onButtonTap: _addStitch,
                onAddRow: _addRow,
                onDelete: _removeLastStitch,
                onEmptySlotTap: _showAddButton,
                onButtonsReordered: _onButtonsReordered,
                onButtonDeleted: _onButtonDeleted,
              ),
            _buildBottomNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentNavIndex) {
      case 0:
        return _buildRecordTab();
      case 1:
        return _buildVideoTab();
      case 2:
        return _buildPatternTab();
      default:
        return _buildRecordTab();
    }
  }

  Widget _buildRecordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._rows.asMap().entries.toList().reversed.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return _buildRow(index, row);
          }),
        ],
      ),
    );
  }

  Widget _buildVideoTab() {
    return const YoutubeListScreen(embedded: true);
  }

  Widget _buildPatternTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_on,
            size: 64,
            color: const Color(0xFFFFB6C1).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '도안 기능 준비 중',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '곧 만나요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.edit_note, '기록'),
              _buildNavItem(1, Icons.play_circle_outline, '영상'),
              _buildNavItem(2, Icons.grid_on, '도안'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFB6C1).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFFFFB6C1) : Colors.black38,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFFFB6C1) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, size: 20),
          ),
          const SizedBox(width: 8),
          const Text(
            'SpringyKnit',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int rowIndex, List<Stitch> row) {
    final isCurrentRow = rowIndex == _currentRowIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRowIndex = rowIndex;
        });
      },
      onLongPress: isCurrentRow ? _removeLastStitch : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'row ${rowIndex + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrentRow ? Colors.black87 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${row.length})',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCurrentRow ? Colors.black54 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: isCurrentRow ? Colors.black54 : Colors.black38,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteRow(rowIndex);
                    } else if (value == 'clear') {
                      _clearRow(rowIndex);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18),
                          SizedBox(width: 8),
                          Text('행 초기화'),
                        ],
                      ),
                    ),
                    if (_rows.length > 1)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('행 삭제', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(12),
                border: isCurrentRow
                    ? Border.all(color: const Color(0xFFFFB6C1), width: 2)
                    : null,
              ),
              child: row.isEmpty
                  ? null
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: _getScrollController(rowIndex),
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          padding: const EdgeInsets.all(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth - 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                for (var i = 0; i < row.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                                    child: _buildStitchCell(
                                      row[row.length - 1 - i],
                                      row.length - i,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStitchCell(Stitch stitch, int number) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: stitch.color,
              borderRadius: BorderRadius.circular(8),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getContrastColor(stitch.color),
                  ),
                ),
                Text(
                  stitch.koreanName,
                  style: TextStyle(
                    fontSize: 9,
                    color: _getContrastColor(stitch.color).withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB6C1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
