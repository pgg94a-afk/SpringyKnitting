import 'package:flutter/gestures.dart';
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

class PatternPdfScreenState extends State<PatternPdfScreen> {
  PdfControllerPinch? _pdfController;
  String? _pdfPath;
  String? _pdfName;
  bool _isLoading = false;

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
    return Stack(
      children: [
        // PDF 뷰어 (줌/스크롤 처리)
        Listener(
          onPointerDown: (_) => _pointerCount++,
          onPointerUp: (_) {
            _pointerCount--;
            if (_pointerCount < 0) _pointerCount = 0;
            _isDrawing = false;
          },
          onPointerCancel: (_) {
            _pointerCount--;
            if (_pointerCount < 0) _pointerCount = 0;
            _isDrawing = false;
          },
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
            ),
          ),
        ),
        // 드로잉 표시 레이어 (터치 이벤트 무시)
        if (_isDrawingMode) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: HighlightPainter(
                  strokes: _pageDrawings[_currentPage] ?? [],
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // 드로잉 입력 레이어 (한 손가락만 처리)
          Positioned.fill(
            child: _buildDrawingInputLayer(),
          ),
        ],
      ],
    );
  }

  Widget _buildDrawingInputLayer() {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _SingleFingerPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_SingleFingerPanGestureRecognizer>(
          () => _SingleFingerPanGestureRecognizer(
            getPointerCount: () => _pointerCount,
          ),
          (_SingleFingerPanGestureRecognizer instance) {
            instance
              ..onStart = (details) {
                if (_pointerCount == 1) {
                  setState(() {
                    _isDrawing = true;
                    _pageDrawings.putIfAbsent(_currentPage, () => []);
                    _pageDrawings[_currentPage]!.add(
                      DrawingStroke(
                        color: _highlightColor,
                        strokeWidth: _strokeWidth,
                        points: [details.localPosition],
                      ),
                    );
                  });
                }
              }
              ..onUpdate = (details) {
                if (_pointerCount == 1 && _isDrawing) {
                  setState(() {
                    if (_pageDrawings[_currentPage]?.isNotEmpty ?? false) {
                      _pageDrawings[_currentPage]!.last.points.add(details.localPosition);
                    }
                  });
                } else if (_pointerCount > 1 && _isDrawing) {
                  // 두 손가락 감지: 현재 획 취소
                  setState(() {
                    if (_pageDrawings[_currentPage]?.isNotEmpty ?? false) {
                      _pageDrawings[_currentPage]!.removeLast();
                    }
                    _isDrawing = false;
                  });
                }
              }
              ..onEnd = (_) {
                _isDrawing = false;
              }
              ..onCancel = () {
                _isDrawing = false;
              };
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
      child: const SizedBox.expand(),
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

  HighlightPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.multiply;

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return true;
  }
}

// 한 손가락 팬 제스처만 인식하는 커스텀 GestureRecognizer
class _SingleFingerPanGestureRecognizer extends PanGestureRecognizer {
  final int Function() getPointerCount;

  _SingleFingerPanGestureRecognizer({required this.getPointerCount});

  @override
  void addPointer(PointerDownEvent event) {
    // 한 손가락일 때만 제스처 인식 시작
    if (getPointerCount() <= 1) {
      super.addPointer(event);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    // 두 손가락 이상이면 제스처 거부
    if (getPointerCount() > 1) {
      resolve(GestureDisposition.rejected);
      return;
    }
    super.handleEvent(event);
  }
}
