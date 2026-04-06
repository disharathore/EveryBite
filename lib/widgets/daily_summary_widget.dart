import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:everybite/services/scan_history_service.dart';
import 'package:everybite/historypage.dart';

class DailySummaryWidget extends StatefulWidget {
  const DailySummaryWidget({super.key});

  @override
  State<DailySummaryWidget> createState() => DailySummaryWidgetState();
}

class DailySummaryWidgetState extends State<DailySummaryWidget> {
  Map<String, double> _totals = {
    'sugar': 0,
    'proteins': 0,
    'fats': 0,
    'sodium': 0,
  };
  int _scanCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final totals = await ScanHistoryService.instance.getTodayTotals();
    final todayScans = await ScanHistoryService.instance.getTodayScans();
    setState(() {
      _totals = totals;
      _scanCount = todayScans.length;
      _isLoading = false;
    });
  }

  // Call this from homepage after a new scan
  void refresh() {
    setState(() => _isLoading = true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final proteins = _totals['proteins'] ?? 0;
    final fats = _totals['fats'] ?? 0;
    final sugar = _totals['sugar'] ?? 0;

    final total = proteins + fats + sugar;
    final hasMacros = total > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.today, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                const Text(
                  "Today's Nutrition",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HistoryPage()),
                    ).then((_) => refresh());
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '$_scanCount scan${_scanCount == 1 ? '' : 's'}  →',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          if (!hasMacros)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner,
                      color: Colors.grey[300], size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Scan your first product today\nto see your nutrition summary',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Row(
                children: [
                  // Pie chart
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: PieChart(
                      dataMap: {
                        'Protein': proteins,
                        'Fats': fats,
                        'Sugar': sugar,
                      },
                      colorList: const [
                        Color(0xFF66BB6A),
                        Color(0xFFEF5350),
                        Color(0xFFFFCA28),
                      ],
                      chartRadius: 50,
                      chartValuesOptions: const ChartValuesOptions(
                        showChartValues: false,
                      ),
                      legendOptions: const LegendOptions(
                        showLegends: false,
                      ),
                      ringStrokeWidth: 14,
                      chartType: ChartType.ring,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Macro stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _macroRow('Protein',
                            '${proteins.toStringAsFixed(1)}g',
                            const Color(0xFF66BB6A)),
                        const SizedBox(height: 6),
                        _macroRow(
                            'Fats',
                            '${fats.toStringAsFixed(1)}g',
                            const Color(0xFFEF5350)),
                        const SizedBox(height: 6),
                        _macroRow(
                            'Sugar',
                            '${sugar.toStringAsFixed(1)}g',
                            const Color(0xFFFFCA28)),
                        const SizedBox(height: 6),
                        _macroRow(
                          'Sodium',
                          '${(_totals['sodium'] ?? 0).toStringAsFixed(2)}g',
                          Colors.blueGrey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}