import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
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
  late final PageController _pageController;
  final GlobalKey<YoutubeListScreenState> _youtubeScreenKey = GlobalKey();

  // Liquid Glass 색상 정의
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _accentColor = Color(0xFF6B7280);
  static const Color _selectedAccent = Color(0xFF6B7280);

  // 기본 버튼 목록 (K, P)
  List<CustomButton> _padButtons = [
    ButtonPresets.knit,
    ButtonPresets.purl,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentNavIndex);
  }

  ScrollController _getScrollController(int index) {
    if (!_scrollControllers.containsKey(index)) {
      _scrollControllers[index] = ScrollController();
    }
    return _scrollControllers[index]!;
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      barrierColor: Colors.black.withOpacity(0.1),
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
      backgroundColor: _glassBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildPageView(),
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
            // Video Player (한 곳에서만 렌더링)
            if (_shouldShowVideoPlayer()) _buildVideoPlayerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildRecordTab(),
        _buildVideoTab(),
        _buildPatternTab(),
      ],
    );
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
    return YoutubeListScreen(
      key: _youtubeScreenKey,
      embedded: true,
    );
  }

  Widget _buildPatternTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_on,
            size: 64,
            color: _accentColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            '도안 기능 준비 중',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
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

  // Video Player 표시 여부 확인
  bool _shouldShowVideoPlayer() {
    final youtubeState = _youtubeScreenKey.currentState;
    return youtubeState?.currentVideo != null &&
           youtubeState?.playerController != null;
  }

  // Video Player 위젯 (영상 탭이면 상단에, 아니면 floating)
  Widget _buildVideoPlayerWidget() {
    final youtubeState = _youtubeScreenKey.currentState;
    if (youtubeState == null) return const SizedBox.shrink();

    final video = youtubeState.currentVideo;
    final controller = youtubeState.playerController;
    if (video == null || controller == null) return const SizedBox.shrink();

    // 영상 탭일 때는 상단에 큰 플레이어
    if (_currentNavIndex == 1) {
      return Positioned(
        top: 56, // 헤더 아래
        left: 0,
        right: 0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 바
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        youtubeState.stopVideo();
                      },
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // YouTube Player
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(
                    controller: controller,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 다른 탭일 때는 Floating Player
    return _buildFloatingPlayer(video, controller);
  }

  // Floating player UI
  Widget _buildFloatingPlayer(YoutubeVideo video, YoutubePlayerController controller) {
    return Positioned(
      right: 16,
      bottom: 100, // 바텀 네비게이션 바 위에 배치
      child: GestureDetector(
        onTap: () {
          // floating player 탭하면 영상 탭으로 이동
          setState(() {
            _currentNavIndex = 1;
          });
          _pageController.jumpToPage(1);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _accentColor.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 제목 바 (위로 이동)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            video.title,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.open_in_full,
                          size: 12,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  // YouTube Player
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    const navItems = [
      (Icons.edit_note, '기록'),
      (Icons.play_circle_outline, '영상'),
      (Icons.grid_on, '도안'),
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.9),
                width: 1,
              ),
            ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 3;
                  const indicatorWidth = 72.0;
                  final indicatorLeft =
                      (itemWidth * _currentNavIndex) + (itemWidth - indicatorWidth) / 2;

                  return Stack(
                    children: [
                      // 슬라이딩 인디케이터
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        top: 0,
                        bottom: 0,
                        width: indicatorWidth,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _selectedAccent.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 네비게이션 아이템들
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (int i = 0; i < navItems.length; i++)
                            _buildNavItem(i, navItems[i].$1, navItems[i].$2),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
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
        _pageController.jumpToPage(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey('$index-$isSelected'),
                size: 24,
                color: isSelected ? _selectedAccent : Colors.black38,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? _selectedAccent : Colors.black38,
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
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black54),
          ),
          const SizedBox(width: 12),
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
                  '${rowIndex + 1}단',
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isCurrentRow ? 0.7 : 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentRow
                          ? _selectedAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.8),
                      width: isCurrentRow ? 2 : 1.5,
                    ),
                    boxShadow: isCurrentRow
                        ? [
                            BoxShadow(
                              color: _selectedAccent.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: stitch.color.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1.5,
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
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
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
