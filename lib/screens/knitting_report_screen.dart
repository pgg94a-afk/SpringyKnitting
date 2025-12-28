import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../models/stitch.dart';
import '../models/custom_button.dart';
import '../models/youtube_video.dart';
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
  final GlobalKey _youtubePlayerKey = GlobalKey(); // YoutubePlayer 위젯 인스턴스 유지용

  // Floating player 위치 및 크기 관리
  double _floatingPlayerX = 16; // 오른쪽 여백
  double _floatingPlayerY = 100; // 바텀 네비게이션 바 위
  double _floatingPlayerScale = 1.0; // 크기 배율 (1.0 ~ 1.5)
  double _baseFloatingPlayerWidth = 200.0; // 기본 크기
  double _scaleStart = 1.0; // 스케일 시작 시 저장
  Offset _lastFocalPoint = Offset.zero; // 마지막 focal point

  // Liquid Glass 색상 정의
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _accentColor = Color(0xFF6B7280);
  static const Color _selectedAccent = Color(0xFF6B7280);

  // 기본 버튼 목록 (K, P)
  List<CustomButton> _padButtons = [
    ButtonPresets.knit,
    ButtonPresets.purl,
  ];

  // 트레이스 탭 관련 변수
  int _gridRows = 10;
  int _gridCols = 10;
  List<List<Stitch?>> _traceGrid = [];
  int _currentTraceRow = 0;
  int _currentTraceCol = 0;

  // X영역 (제외된 셀) 관리
  final Set<String> _excludedCells = {}; // "row,col" 형식으로 저장

  // 드래그 선택용 변수
  int? _dragStartRow;
  int? _dragStartCol;
  int? _dragEndRow;
  int? _dragEndCol;
  bool _isSelectingExcluded = false;

  // 격자 보기 관련
  final TransformationController _transformationController = TransformationController();
  bool _isGridConfigured = false; // 격자 설정 완료 여부
  final GlobalKey _gridPaintKey = GlobalKey(); // CustomPaint 위치 추적용

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentNavIndex);
    _initializeTraceGrid();
  }

  void _initializeTraceGrid() {
    _traceGrid = List.generate(
      _gridRows,
      (_) => List.generate(_gridCols, (_) => null),
    );
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
    _transformationController.dispose();
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
                if (_currentNavIndex == 2)
                  StitchPad(
                    buttons: _padButtons,
                    onButtonTap: _addTraceStitch,
                    onAddRow: () {}, // 트레이스에서는 행 추가 안함
                    onDelete: _removeTraceStitch,
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
        _buildTraceTab(),
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
    final youtubeState = _youtubeScreenKey.currentState;
    final isPlayerVisible = _currentNavIndex == 1 &&
                           youtubeState?.currentVideo != null &&
                           youtubeState?.playerController != null;

    return YoutubeListScreen(
      key: _youtubeScreenKey,
      embedded: true,
      isPlayerVisible: isPlayerVisible,
      onVideoStateChanged: () {
        // 영상 상태가 변경되면 KnittingReportScreen rebuild
        setState(() {});
      },
    );
  }

  Widget _buildTraceTab() {
    if (!_isGridConfigured) {
      return _buildGridSetup();
    }
    return _buildGridCanvas();
  }

  Widget _buildGridSetup() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(
              Icons.grid_on,
              size: 64,
              color: _accentColor.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            const Text(
              '트레이스 모드',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '격자 크기를 설정하고\n따라 그리기를 시작하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            // Grid 설정
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _accentColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '행 개수',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _gridRows > 1 ? () {
                              setState(() {
                                _gridRows--;
                              });
                            } : null,
                          ),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: TextEditingController(text: '$_gridRows'),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                final rows = int.tryParse(value);
                                if (rows != null && rows > 0 && rows <= 200) {
                                  setState(() {
                                    _gridRows = rows;
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _gridRows < 200 ? () {
                              setState(() {
                                _gridRows++;
                              });
                            } : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '열 개수',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _gridCols > 1 ? () {
                              setState(() {
                                _gridCols--;
                              });
                            } : null,
                          ),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: TextEditingController(text: '$_gridCols'),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                final cols = int.tryParse(value);
                                if (cols != null && cols > 0 && cols <= 200) {
                                  setState(() {
                                    _gridCols = cols;
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _gridCols < 200 ? () {
                              setState(() {
                                _gridCols++;
                              });
                            } : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 시작 버튼
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isGridConfigured = true;
                  _initializeTraceGrid();
                  // 시작 위치: 가장 우측, 가장 하단 (0,0)
                  _currentTraceRow = 0;
                  _currentTraceCol = _gridCols - 1;
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('시작하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildGridCanvas() {
    return Column(
      children: [
        // 상단 컨트롤
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${_currentTraceRow + 1}행 ${_currentTraceCol + 1}열',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // X영역 선택 모드 토글 (강조)
                  Container(
                    decoration: BoxDecoration(
                      color: _isSelectingExcluded
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSelectingExcluded ? Colors.red : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isSelectingExcluded = !_isSelectingExcluded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSelectingExcluded ? Icons.close : Icons.block,
                              color: _isSelectingExcluded ? Colors.red : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isSelectingExcluded ? 'X선택 종료' : 'X영역 선택',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isSelectingExcluded ? Colors.red : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 초기화 버튼
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 22),
                    onPressed: () {
                      setState(() {
                        _isGridConfigured = false;
                        _excludedCells.clear();
                        _currentTraceRow = 0;
                        _currentTraceCol = 0;
                        _transformationController.value = Matrix4.identity();
                      });
                    },
                    tooltip: '처음부터',
                  ),
                ],
              ),
              if (_isSelectingExcluded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '탭: 단일 선택 / 길게 누르고 드래그: 범위 선택',
                            style: TextStyle(fontSize: 11, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Grid Canvas
        Expanded(
          child: _buildInteractiveGrid(),
        ),
        // 키패드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.9),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 뒤로 버튼
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _moveToPreviousTraceCell,
                tooltip: '이전 셀',
              ),
              // 버튼들
              ..._padButtons.map((button) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () => _addTraceStitch(button),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: button.color,
                    foregroundColor: _getContrastColor(button.color),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    button.abbreviation,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )),
              // 삭제 버튼
              IconButton(
                icon: const Icon(Icons.backspace),
                onPressed: _removeTraceStitch,
                tooltip: '삭제',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveGrid() {
    // 화면 크기에 맞춰 셀 크기 계산
    final screenSize = MediaQuery.of(context).size;
    final availableWidth = screenSize.width - 32;
    final availableHeight = screenSize.height - 350; // 상단 컨트롤 + 하단 키패드 공간

    final cellSizeByWidth = availableWidth / _gridCols;
    final cellSizeByHeight = availableHeight / _gridRows;
    final baseCellSize = (cellSizeByWidth < cellSizeByHeight ? cellSizeByWidth : cellSizeByHeight).clamp(10.0, 60.0);

    final gridWidth = _gridCols * baseCellSize;
    final gridHeight = _gridRows * baseCellSize;

    return GestureDetector(
      onTapDown: _isSelectingExcluded ? (details) {
        _handleGridTap(details, baseCellSize, gridWidth, gridHeight);
      } : null,
      onLongPressStart: _isSelectingExcluded ? (details) {
        _handleGridLongPressStart(details, baseCellSize, gridWidth, gridHeight);
      } : null,
      onLongPressMoveUpdate: _isSelectingExcluded ? (details) {
        _handleGridLongPressUpdate(details, baseCellSize, gridWidth, gridHeight);
      } : null,
      onLongPressEnd: _isSelectingExcluded ? (_) {
        _handleGridLongPressEnd();
      } : null,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(100),
        panEnabled: !_isSelectingExcluded,
        scaleEnabled: !_isSelectingExcluded,
        child: Center(
          child: CustomPaint(
            key: _gridPaintKey,
            size: Size(gridWidth, gridHeight),
            painter: _TraceGridPainter(
              rows: _gridRows,
              cols: _gridCols,
              cellSize: baseCellSize,
              traceGrid: _traceGrid,
              currentRow: _currentTraceRow,
              currentCol: _currentTraceCol,
              excludedCells: _excludedCells,
              dragStartRow: _dragStartRow,
              dragStartCol: _dragStartCol,
              dragEndRow: _dragEndRow,
              dragEndCol: _dragEndCol,
              isSelectingExcluded: _isSelectingExcluded,
            ),
          ),
        ),
      ),
    );
  }

  void _handleGridTap(TapDownDetails details, double cellSize, double gridWidth, double gridHeight) {
    // CustomPaint의 RenderBox 찾기
    final RenderBox? gridBox = _gridPaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;

    // 글로벌 좌표를 CustomPaint의 로컬 좌표로 변환
    final localPos = gridBox.globalToLocal(details.globalPosition);

    final gridX = localPos.dx;
    final gridY = localPos.dy;

    if (gridX >= 0 && gridX < gridWidth && gridY >= 0 && gridY < gridHeight) {
      final col = (gridX / cellSize).floor().clamp(0, _gridCols - 1);
      final row = (_gridRows - 1 - (gridY / cellSize).floor()).clamp(0, _gridRows - 1);

      setState(() {
        // 단일 셀 토글
        final key = '$row,$col';
        if (_excludedCells.contains(key)) {
          _excludedCells.remove(key);
        } else {
          _excludedCells.add(key);
        }
      });
    }
  }

  void _handleGridLongPressStart(LongPressStartDetails details, double cellSize, double gridWidth, double gridHeight) {
    final RenderBox? gridBox = _gridPaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;

    final localPos = gridBox.globalToLocal(details.globalPosition);

    final gridX = localPos.dx;
    final gridY = localPos.dy;

    if (gridX >= 0 && gridX < gridWidth && gridY >= 0 && gridY < gridHeight) {
      setState(() {
        _dragStartCol = (gridX / cellSize).floor().clamp(0, _gridCols - 1);
        _dragStartRow = (_gridRows - 1 - (gridY / cellSize).floor()).clamp(0, _gridRows - 1);
        _dragEndCol = _dragStartCol;
        _dragEndRow = _dragStartRow;
      });
    }
  }

  void _handleGridLongPressUpdate(LongPressMoveUpdateDetails details, double cellSize, double gridWidth, double gridHeight) {
    if (_dragStartRow == null || _dragStartCol == null) return;

    final RenderBox? gridBox = _gridPaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return;

    final localPos = gridBox.globalToLocal(details.globalPosition);

    final gridX = localPos.dx;
    final gridY = localPos.dy;

    if (gridX >= 0 && gridX < gridWidth && gridY >= 0 && gridY < gridHeight) {
      setState(() {
        _dragEndCol = (gridX / cellSize).floor().clamp(0, _gridCols - 1);
        _dragEndRow = (_gridRows - 1 - (gridY / cellSize).floor()).clamp(0, _gridRows - 1);
      });
    }
  }

  void _handleGridLongPressEnd() {
    if (_dragStartRow == null || _dragStartCol == null || _dragEndRow == null || _dragEndCol == null) return;

    setState(() {
      final minRow = _dragStartRow! < _dragEndRow! ? _dragStartRow! : _dragEndRow!;
      final maxRow = _dragStartRow! > _dragEndRow! ? _dragStartRow! : _dragEndRow!;
      final minCol = _dragStartCol! < _dragEndCol! ? _dragStartCol! : _dragEndCol!;
      final maxCol = _dragStartCol! > _dragEndCol! ? _dragStartCol! : _dragEndCol!;

      for (int row = minRow; row <= maxRow; row++) {
        for (int col = minCol; col <= maxCol; col++) {
          final key = '$row,$col';
          if (_excludedCells.contains(key)) {
            _excludedCells.remove(key);
          } else {
            _excludedCells.add(key);
          }
        }
      }

      _dragStartRow = null;
      _dragStartCol = null;
      _dragEndRow = null;
      _dragEndCol = null;
    });
  }

  void _addTraceStitch(CustomButton button) {
    if (_currentTraceRow >= _gridRows) return;

    // X영역 확인
    final key = '$_currentTraceRow,$_currentTraceCol';
    if (_excludedCells.contains(key)) {
      // X영역이면 자동으로 다음 셀로 이동
      _moveToNextTraceCell();
      return;
    }

    setState(() {
      _traceGrid[_currentTraceRow][_currentTraceCol] = Stitch.fromButton(button);
      _moveToNextTraceCell();
    });
  }

  void _removeTraceStitch() {
    setState(() {
      if (_traceGrid[_currentTraceRow][_currentTraceCol] != null) {
        _traceGrid[_currentTraceRow][_currentTraceCol] = null;
      } else {
        _moveToPreviousTraceCell();
        _traceGrid[_currentTraceRow][_currentTraceCol] = null;
      }
    });
  }

  void _moveToNextTraceCell() {
    // 지그재그 패턴: 우측하단(0,0)에서 시작
    // 홀수 행(0,2,4...): 오른쪽에서 왼쪽
    // 짝수 행(1,3,5...): 왼쪽에서 오른쪽

    int attempts = 0;
    do {
      if (_currentTraceRow % 2 == 0) {
        // 홀수번째 줄 (0-based는 짝수): 오른쪽 → 왼쪽
        if (_currentTraceCol > 0) {
          _currentTraceCol--;
        } else {
          // 다음 행으로
          _currentTraceRow++;
          if (_currentTraceRow >= _gridRows) break;
          _currentTraceCol = 0; // 왼쪽부터 시작
        }
      } else {
        // 짝수번째 줄 (0-based는 홀수): 왼쪽 → 오른쪽
        if (_currentTraceCol < _gridCols - 1) {
          _currentTraceCol++;
        } else {
          // 다음 행으로
          _currentTraceRow++;
          if (_currentTraceRow >= _gridRows) break;
          _currentTraceCol = _gridCols - 1; // 오른쪽부터 시작
        }
      }

      final key = '$_currentTraceRow,$_currentTraceCol';
      if (!_excludedCells.contains(key)) break; // X영역이 아니면 중단

      attempts++;
    } while (attempts < _gridRows * _gridCols); // 무한 루프 방지
  }

  void _moveToPreviousTraceCell() {
    if (_currentTraceRow == 0 && _currentTraceCol == _gridCols - 1) {
      // 시작 위치면 더 이상 뒤로 갈 수 없음
      return;
    }

    int attempts = 0;
    do {
      if (_currentTraceRow % 2 == 0) {
        // 0행 (짝수): 정방향은 오른쪽 → 왼쪽이므로, 역방향은 왼쪽 ← 오른쪽 (증가)
        if (_currentTraceCol < _gridCols - 1) {
          _currentTraceCol++;
        } else if (_currentTraceRow > 0) {
          // 이전 행으로
          _currentTraceRow--;
          _currentTraceCol = _gridCols - 1; // 1행(홀수)의 끝은 오른쪽
        } else {
          break; // 0행의 끝이면 멈춤
        }
      } else {
        // 1행 (홀수): 정방향은 왼쪽 → 오른쪽이므로, 역방향은 오른쪽 ← 왼쪽 (감소)
        if (_currentTraceCol > 0) {
          _currentTraceCol--;
        } else {
          // 이전 행으로
          _currentTraceRow--;
          _currentTraceCol = 0; // 0행(짝수)의 끝은 왼쪽
        }
      }

      final key = '$_currentTraceRow,$_currentTraceCol';
      if (!_excludedCells.contains(key)) break; // X영역이 아니면 중단

      attempts++;
    } while (attempts < _gridRows * _gridCols); // 무한 루프 방지
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
                    key: _youtubePlayerKey, // 동일한 key로 위젯 인스턴스 유지
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
    final currentWidth = _baseFloatingPlayerWidth * _floatingPlayerScale;
    final currentHeight = currentWidth * 9 / 16 + 40; // 16:9 비율 + 타이틀바

    return Positioned(
      right: _floatingPlayerX,
      bottom: _floatingPlayerY,
      child: GestureDetector(
        onTap: () {
          // floating player 탭하면 영상 탭으로 이동
          setState(() {
            _currentNavIndex = 1;
          });
          _pageController.jumpToPage(1);
        },
        onScaleStart: (details) {
          // 스케일/드래그 시작 시 초기값 저장
          _scaleStart = _floatingPlayerScale;
          _lastFocalPoint = details.focalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            // 핀치 줌으로 크기 조절 (1.0 ~ 1.5배)
            _floatingPlayerScale = (_scaleStart * details.scale).clamp(1.0, 1.5);

            // 드래그로 위치 이동 (focalPointDelta 사용)
            final delta = details.focalPoint - _lastFocalPoint;
            _lastFocalPoint = details.focalPoint;

            // X축은 right 기준이므로 반대로
            _floatingPlayerX -= delta.dx;
            // Y축은 bottom 기준이므로 반대로
            _floatingPlayerY -= delta.dy;

            // 화면 밖으로 나가지 않도록 제한 (동적 크기 반영)
            final currentWidthNow = _baseFloatingPlayerWidth * _floatingPlayerScale;
            final currentHeightNow = currentWidthNow * 9 / 16 + 40;
            _floatingPlayerX = _floatingPlayerX.clamp(0.0, MediaQuery.of(context).size.width - currentWidthNow - 16);
            _floatingPlayerY = _floatingPlayerY.clamp(0.0, MediaQuery.of(context).size.height - currentHeightNow - 16);
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: currentWidth,
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
                      key: _youtubePlayerKey, // 동일한 key로 위젯 인스턴스 유지
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
      (Icons.grid_on, '트레이스'),
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

class _TraceGridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;
  final List<List<Stitch?>> traceGrid;
  final int currentRow;
  final int currentCol;
  final Set<String> excludedCells;
  final int? dragStartRow;
  final int? dragStartCol;
  final int? dragEndRow;
  final int? dragEndCol;
  final bool isSelectingExcluded;

  _TraceGridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.traceGrid,
    required this.currentRow,
    required this.currentCol,
    required this.excludedCells,
    this.dragStartRow,
    this.dragStartCol,
    this.dragEndRow,
    this.dragEndCol,
    required this.isSelectingExcluded,
  });

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 0. 행 번호 표시 (왼쪽에, 5단위로)
    final numberTextStyle = TextStyle(
      color: Colors.black.withOpacity(0.6),
      fontSize: (cellSize * 0.25).clamp(8.0, 12.0),
      fontWeight: FontWeight.bold,
    );

    for (int row = 0; row < rows; row++) {
      // 맨 하단부터 1, 2, 3... 순서
      final rowNumber = row + 1;

      // 5, 10, 15, 20, 25... 형태로 5단위마다 표시
      if (rowNumber % 5 == 0) {
        final displayRow = rows - 1 - row;
        final textPainter = TextPainter(
          text: TextSpan(text: '$rowNumber', style: numberTextStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            -textPainter.width - 6,
            displayRow * cellSize + (cellSize - textPainter.height) / 2,
          ),
        );
      }
    }

    // 1. 격자선 그리기
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final boldGridPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= rows; i++) {
      final y = i * cellSize;
      final rowNumber = rows - i; // 맨 하단이 1

      // 행 번호가 5의 배수면 굵은 선
      final isBoldLine = rowNumber > 0 && rowNumber % 5 == 0;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isBoldLine ? boldGridPaint : gridPaint,
      );
    }

    for (int i = 0; i <= cols; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 2. X영역 표시
    final excludedPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (final key in excludedCells) {
      final parts = key.split(',');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final displayRow = rows - 1 - row;

      canvas.drawRect(
        Rect.fromLTWH(col * cellSize, displayRow * cellSize, cellSize, cellSize),
        excludedPaint,
      );

      // X 표시
      final xPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final left = col * cellSize + 4;
      final top = displayRow * cellSize + 4;
      final right = (col + 1) * cellSize - 4;
      final bottom = (displayRow + 1) * cellSize - 4;

      canvas.drawLine(Offset(left, top), Offset(right, bottom), xPaint);
      canvas.drawLine(Offset(right, top), Offset(left, bottom), xPaint);
    }

    // 3. 드래그 선택 영역 표시
    if (isSelectingExcluded && dragStartRow != null && dragStartCol != null &&
        dragEndRow != null && dragEndCol != null) {
      final minRow = dragStartRow! < dragEndRow! ? dragStartRow! : dragEndRow!;
      final maxRow = dragStartRow! > dragEndRow! ? dragStartRow! : dragEndRow!;
      final minCol = dragStartCol! < dragEndCol! ? dragStartCol! : dragEndCol!;
      final maxCol = dragStartCol! > dragEndCol! ? dragStartCol! : dragEndCol!;

      final selectionPaint = Paint()
        ..color = Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      for (int row = minRow; row <= maxRow; row++) {
        for (int col = minCol; col <= maxCol; col++) {
          final displayRow = rows - 1 - row;
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, displayRow * cellSize, cellSize, cellSize),
            selectionPaint,
          );
        }
      }
    }

    // 4. 스티치 표시
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final stitch = traceGrid[row][col];
        if (stitch != null) {
          final displayRow = rows - 1 - row;

          final stitchPaint = Paint()
            ..color = stitch.color
            ..style = PaintingStyle.fill;

          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize + 2,
              displayRow * cellSize + 2,
              cellSize - 4,
              cellSize - 4,
            ),
            stitchPaint,
          );

          // 약어 텍스트
          final textPainter = TextPainter(
            text: TextSpan(
              text: stitch.abbreviation,
              style: TextStyle(
                color: _getContrastColor(stitch.color),
                fontSize: (cellSize * 0.3).clamp(8, 14),
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              col * cellSize + (cellSize - textPainter.width) / 2,
              displayRow * cellSize + (cellSize - textPainter.height) / 2,
            ),
          );
        }
      }
    }

    // 5. 현재 셀 하이라이트
    final displayCurrentRow = rows - 1 - currentRow;
    final highlightPaint = Paint()
      ..color = const Color(0xFF6B7280)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(
        currentCol * cellSize + 1.5,
        displayCurrentRow * cellSize + 1.5,
        cellSize - 3,
        cellSize - 3,
      ),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
