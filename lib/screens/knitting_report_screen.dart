import 'package:flutter/material.dart';
import '../models/stitch.dart';
import '../widgets/stitch_pad.dart';

class KnittingReportScreen extends StatefulWidget {
  const KnittingReportScreen({super.key});

  @override
  State<KnittingReportScreen> createState() => _KnittingReportScreenState();
}

class _KnittingReportScreenState extends State<KnittingReportScreen> {
  final List<List<Stitch>> _rows = [[]];
  int _currentRowIndex = 0;

  void _addStitch(StitchType type) {
    setState(() {
      _rows[_currentRowIndex].add(Stitch(type));
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._rows.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      return _buildRow(index, row);
                    }),
                  ],
                ),
              ),
            ),
            StitchPad(
              onStitchTap: _addStitch,
              onAddRow: _addRow,
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

  Widget _buildRow(int index, List<Stitch> row) {
    final isCurrentRow = index == _currentRowIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRowIndex = index;
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
                  'row ${index + 1}',
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
              ],
            ),
            const SizedBox(height: 8),
            if (row.isEmpty)
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrentRow
                      ? Border.all(color: const Color(0xFFFFB6C1), width: 2)
                      : null,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrentRow
                      ? Border.all(color: const Color(0xFFFFB6C1), width: 2)
                      : null,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: row.reversed.map((stitch) {
                    return _buildStitchCell(stitch);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStitchCell(Stitch stitch) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            stitch.abbreviation,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            stitch.koreanName,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
