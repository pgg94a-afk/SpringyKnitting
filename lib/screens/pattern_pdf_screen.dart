import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:file_picker/file_picker.dart';

class PatternPdfScreen extends StatefulWidget {
  final bool embedded;

  const PatternPdfScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<PatternPdfScreen> createState() => PatternPdfScreenState();
}

class PatternPdfScreenState extends State<PatternPdfScreen>
    with AutomaticKeepAliveClientMixin {
  PdfDocument? _pdfDocument;
  String? _pdfPath;
  String? _pdfName;
  bool _isLoading = false;

  // 페이지별 이미지 캐시
  final Map<int, PdfPageImage> _pageImages = {};

  @override
  bool get wantKeepAlive => true;

  // 형광펜 관련
  bool _isDrawingMode = false;
  Color _highlightColor = Colors.yellow.withOpacity(0.4);
  double _strokeWidth = 20.0;

  // 페이지별 드로잉 데이터
  final Map<int, List<DrawingStroke>> _pageDrawings = {};
  int _currentPage = 1;
  int _totalPages = 0;

  // 멀티터치 감지용
  int _pointerCount = 0;
  bool _isDrawing = false;

  // 플로팅 툴바 관련
  bool _isToolbarExpanded = false;
  bool _isEraserMode = false;
  Offset _toolbarPosition = const Offset(0, 0); // 초기 위치 (나중에 설정)
  bool _isToolbarPositionInitialized = false;
  static const double _collapsedToolbarSize = 56.0;
  static const double _expandedToolbarWidth = 340.0; // 펼쳐진 툴바 너비

  // 스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();

  // 디자인 색상
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _accentColor = Color(0xFF6B7280);

  @override
  void dispose() {
    _scrollController.dispose();
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _pdfPath = result.files.single.path;
          _pdfName = result.files.single.name;
          _pageDrawings.clear();
          _pageImages.clear();
          _currentPage = 1;
        });

        _pdfDocument?.close();
        final document = await PdfDocument.openFile(_pdfPath!);

        setState(() {
          _pdfDocument = document;
          _totalPages = document.pagesCount;
        });

        // 모든 페이지 로드
        await _loadAllPages();

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 불러오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _loadAllPages() async {
    if (_pdfDocument == null) return;

    for (int i = 1; i <= _totalPages; i++) {
      await _loadPage(i);
    }
  }

  Future<void> _loadPage(int pageNumber) async {
    if (_pdfDocument == null || _pageImages.containsKey(pageNumber)) return;

    final page = await _pdfDocument!.getPage(pageNumber);
    final pageImage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();

    if (mounted && pageImage != null) {
      setState(() {
        _pageImages[pageNumber] = pageImage;
      });
    }
  }

  void _toggleDrawingMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
    });
  }

  void _clearCurrentPageDrawings() {
    setState(() {
      _pageDrawings[_currentPage]?.clear();
    });
  }

  void _clearAllDrawings() {
    setState(() {
      _pageDrawings.clear();
    });
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildColorPickerSheet(),
    );
  }

  Widget _buildColorPickerSheet() {
    final colors = [
      Colors.yellow.withOpacity(0.4),
      Colors.pink.withOpacity(0.4),
      Colors.lightBlue.withOpacity(0.4),
      Colors.lightGreen.withOpacity(0.4),
      Colors.orange.withOpacity(0.4),
      Colors.purple.withOpacity(0.4),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '형광펜 색상',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: colors.map((color) {
              final isSelected = _highlightColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _highlightColor = color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _accentColor : Colors.grey.shade300,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            '펜 두께',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setSheetState) {
              return Slider(
                value: _strokeWidth,
                min: 10,
                max: 40,
                activeColor: _accentColor,
                onChanged: (value) {
                  setSheetState(() {});
                  setState(() => _strokeWidth = value);
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return widget.embedded
        ? _buildContent()
        : Scaffold(
            backgroundColor: _glassBackground,
            body: SafeArea(child: _buildContent()),
          );
  }

  Widget _buildContent() {
    if (_pdfDocument == null) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // 초기 위치 설정 (화면 하단 중앙)
        if (!_isToolbarPositionInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isToolbarPositionInitialized) {
              setState(() {
                _toolbarPosition = Offset(
                  (screenWidth - _collapsedToolbarSize) / 2,
                  screenHeight - _collapsedToolbarSize - 24,
                );
                _isToolbarPositionInitialized = true;
              });
            }
          });
        }

        return Stack(
          children: [
            Column(
              children: [
                if (_pdfName != null) _buildPdfHeader(),
                Expanded(child: _buildPdfViewer()),
              ],
            ),
            // 플로팅 툴바
            if (_isToolbarPositionInitialized)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: _toolbarPosition.dx,
                top: _toolbarPosition.dy,
                child: _buildDraggableFloatingToolbar(screenWidth, screenHeight),
              ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 56,
              color: _accentColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '도안 PDF 불러오기',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '뜨개질 도안을 불러와서\n형광펜으로 표시하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.folder_open, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'PDF 파일 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pdfName ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$_currentPage / $_totalPages',
            style: TextStyle(
              fontSize: 13,
              color: _accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.folder_open, size: 18, color: _accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (_pageImages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Listener(
      onPointerDown: (_) {
        _pointerCount++;
        if (_pointerCount > 1 && _isDrawing) {
          setState(() {
            if (_pageDrawings[_currentPage]?.isNotEmpty ?? false) {
              _pageDrawings[_currentPage]!.removeLast();
            }
            _isDrawing = false;
          });
        }
      },
      onPointerUp: (_) {
        _pointerCount--;
        if (_pointerCount < 0) _pointerCount = 0;
        if (_pointerCount == 0) _isDrawing = false;
      },
      onPointerCancel: (_) {
        _pointerCount--;
        if (_pointerCount < 0) _pointerCount = 0;
        if (_pointerCount == 0) _isDrawing = false;
      },
      behavior: HitTestBehavior.translucent,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          return _buildPageItem(pageNumber);
        },
      ),
    );
  }

  Widget _buildPageItem(int pageNumber) {
    final pageImage = _pageImages[pageNumber];
    if (pageImage == null || pageImage.width == null || pageImage.height == null) {
      return Container(
        height: 400,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 페이지 번호 표시
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '$pageNumber / $_totalPages',
              style: TextStyle(
                fontSize: 12,
                color: _accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // PDF 페이지와 드로잉 (InteractiveViewer로 줌 가능)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              // 형광펜 모드일 때는 팬 비활성화
              panEnabled: !_isDrawingMode,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 실제 표시되는 크기를 기준으로 pageSize 계산
                  final displayWidth = constraints.maxWidth;
                  final aspectRatio = pageImage.width! / pageImage.height!;
                  final displayHeight = displayWidth / aspectRatio;
                  final displaySize = Size(displayWidth, displayHeight);

                  return Stack(
                    children: [
                      // PDF 페이지 이미지
                      Image.memory(
                        pageImage.bytes,
                        fit: BoxFit.contain,
                        width: displayWidth,
                      ),
                      // 드로잉 표시 레이어
                      Positioned.fill(
                        child: CustomPaint(
                          painter: HighlightPainter(
                            strokes: _pageDrawings[pageNumber] ?? [],
                            pageSize: displaySize,
                          ),
                        ),
                      ),
                      // 드로잉 입력 레이어
                      if (_isDrawingMode)
                        Positioned.fill(
                          child: _buildDrawingInputLayer(pageNumber, displaySize),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingInputLayer(int pageNumber, Size pageSize) {
    return GestureDetector(
      onPanStart: (details) {
        if (_pointerCount == 1) {
          if (_isEraserMode) {
            // 지우개 모드: 터치한 위치의 형광펜 삭제
            _eraseStrokeAtPosition(pageNumber, details.localPosition, pageSize);
          } else {
            setState(() {
              _currentPage = pageNumber;
              _isDrawing = true;
              _pageDrawings.putIfAbsent(pageNumber, () => []);
              final normalizedPoint = Offset(
                details.localPosition.dx / pageSize.width,
                details.localPosition.dy / pageSize.height,
              );
              _pageDrawings[pageNumber]!.add(
                DrawingStroke(
                  color: _highlightColor,
                  strokeWidth: _strokeWidth / pageSize.width * 100,
                  points: [normalizedPoint],
                ),
              );
            });
          }
        }
      },
      onPanUpdate: (details) {
        if (_pointerCount == 1 && _currentPage == pageNumber) {
          if (_isEraserMode) {
            // 지우개 모드: 드래그하면서 지우기
            _eraseStrokeAtPosition(pageNumber, details.localPosition, pageSize);
          } else if (_isDrawing) {
            setState(() {
              if (_pageDrawings[pageNumber]?.isNotEmpty ?? false) {
                final normalizedPoint = Offset(
                  details.localPosition.dx / pageSize.width,
                  details.localPosition.dy / pageSize.height,
                );
                _pageDrawings[pageNumber]!.last.points.add(normalizedPoint);
              }
            });
          }
        }
      },
      onPanEnd: (_) {
        _isDrawing = false;
      },
      onPanCancel: () {
        _isDrawing = false;
      },
      behavior: HitTestBehavior.opaque,
      child: const SizedBox.expand(),
    );
  }

  void _eraseStrokeAtPosition(int pageNumber, Offset position, Size pageSize) {
    final strokes = _pageDrawings[pageNumber];
    if (strokes == null || strokes.isEmpty) return;

    // 정규화된 위치로 변환
    final normalizedPos = Offset(
      position.dx / pageSize.width,
      position.dy / pageSize.height,
    );

    // 터치 반경 (정규화된 값)
    const touchRadius = 0.03;

    // 뒤에서부터 검사 (최근에 그린 것부터)
    for (int i = strokes.length - 1; i >= 0; i--) {
      final stroke = strokes[i];
      for (final point in stroke.points) {
        final distance = (point - normalizedPos).distance;
        // 터치 반경 + 스트로크 두께의 절반 내에 있으면 삭제
        final strokeRadiusNormalized = stroke.strokeWidth / 100 / 2;
        if (distance <= touchRadius + strokeRadiusNormalized) {
          setState(() {
            strokes.removeAt(i);
          });
          return;
        }
      }
    }
  }

  Widget _buildDraggableFloatingToolbar(double screenWidth, double screenHeight) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (!_isToolbarExpanded) {
          setState(() {
            double newX = _toolbarPosition.dx + details.delta.dx;
            double newY = _toolbarPosition.dy + details.delta.dy;

            // 화면 경계 내로 제한
            newX = newX.clamp(0, screenWidth - _collapsedToolbarSize);
            newY = newY.clamp(0, screenHeight - _collapsedToolbarSize);

            _toolbarPosition = Offset(newX, newY);
          });
        }
      },
      child: _buildFloatingToolbar(screenWidth),
    );
  }

  void _expandToolbar(double screenWidth) {
    setState(() {
      // 펼쳤을 때 화면 밖으로 나가는지 확인
      final rightEdge = _toolbarPosition.dx + _expandedToolbarWidth;
      if (rightEdge > screenWidth - 16) {
        // 화면 밖으로 나가면 자동으로 위치 조정
        final newX = screenWidth - _expandedToolbarWidth - 16;
        _toolbarPosition = Offset(newX.clamp(16, screenWidth - _expandedToolbarWidth - 16), _toolbarPosition.dy);
      }
      _isToolbarExpanded = true;
    });
  }

  Widget _buildFloatingToolbar(double screenWidth) {
    final highlightColors = [
      Colors.yellow.withOpacity(0.4),
      Colors.pink.withOpacity(0.4),
      Colors.lightBlue.withOpacity(0.4),
      Colors.lightGreen.withOpacity(0.4),
      Colors.orange.withOpacity(0.4),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: _isToolbarExpanded ? 12 : 0,
        vertical: _isToolbarExpanded ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isToolbarExpanded
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 접기 버튼
                _buildFloatingToolButton(
                  icon: Icons.close,
                  isActive: false,
                  onTap: () {
                    setState(() {
                      _isToolbarExpanded = false;
                      _isEraserMode = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                // 구분선
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
                // 형광펜 색상들
                ...highlightColors.map((color) {
                  final isSelected = _highlightColor.value == color.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _highlightColor = color;
                          _isDrawingMode = true;
                          _isEraserMode = false;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected && _isDrawingMode && !_isEraserMode
                                ? _accentColor
                                : Colors.grey.shade300,
                            width: isSelected && _isDrawingMode && !_isEraserMode ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                // 구분선
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
                // 실행취소
                _buildFloatingToolButton(
                  icon: Icons.undo,
                  isActive: false,
                  onTap: () {
                    setState(() {
                      if (_pageDrawings[_currentPage]?.isNotEmpty ?? false) {
                        _pageDrawings[_currentPage]!.removeLast();
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                // 지우개
                _buildFloatingToolButton(
                  icon: Icons.auto_fix_high,
                  isActive: _isEraserMode,
                  onTap: () {
                    setState(() {
                      _isEraserMode = !_isEraserMode;
                      if (_isEraserMode) {
                        _isDrawingMode = true;
                      }
                    });
                  },
                  onLongPress: () => _showEraserOptionsSheet(),
                ),
              ],
            )
          : GestureDetector(
              onTap: () => _expandToolbar(screenWidth),
              child: Container(
                width: _collapsedToolbarSize,
                height: _collapsedToolbarSize,
                decoration: BoxDecoration(
                  color: _isDrawingMode
                      ? (_isEraserMode ? Colors.red.shade100 : _highlightColor)
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isDrawingMode ? _accentColor : Colors.grey.shade300,
                    width: _isDrawingMode ? 2.5 : 1.5,
                  ),
                ),
                child: Icon(
                  _isEraserMode
                      ? Icons.auto_fix_high
                      : (_isDrawingMode ? Icons.edit : Icons.edit_outlined),
                  color: _isDrawingMode ? _accentColor : Colors.grey.shade500,
                  size: 24,
                ),
              ),
            ),
    );
  }

  Widget _buildFloatingToolButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? _accentColor : Colors.black54,
        ),
      ),
    );
  }

  void _showEraserOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '지우기 옵션',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_fix_high, size: 20),
              ),
              title: const Text('터치하여 지우기'),
              subtitle: Text(
                '형광펜 위를 터치하면 해당 형광펜만 삭제',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              onTap: () {
                setState(() {
                  _isEraserMode = true;
                  _isDrawingMode = true;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cleaning_services_outlined, size: 20),
              ),
              title: const Text('현재 페이지 전체 지우기'),
              onTap: () {
                _clearCurrentPageDrawings();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.red.shade400),
              ),
              title: Text('모든 페이지 지우기', style: TextStyle(color: Colors.red.shade400)),
              onTap: () {
                _clearAllDrawings();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// 드로잉 스트로크 클래스
class DrawingStroke {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  DrawingStroke({
    required this.color,
    required this.strokeWidth,
    required this.points,
  });
}

// 형광펜 페인터
class HighlightPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final Size? pageSize;

  HighlightPainter({required this.strokes, this.pageSize});

  @override
  void paint(Canvas canvas, Size size) {
    // 실제 그릴 크기 (pageSize가 있으면 사용, 없으면 canvas size 사용)
    final drawSize = pageSize ?? size;

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      // 정규화된 두께를 실제 두께로 변환
      final actualStrokeWidth = stroke.strokeWidth * drawSize.width / 100;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = actualStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.multiply;

      final path = Path();
      // 정규화된 좌표를 실제 좌표로 변환
      final firstPoint = Offset(
        stroke.points.first.dx * drawSize.width,
        stroke.points.first.dy * drawSize.height,
      );
      path.moveTo(firstPoint.dx, firstPoint.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final point = Offset(
          stroke.points[i].dx * drawSize.width,
          stroke.points[i].dy * drawSize.height,
        );
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return true;
  }
}
