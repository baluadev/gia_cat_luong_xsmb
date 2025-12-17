import 'dart:io';
import 'dart:math';

/// =======================
/// DATA MODEL
/// =======================
class DataModel {
  final String date;
  final int de;
  final List<int> others;

  DataModel({
    required this.date,
    required this.de,
    required this.others,
  });
}

/// =======================
/// LOAD CSV
/// =======================
Future<List<DataModel>> loadDataModels(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0);

  return lines.map((line) {
    final parts = line.split(',');
    return DataModel(
      date: parts[0],
      de: int.parse(parts[1]),
      others: parts.sublist(2).map(int.parse).toList(),
    );
  }).toList();
}

/// =======================
/// HELPER: TOP N
/// =======================
List<int> topN(Iterable<int> nums, int n) {
  final counter = <int, int>{};
  for (final x in nums) {
    counter[x] = (counter[x] ?? 0) + 1;
  }

  final sorted = counter.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(n).map((e) => e.key).toList();
}

/// =======================
/// MAIN ANALYTIC
/// =======================
Future<void> main() async {
  final data = await loadDataModels('data.csv');

  /// sort tăng dần
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  /// =======================
  /// LỊCH SỬ: DE → OTHERS NGÀY SAU
  /// =======================
  final Map<int, List<int>> deNextOthersHistory = {};

  print('\n=========== DATA ANALYTIC ===========');

  for (int i = 3; i < data.length - 1; i++) {
    final today = data[i];

    /// =======================
    /// A. TOP2 THEO DE (QUÁ KHỨ)
    /// =======================
    final historyOthers = deNextOthersHistory[today.de] ?? [];
    if (historyOthers.isEmpty) {
      /// chưa đủ data → skip analytic
      _updateHistory(deNextOthersHistory, data, i);
      continue;
    }

    final topDe = topN(historyOthers, 2);

    /// =======================
    /// B. TOP2 OTHERS 3 NGÀY TRƯỚC
    /// =======================
    final prev3Others = <int>[];
    for (int k = 1; k <= 3; k++) {
      prev3Others.addAll(data[i - k].others);
    }

    final topPrev3 = topN(prev3Others, 2);

    /// =======================
    /// C. GIAO TỔ HỢP
    /// =======================
    final intersect = topDe.where(topPrev3.contains).toList();

    /// =======================
    /// OUTPUT
    /// =======================
    print(
      '${today.date.split(" ").first} | DE ${today.de.toString().padLeft(2, '0')}'
      '\n  TOP_DE      : ${topDe.map(_fmt).toList()}'
      '\n  TOP_3D_PREV : ${topPrev3.map(_fmt).toList()}'
      '\n  INTERSECT  : ${intersect.map(_fmt).toList()}\n',
    );

    /// =======================
    /// UPDATE HISTORY (SAU ANALYTIC)
    /// =======================
    _updateHistory(deNextOthersHistory, data, i);
  }
}

/// =======================
/// UPDATE HISTORY HELPER
/// =======================
void _updateHistory(
  Map<int, List<int>> history,
  List<DataModel> data,
  int i,
) {
  final today = data[i];
  final tomorrow = data[i + 1];

  history.putIfAbsent(today.de, () => []);
  history[today.de]!.addAll(tomorrow.others);
}

/// =======================
/// FORMAT
/// =======================
String _fmt(int n) => n.toString().padLeft(2, '0');
