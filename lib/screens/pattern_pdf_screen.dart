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
  PdfControllerPinch? _pdfController;
  String? _pdfPath;
  String? _pdfName;
  bool _isLoading = false;

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

  // 디자인 색상
  static const Color _glassBackground = Color(0xFFF1F0EF);
  static const Color _accentColor = Color(0xFF6B7280);

  @override
  void dispose() {
    _pdfController?.dispose();
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
        });

        final document = await PdfDocument.openFile(_pdfPath!);

        setState(() {
          _totalPages = document.pagesCount;
          _pdfController?.dispose();
          _pdfController = PdfControllerPinch(
            document: Future.value(document),
          );
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
    if (_pdfController == null) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        Column(
          children: [
            if (_pdfName != null) _buildPdfHeader(),
            Expanded(child: _buildPdfViewer()),
            _buildBottomToolbar(),
          ],
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
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
    return Listener(
      // 최상위에서 포인터 카운트 추적
      onPointerDown: (_) {
        _pointerCount++;
        // 두 손가락 이상이면 진행 중인 드로잉 취소
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
      child: PdfViewPinch(
        controller: _pdfController!,
        onPageChanged: (page) {
          setState(() => _currentPage = page);
        },
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (_, error) => Center(
            child: Text('오류: $error'),
          ),
          // 페이지 빌더: PDF 페이지 위에 드로잉 오버레이 추가
          pageBuilder: (context, pageImage, pageNumber, document) {
            return Stack(
              children: [
                // PDF 페이지 이미지
                Image.memory(
                  pageImage.bytes,
                  fit: BoxFit.contain,
                  width: pageImage.width.toDouble(),
                  height: pageImage.height.toDouble(),
                ),
                // 드로잉 표시 레이어 (페이지와 함께 변환됨)
                Positioned.fill(
                  child: CustomPaint(
                    painter: HighlightPainter(
                      strokes: _pageDrawings[pageNumber] ?? [],
                      pageSize: Size(
                        pageImage.width.toDouble(),
                        pageImage.height.toDouble(),
                      ),
                    ),
                    size: Size(
                      pageImage.width.toDouble(),
                      pageImage.height.toDouble(),
                    ),
                  ),
                ),
                // 드로잉 입력 레이어 (형광펜 모드일 때만)
                if (_isDrawingMode && pageNumber == _currentPage)
                  Positioned.fill(
                    child: _buildDrawingInputLayer(
                      Size(
                        pageImage.width.toDouble(),
                        pageImage.height.toDouble(),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawingInputLayer(Size pageSize) {
    return Listener(
      onPointerMove: (event) {
        // 한 손가락이고 드로잉 중일 때만 포인트 추가
        if (_pointerCount == 1 && _isDrawing) {
          setState(() {
            if (_pageDrawings[_currentPage]?.isNotEmpty ?? false) {
              // 정규화된 좌표로 저장 (0~1 범위)
              final normalizedPoint = Offset(
                event.localPosition.dx / pageSize.width,
                event.localPosition.dy / pageSize.height,
              );
              _pageDrawings[_currentPage]!.last.points.add(normalizedPoint);
            }
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: GestureDetector(
        onPanStart: (details) {
          // 한 손가락일 때만 드로잉 시작
          if (_pointerCount == 1) {
            setState(() {
              _isDrawing = true;
              _pageDrawings.putIfAbsent(_currentPage, () => []);
              // 정규화된 좌표로 저장 (0~1 범위)
              final normalizedPoint = Offset(
                details.localPosition.dx / pageSize.width,
                details.localPosition.dy / pageSize.height,
              );
              _pageDrawings[_currentPage]!.add(
                DrawingStroke(
                  color: _highlightColor,
                  strokeWidth: _strokeWidth / pageSize.width * 100, // 상대적 두께
                  points: [normalizedPoint],
                ),
              );
            });
          }
        },
        onPanEnd: (_) {
          _isDrawing = false;
        },
        onPanCancel: () {
          _isDrawing = false;
        },
        behavior: HitTestBehavior.translucent,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolButton(
            icon: _isDrawingMode ? Icons.edit : Icons.edit_outlined,
            label: '형광펜',
            isActive: _isDrawingMode,
            onTap: _toggleDrawingMode,
          ),
          _buildToolButton(
            icon: Icons.palette_outlined,
            label: '색상',
            onTap: _showColorPicker,
            activeColor: _highlightColor.withOpacity(1),
          ),
          _buildToolButton(
            icon: Icons.undo,
            label: '실행취소',
            onTap: () {
              setState(() {
                if (_pageDrawings[_currentPage]?.isNotEmpty ?? false) {
                  _pageDrawings[_currentPage]!.removeLast();
                }
              });
            },
          ),
          _buildToolButton(
            icon: Icons.cleaning_services_outlined,
            label: '지우기',
            onTap: () => _showClearOptionsSheet(),
          ),
        ],
      ),
    );
  }

  void _showClearOptionsSheet() {
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
          children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('현재 페이지 지우기'),
              onTap: () {
                _clearCurrentPageDrawings();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined, color: Colors.red.shade400),
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

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: activeColor ?? (isActive ? _accentColor : Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? _accentColor : Colors.black54,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
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
