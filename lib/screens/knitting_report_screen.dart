import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
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
  File? _traceImage;
  int _gridRows = 10;
  int _gridCols = 10;
  double _imageOpacity = 0.5;
  List<List<Stitch?>> _traceGrid = [];
  int _currentTraceRow = 0;
  int _currentTraceCol = 0;
  final ImagePicker _picker = ImagePicker();

  // 이미지 조정 관련 변수
  final TransformationController _transformationController = TransformationController();
  double _imageScale = 1.0;
  Offset _imageOffset = Offset.zero;
  bool _isAdjustMode = false;

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
    if (_traceImage == null) {
      return _buildTraceSetup();
    }
    return _buildTraceCanvas();
  }

  Widget _buildTraceSetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              '기호도 이미지를 업로드하여\n따라 그리기를 시작하세요',
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
                                _initializeTraceGrid();
                              });
                            } : null,
                          ),
                          Text(
                            '$_gridRows',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                _gridRows++;
                                _initializeTraceGrid();
                              });
                            },
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
                                _initializeTraceGrid();
                              });
                            } : null,
                          ),
                          Text(
                            '$_gridCols',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                _gridCols++;
                                _initializeTraceGrid();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 이미지 업로드 버튼
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('기호도 이미지 업로드'),
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
    );
  }

  Widget _buildTraceCanvas() {
    return Column(
      children: [
        // 상단 컨트롤
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.9),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '이미지 투명도',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _imageOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(_imageOpacity * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _imageOpacity = value;
                        });
                      },
                    ),
                  ),
                  // 이미지 조정 모드 토글
                  IconButton(
                    icon: Icon(
                      _isAdjustMode ? Icons.lock_open : Icons.lock,
                      color: _isAdjustMode ? _selectedAccent : Colors.black54,
                    ),
                    onPressed: () {
                      setState(() {
                        _isAdjustMode = !_isAdjustMode;
                      });
                    },
                    tooltip: _isAdjustMode ? '조정 모드 (드래그/줌 가능)' : '고정 모드',
                  ),
                  // 격자 자동 감지 버튼
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    onPressed: _detectGridFromImage,
                    tooltip: '격자 자동 감지',
                  ),
                  // 격자 크기 조정 버튼
                  IconButton(
                    icon: const Icon(Icons.grid_4x4),
                    onPressed: _showGridSizeDialog,
                    tooltip: '격자 크기 수동 조정',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _traceImage = null;
                        _currentTraceRow = 0;
                        _currentTraceCol = 0;
                        _initializeTraceGrid();
                        _transformationController.value = Matrix4.identity();
                      });
                    },
                  ),
                ],
              ),
              if (_isAdjustMode)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '드래그로 이동, 핀치로 확대/축소',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (!_isAdjustMode)
                Text(
                  '현재 위치: ${_currentTraceRow + 1}행 ${_currentTraceCol + 1}열',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
        ),
        // Grid Canvas
        Expanded(
          child: _buildGridWithImage(),
        ),
      ],
    );
  }

  Widget _buildGridWithImage() {
    final cellSize = 40.0;
    final gridWidth = _gridCols * cellSize;
    final gridHeight = _gridRows * cellSize;

    final gridContent = SizedBox(
      width: gridWidth,
      height: gridHeight,
      child: Stack(
        children: [
          // 배경 이미지 (투명도 적용)
          if (_traceImage != null)
            Positioned.fill(
              child: Opacity(
                opacity: _imageOpacity,
                child: Image.file(
                  _traceImage!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // Grid
          CustomPaint(
            size: Size(gridWidth, gridHeight),
            painter: _GridPainter(
              rows: _gridRows,
              cols: _gridCols,
              cellSize: cellSize,
            ),
          ),
          // 스티치 표시
          if (!_isAdjustMode) ..._buildStitchCells(cellSize),
        ],
      ),
    );

    // 조정 모드일 때는 InteractiveViewer 사용
    if (_isAdjustMode) {
      return InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Center(child: gridContent),
      );
    }

    // 일반 모드일 때는 스크롤 가능
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: gridContent,
      ),
    );
  }

  List<Widget> _buildStitchCells(double cellSize) {
    final List<Widget> cells = [];

    for (int row = 0; row < _gridRows; row++) {
      for (int col = 0; col < _gridCols; col++) {
        final stitch = _traceGrid[row][col];
        if (stitch != null) {
          // Grid는 위에서 아래로, 왼쪽에서 오른쪽
          // 하지만 뜨개질은 아래에서 위로
          final displayRow = _gridRows - 1 - row;

          cells.add(
            Positioned(
              left: col * cellSize,
              top: displayRow * cellSize,
              child: Container(
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: stitch.color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    stitch.abbreviation,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getContrastColor(stitch.color),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // 현재 셀 하이라이트
        if (row == _currentTraceRow && col == _currentTraceCol) {
          final displayRow = _gridRows - 1 - row;
          cells.add(
            Positioned(
              left: col * cellSize,
              top: displayRow * cellSize,
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }
      }
    }

    return cells;
  }

  void _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _traceImage = File(image.path);
      });
    }
  }

  void _addTraceStitch(CustomButton button) {
    if (_currentTraceRow >= _gridRows) return;

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

    if (_currentTraceRow % 2 == 0) {
      // 홀수번째 줄 (0-based는 짝수): 오른쪽 → 왼쪽
      if (_currentTraceCol > 0) {
        _currentTraceCol--;
      } else {
        // 다음 행으로
        _currentTraceRow++;
        _currentTraceCol = 0; // 왼쪽부터 시작
      }
    } else {
      // 짝수번째 줄 (0-based는 홀수): 왼쪽 → 오른쪽
      if (_currentTraceCol < _gridCols - 1) {
        _currentTraceCol++;
      } else {
        // 다음 행으로
        _currentTraceRow++;
        _currentTraceCol = _gridCols - 1; // 오른쪽부터 시작
      }
    }
  }

  void _moveToPreviousTraceCell() {
    if (_currentTraceRow % 2 == 0) {
      // 홀수번째 줄: 왼쪽 → 오른쪽 (역방향)
      if (_currentTraceCol < _gridCols - 1) {
        _currentTraceCol++;
      } else if (_currentTraceRow > 0) {
        _currentTraceRow--;
        _currentTraceCol = 0;
      }
    } else {
      // 짝수번째 줄: 오른쪽 → 왼쪽 (역방향)
      if (_currentTraceCol > 0) {
        _currentTraceCol--;
      } else if (_currentTraceRow > 0) {
        _currentTraceRow--;
        _currentTraceCol = _gridCols - 1;
      }
    }
  }

  // 픽셀 기반 격자 자동 감지
  Future<void> _detectGridFromImage() async {
    if (_traceImage == null) return;

    try {
      // 로딩 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // 이미지 로드
      final bytes = await _traceImage!.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('이미지를 읽을 수 없습니다');

      // 가로선 감지 (각 행의 평균 밝기)
      final horizontalBrightness = <int, double>{};
      for (int y = 0; y < image.height; y++) {
        double totalBrightness = 0;
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // RGB를 그레이스케일로 변환
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          totalBrightness += brightness;
        }
        horizontalBrightness[y] = totalBrightness / image.width;
      }

      // 세로선 감지 (각 열의 평균 밝기)
      final verticalBrightness = <int, double>{};
      for (int x = 0; x < image.width; x++) {
        double totalBrightness = 0;
        for (int y = 0; y < image.height; y++) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3;
          totalBrightness += brightness;
        }
        verticalBrightness[x] = totalBrightness / image.height;
      }

      // 어두운 선 찾기 (격자선)
      final horizontalLines = _findDarkLines(horizontalBrightness);
      final verticalLines = _findDarkLines(verticalBrightness);

      // 격자 개수 계산
      int detectedRows = horizontalLines.length > 1 ? horizontalLines.length - 1 : _gridRows;
      int detectedCols = verticalLines.length > 1 ? verticalLines.length - 1 : _gridCols;

      // UI 업데이트
      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

        setState(() {
          _gridRows = detectedRows.clamp(1, 50);
          _gridCols = detectedCols.clamp(1, 50);
          _initializeTraceGrid();
        });

        // 결과 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('격자 검출 완료: ${_gridRows}행 × ${_gridCols}열'),
            duration: const Duration(seconds: 2),
            backgroundColor: _selectedAccent,
          ),
        );
      }
    } catch (e) {
      // 오류 처리
      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('격자 검출 실패: 수동으로 조정해주세요'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 밝기 데이터에서 어두운 선 찾기
  List<int> _findDarkLines(Map<int, double> brightness) {
    if (brightness.isEmpty) return [];

    // 평균 밝기 계산
    final avgBrightness = brightness.values.reduce((a, b) => a + b) / brightness.length;

    // 최소값 찾기 (가장 어두운 부분)
    final minBrightness = brightness.values.reduce((a, b) => a < b ? a : b);

    // 임계값: 최소값에 훨씬 가까운 값 (최소값 + 차이의 15%)
    // 격자선은 가장 어두운 부분이므로 최소값에 가깝게 설정
    final threshold = minBrightness + (avgBrightness - minBrightness) * 0.15;

    // 어두운 선 찾기
    final darkLines = <int>[];
    for (final entry in brightness.entries) {
      if (entry.value < threshold) {
        darkLines.add(entry.key);
      }
    }

    if (darkLines.isEmpty) return [];

    // 가까운 선들을 그룹화 (연속된 어두운 픽셀은 하나의 선)
    final groupedLines = <int>[];
    int currentGroupStart = darkLines[0];
    int currentGroupEnd = darkLines[0];

    for (int i = 1; i < darkLines.length; i++) {
      if (darkLines[i] - currentGroupEnd <= 2) {
        // 연속된 픽셀, 그룹에 포함
        currentGroupEnd = darkLines[i];
      } else {
        // 새로운 그룹 시작
        // 현재 그룹의 중간점을 추가
        groupedLines.add((currentGroupStart + currentGroupEnd) ~/ 2);
        currentGroupStart = darkLines[i];
        currentGroupEnd = darkLines[i];
      }
    }
    // 마지막 그룹 추가
    groupedLines.add((currentGroupStart + currentGroupEnd) ~/ 2);

    // 간격이 너무 작은 선들 제거 (최소 2픽셀 이상)
    final filteredLines = <int>[groupedLines[0]];
    for (int i = 1; i < groupedLines.length; i++) {
      if (groupedLines[i] - filteredLines.last >= 2) {
        filteredLines.add(groupedLines[i]);
      }
    }

    return filteredLines;
  }

  // 격자 크기 조정 다이얼로그
  void _showGridSizeDialog() {
    int tempRows = _gridRows;
    int tempCols = _gridCols;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            '격자 크기 조정',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 행 조정
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '행 개수',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: tempRows > 1
                            ? () {
                                setDialogState(() {
                                  tempRows--;
                                });
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$tempRows',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setDialogState(() {
                            tempRows++;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              // 열 조정
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '열 개수',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: tempCols > 1
                            ? () {
                                setDialogState(() {
                                  tempCols--;
                                });
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$tempCols',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setDialogState(() {
                            tempCols++;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _gridRows = tempRows;
                  _gridCols = tempCols;
                  _initializeTraceGrid();
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('적용'),
            ),
          ],
        ),
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

class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;

  _GridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 가로선 그리기
    for (int i = 0; i <= rows; i++) {
      final y = i * cellSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // 세로선 그리기
    for (int i = 0; i <= cols; i++) {
      final x = i * cellSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
