import 'dart:ui';
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

  // 펜/형광펜 관련
  bool _isDrawingMode = false;
  bool _isHighlighterMode = true; // true: 형광펜, false: 일반펜
  Color _penColor = Colors.yellow; // 공용 색상 (투명도 없음)
  double _penStrokeWidth = 3.0; // 일반펜 두께
  double _highlighterStrokeWidth = 20.0; // 형광펜 두께
  bool _showPenThicknessPopup = false;
  bool _showHighlighterThicknessPopup = false;

  // 두께 옵션
  static const List<double> _penThicknessOptions = [1.0, 2.0, 3.0, 5.0, 8.0];
  static const List<double> _highlighterThicknessOptions = [10.0, 15.0, 20.0, 30.0, 40.0];

  // HSV 색상 값 (색상선택 그래디언트용)
  double _hue = 60; // 노란색 기본
  double _saturation = 1.0;
  double _value = 1.0;

  // 페이지별 드로잉 데이터
  final Map<int, List<DrawingStroke>> _pageDrawings = {};
  int _currentPage = 1;
  int _totalPages = 0;

  // 멀티터치 감지용
  int _pointerCount = 0;
  bool _isDrawing = false;

  // 플로팅 툴바 관련
  bool _isEditModeEnabled = false; // 편집 모드 (상단바 연필 버튼으로 제어)
  bool _isToolbarExpanded = false;
  bool _isEraserMode = false;
  Offset _toolbarPosition = const Offset(0, 0); // 초기 위치 (나중에 설정)
  bool _isToolbarPositionInitialized = false;
  static const double _collapsedToolbarSize = 56.0;
  static const double _expandedToolbarWidth = 280.0; // 펼쳐진 툴바 너비 (줄임)

  // 전체 줌 관련
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  // 스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();

  // 디자인 색상
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _accentColor = Color(0xFF6B7280);

  @override
  void dispose() {
    _scrollController.dispose();
    _transformationController.dispose();
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
            // 플로팅 툴바 (편집 모드 활성화 시에만 표시)
            if (_isEditModeEnabled && _isToolbarPositionInitialized)
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
    final hasDrawings = _pageDrawings[_currentPage]?.isNotEmpty ?? false;

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
          // 폴더 열기 버튼
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
          const SizedBox(width: 8),
          // 실행취소 버튼
          GestureDetector(
            onTap: hasDrawings ? () {
              setState(() {
                _pageDrawings[_currentPage]?.removeLast();
              });
            } : null,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hasDrawings
                    ? _accentColor.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.undo,
                size: 18,
                color: hasDrawings ? _accentColor : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 연필 모드 활성화/비활성화 버튼
          GestureDetector(
            onTap: () {
              setState(() {
                _isEditModeEnabled = !_isEditModeEnabled;
                if (!_isEditModeEnabled) {
                  // 편집 모드 비활성화 시 초기화
                  _isDrawingMode = false;
                  _isEraserMode = false;
                  _isToolbarExpanded = false;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isEditModeEnabled
                    ? _accentColor
                    : _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isEditModeEnabled ? Icons.edit : Icons.edit_outlined,
                size: 18,
                color: _isEditModeEnabled ? Colors.white : _accentColor,
              ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            minScale: 1.0,
            maxScale: 4.0,
            panEnabled: !_isDrawingMode,
            scaleEnabled: true,
            boundaryMargin: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth * 0.5,
              vertical: constraints.maxHeight * 0.5,
            ),
            onInteractionEnd: (details) {
              setState(() {
                _currentScale = _transformationController.value.getMaxScaleOnAxis();
              });
            },
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ...List.generate(_totalPages, (index) {
                    final pageNumber = index + 1;
                    return _buildPageItem(pageNumber);
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
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

    // 드로잉 영역 확장 패딩 (페이지 외부에서도 터치 시작 가능하도록)
    const double drawingPadding = 150.0;

    return Container(
      // 확장된 드로잉 영역을 고려하여 음수 마진 적용
      margin: EdgeInsets.symmetric(
        horizontal: 16 - drawingPadding,
        vertical: 8 - drawingPadding,
      ),
      child: Column(
        children: [
          // 페이지 번호 표시 (패딩만큼 들여쓰기)
          Container(
            margin: EdgeInsets.only(left: drawingPadding, right: drawingPadding, top: drawingPadding),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$pageNumber / $_totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // PDF 페이지와 드로잉 (줌은 상위 InteractiveViewer에서 처리)
          LayoutBuilder(
            builder: (context, constraints) {
              // 확장된 영역에서 실제 PDF 표시 영역 계산
              final displayWidth = constraints.maxWidth - drawingPadding * 2;
              final aspectRatio = pageImage.width! / pageImage.height!;
              final displayHeight = displayWidth / aspectRatio;
              final displaySize = Size(displayWidth, displayHeight);

              // Stack 크기를 확장하여 터치 영역 확보
              return SizedBox(
                width: constraints.maxWidth,
                height: displayHeight + drawingPadding * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // PDF 페이지 이미지 (중앙에 배치) + 배경
                    Positioned(
                      left: drawingPadding,
                      top: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          child: Image.memory(
                            pageImage.bytes,
                            fit: BoxFit.contain,
                            width: displayWidth,
                          ),
                        ),
                      ),
                    ),
                    // 드로잉 표시 레이어 (전체 영역)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: HighlightPainter(
                          strokes: _pageDrawings[pageNumber] ?? [],
                          pageSize: displaySize,
                          drawingPadding: drawingPadding,
                        ),
                      ),
                    ),
                    // 드로잉 입력 레이어 (전체 영역)
                    if (_isDrawingMode)
                      Positioned.fill(
                        child: _buildDrawingInputLayer(
                          pageNumber,
                          displaySize,
                          drawingPadding: drawingPadding,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingInputLayer(int pageNumber, Size pageSize, {double drawingPadding = 0}) {
    // 현재 모드에 맞는 두께 선택
    final currentStrokeWidth = _isHighlighterMode
        ? _highlighterStrokeWidth
        : _penStrokeWidth;

    return GestureDetector(
      onPanStart: (details) {
        if (_pointerCount == 1) {
          // 패딩을 고려한 좌표 계산
          final adjustedPosition = Offset(
            details.localPosition.dx - drawingPadding,
            details.localPosition.dy - drawingPadding,
          );

          if (_isEraserMode) {
            // 지우개 모드: 터치한 위치의 펜/형광펜 삭제
            _eraseStrokeAtPosition(pageNumber, adjustedPosition, pageSize);
          } else {
            setState(() {
              _currentPage = pageNumber;
              _isDrawing = true;
              _pageDrawings.putIfAbsent(pageNumber, () => []);
              // 정규화된 좌표 (0~1 범위를 벗어날 수 있음)
              final normalizedPoint = Offset(
                adjustedPosition.dx / pageSize.width,
                adjustedPosition.dy / pageSize.height,
              );
              _pageDrawings[pageNumber]!.add(
                DrawingStroke(
                  color: _penColor, // 투명도 없는 색상 저장
                  strokeWidth: currentStrokeWidth / pageSize.width * 100,
                  points: [normalizedPoint],
                  isHighlighter: _isHighlighterMode,
                ),
              );
            });
          }
        }
      },
      onPanUpdate: (details) {
        if (_pointerCount == 1 && _currentPage == pageNumber) {
          // 패딩을 고려한 좌표 계산
          final adjustedPosition = Offset(
            details.localPosition.dx - drawingPadding,
            details.localPosition.dy - drawingPadding,
          );

          if (_isEraserMode) {
            // 지우개 모드: 드래그하면서 지우기
            _eraseStrokeAtPosition(pageNumber, adjustedPosition, pageSize);
          } else if (_isDrawing) {
            setState(() {
              if (_pageDrawings[pageNumber]?.isNotEmpty ?? false) {
                final normalizedPoint = Offset(
                  adjustedPosition.dx / pageSize.width,
                  adjustedPosition.dy / pageSize.height,
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
        } else {
          // 펼쳐진 상태에서 드래그하면 접기
          setState(() {
            _isToolbarExpanded = false;
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
    final isPenActive = _isDrawingMode && !_isHighlighterMode && !_isEraserMode;
    final isHighlighterActive = _isDrawingMode && _isHighlighterMode && !_isEraserMode;
    final isYellowSelected = _penColor.value == Colors.yellow.value;

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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 두께 팝오버 (펜)
                if (_showPenThicknessPopup)
                  _buildThicknessPopup(
                    thicknesses: _penThicknessOptions,
                    currentThickness: _penStrokeWidth,
                    isHighlighter: false,
                    onSelect: (thickness) {
                      setState(() {
                        _penStrokeWidth = thickness;
                        _showPenThicknessPopup = false;
                        _isHighlighterMode = false;
                        _isDrawingMode = true;
                        _isEraserMode = false;
                      });
                    },
                  ),
                // 두께 팝오버 (형광펜)
                if (_showHighlighterThicknessPopup)
                  _buildThicknessPopup(
                    thicknesses: _highlighterThicknessOptions,
                    currentThickness: _highlighterStrokeWidth,
                    isHighlighter: true,
                    onSelect: (thickness) {
                      setState(() {
                        _highlighterStrokeWidth = thickness;
                        _showHighlighterThicknessPopup = false;
                        _isHighlighterMode = true;
                        _isDrawingMode = true;
                        _isEraserMode = false;
                      });
                    },
                  ),
                // 메인 툴바
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 일반 펜
                    _buildPenButton(
                      icon: Icons.edit,
                      isActive: isPenActive,
                      color: isPenActive ? _penColor : null,
                      onTap: () {
                        setState(() {
                          if (isPenActive) {
                            // 이미 활성화된 상태면 두께 팝업 토글
                            _showPenThicknessPopup = !_showPenThicknessPopup;
                            _showHighlighterThicknessPopup = false;
                          } else {
                            // 펜 모드 활성화
                            _isHighlighterMode = false;
                            _isDrawingMode = true;
                            _isEraserMode = false;
                            _showPenThicknessPopup = true;
                            _showHighlighterThicknessPopup = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    // 형광펜
                    _buildPenButton(
                      icon: Icons.brush,
                      isActive: isHighlighterActive,
                      color: isHighlighterActive ? _penColor.withOpacity(0.4) : null,
                      onTap: () {
                        setState(() {
                          if (isHighlighterActive) {
                            // 이미 활성화된 상태면 두께 팝업 토글
                            _showHighlighterThicknessPopup = !_showHighlighterThicknessPopup;
                            _showPenThicknessPopup = false;
                          } else {
                            // 형광펜 모드 활성화
                            _isHighlighterMode = true;
                            _isDrawingMode = true;
                            _isEraserMode = false;
                            _showHighlighterThicknessPopup = true;
                            _showPenThicknessPopup = false;
                          }
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
                    // 노란색 색상
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _penColor = Colors.yellow;
                          _showPenThicknessPopup = false;
                          _showHighlighterThicknessPopup = false;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isYellowSelected ? _accentColor : Colors.grey.shade300,
                            width: isYellowSelected ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 색상 선택 그래디언트
                    GestureDetector(
                      onTap: () {
                        _showPenThicknessPopup = false;
                        _showHighlighterThicknessPopup = false;
                        _showColorPickerPopup();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
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
                          border: Border.all(
                            color: !isYellowSelected ? _accentColor : Colors.grey.shade300,
                            width: !isYellowSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: !isYellowSelected
                            ? Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _penColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          _showPenThicknessPopup = false;
                          _showHighlighterThicknessPopup = false;
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
                          _showPenThicknessPopup = false;
                          _showHighlighterThicknessPopup = false;
                        });
                      },
                      onLongPress: () => _showEraserOptionsSheet(),
                    ),
                  ],
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
                      ? (_isEraserMode
                          ? Colors.red.shade100
                          : (_isHighlighterMode
                              ? _penColor.withOpacity(0.4)
                              : _penColor))
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
                      : (_isHighlighterMode ? Icons.brush : Icons.edit),
                  color: _isDrawingMode ? _accentColor : Colors.grey.shade500,
                  size: 24,
                ),
              ),
            ),
    );
  }

  Widget _buildPenButton({
    required IconData icon,
    required bool isActive,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? (color ?? _accentColor.withOpacity(0.15))
              : Colors.transparent,
          shape: BoxShape.circle,
          border: isActive
              ? Border.all(color: _accentColor, width: 2)
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? _accentColor : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildThicknessPopup({
    required List<double> thicknesses,
    required double currentThickness,
    required bool isHighlighter,
    required Function(double) onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: thicknesses.map((thickness) {
          final isSelected = currentThickness == thickness;
          final displaySize = isHighlighter
              ? (thickness / 40 * 24).clamp(8.0, 24.0)
              : (thickness / 8 * 16).clamp(4.0, 16.0);

          return GestureDetector(
            onTap: () => onSelect(thickness),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? _accentColor.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: _accentColor, width: 2)
                    : null,
              ),
              child: Center(
                child: Container(
                  width: displaySize,
                  height: displaySize,
                  decoration: BoxDecoration(
                    color: isHighlighter
                        ? _penColor.withOpacity(0.4)
                        : _penColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showColorPickerPopup() {
    // 현재 색상에서 HSV 값 추출
    final hsv = HSVColor.fromColor(_penColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;

    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialHue: _hue,
        initialSaturation: _saturation,
        initialValue: _value,
        onColorSelected: (color) {
          setState(() {
            _penColor = color; // 투명도 없이 저장
            final hsv = HSVColor.fromColor(color);
            _hue = hsv.hue;
            _saturation = hsv.saturation;
            _value = hsv.value;
          });
        },
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
  final bool isHighlighter; // true: 형광펜, false: 일반펜

  DrawingStroke({
    required this.color,
    required this.strokeWidth,
    required this.points,
    this.isHighlighter = true,
  });
}

// 펜/형광펜 페인터
class HighlightPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final Size? pageSize;
  final double drawingPadding;

  HighlightPainter({
    required this.strokes,
    this.pageSize,
    this.drawingPadding = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 실제 그릴 크기 (pageSize가 있으면 사용, 없으면 canvas size 사용)
    final drawSize = pageSize ?? size;

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      // 정규화된 두께를 실제 두께로 변환
      final actualStrokeWidth = stroke.strokeWidth * drawSize.width / 100;

      final paint = Paint()
        ..strokeWidth = actualStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // 펜 타입에 따라 다른 렌더링
      if (stroke.isHighlighter) {
        // 형광펜: 반투명 + multiply 블렌드
        paint.color = stroke.color.withOpacity(0.4);
        paint.blendMode = BlendMode.multiply;
      } else {
        // 일반펜: 불투명
        paint.color = stroke.color;
        paint.blendMode = BlendMode.srcOver;
      }

      final path = Path();
      // 정규화된 좌표를 실제 좌표로 변환 (패딩 고려)
      final firstPoint = Offset(
        stroke.points.first.dx * drawSize.width + drawingPadding,
        stroke.points.first.dy * drawSize.height + drawingPadding,
      );
      path.moveTo(firstPoint.dx, firstPoint.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final point = Offset(
          stroke.points[i].dx * drawSize.width + drawingPadding,
          stroke.points[i].dy * drawSize.height + drawingPadding,
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

// 색상 선택 다이얼로그
class _ColorPickerDialog extends StatefulWidget {
  final double initialHue;
  final double initialSaturation;
  final double initialValue;
  final Function(Color) onColorSelected;

  const _ColorPickerDialog({
    required this.initialHue,
    required this.initialSaturation,
    required this.initialValue,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late Color _selectedColor;

  static const Color _accentColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _hue = widget.initialHue;
    _saturation = widget.initialSaturation;
    _value = widget.initialValue;
    _updateColor();
  }

  void _updateColor() {
    _selectedColor = HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();
  }

  void _updateFromPosition(double dx, double dy, double width, double height) {
    setState(() {
      _saturation = (dx / width).clamp(0.0, 1.0);
      _value = (1 - dy / height).clamp(0.0, 1.0);
      _updateColor();
    });
  }

  void _updateHue(double dy, double height) {
    setState(() {
      _hue = (dy / height * 360).clamp(0.0, 360.0);
      _updateColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '형광펜 색상',
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
                const SizedBox(height: 20),
                // 색상 미리보기
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 색상 선택 영역
                Row(
                  children: [
                    // Saturation-Value 그리드
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          const height = 180.0;
                          return GestureDetector(
                            onPanDown: (details) {
                              _updateFromPosition(
                                details.localPosition.dx,
                                details.localPosition.dy,
                                width,
                                height,
                              );
                            },
                            onPanUpdate: (details) {
                              _updateFromPosition(
                                details.localPosition.dx,
                                details.localPosition.dy,
                                width,
                                height,
                              );
                            },
                            child: Container(
                              height: height,
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
                                      left: ((_saturation * width) - 10).clamp(0.0, width - 20),
                                      top: (((1 - _value) * height) - 10).clamp(0.0, height - 20),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _selectedColor,
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hue 바 (세로)
                    GestureDetector(
                      onPanDown: (details) {
                        _updateHue(details.localPosition.dy, 180);
                      },
                      onPanUpdate: (details) {
                        _updateHue(details.localPosition.dy, 180);
                      },
                      child: Container(
                        width: 24,
                        height: 180,
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
                              left: 0,
                              right: 0,
                              top: (((_hue / 360) * 180) - 3).clamp(0.0, 180 - 6),
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
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
                // 선택 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onColorSelected(_selectedColor);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
