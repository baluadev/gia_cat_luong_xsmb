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

class RoiStat {
  int hit = 0;
  int total = 0;
  int profit = 0;

  double get winrate => total == 0 ? 0 : hit / total * 100;
  double get roiPerTurn => total == 0 ? 0 : profit / total;
}

/// =======================
/// LOAD CSV (NO PACKAGE)
/// =======================
Future<List<DataModel>> loadDataModels(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0); // remove header

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
/// POWER SCORE
/// =======================
extension RoiPower on RoiStat {
  double powerScore(int cost) {
    if (total == 0) return 0;

    final winrateScore = (winrate - 35) * 1.5; // >35% mới có lợi
    final roiScore = roiPerTurn / cost;
    final stabilityScore = log(total);

    return winrateScore + roiScore + stabilityScore;
  }
}

/// =======================
/// CONFIG
/// =======================
///
///
const int POINT_PER_NUMBER = 5;
const int COST = POINT_PER_NUMBER * 3 * 22500;
const int PROFIT_PER_HIT =
    (POINT_PER_NUMBER * 80000) - (POINT_PER_NUMBER * 3 * 22500);

const double MIN_WINRATE = 85.0;
const int MIN_TOTAL = 10;

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  // =======================
  // LOAD + SORT
  // =======================
  final data = await loadDataModels('data.csv');
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  // =======================
  // MAP: DE -> OTHER NGÀY MAI
  // =======================
  final Map<int, List<int>> nextDayStats = {};

  for (int i = 0; i < data.length - 1; i++) {
    final deToday = data[i].de;
    nextDayStats.putIfAbsent(deToday, () => []);
    nextDayStats[deToday]!.addAll(data[i + 1].others);
  }

  // =======================
  // TOP 3 BY DE
  // =======================
  final Map<int, List<int>> top3ByDe = {};

  nextDayStats.forEach((de, nums) {
    final Map<int, int> counter = {};
    for (final n in nums) {
      counter[n] = (counter[n] ?? 0) + 1;
    }

    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    top3ByDe[de] = sorted.take(3).map((e) => e.key).toList();
  });

  // =======================
  // ROI: HIT + TOTAL
  // =======================
  final Map<int, RoiStat> roiStats = {};

  for (int i = 0; i < data.length - 1; i++) {
    final deToday = data[i].de;
    final top3 = top3ByDe[deToday];
    if (top3 == null) continue;

    final hit = top3.any(data[i + 1].others.contains);

    roiStats.putIfAbsent(deToday, () => RoiStat());
    final s = roiStats[deToday]!;

    s.total++;
    if (hit) s.hit++;
  }

  // =======================
  // TÍNH PROFIT (CHUẨN)
  // =======================
  roiStats.forEach((_, s) {
    final miss = s.total - s.hit;
    s.profit = s.hit * PROFIT_PER_HIT - miss * COST;
  });

  // =======================
  // CHECK DE ĐÁNG ĐÁNH
  // =======================
  bool isGoodDe(RoiStat s) {
    return s.total >= MIN_TOTAL && s.winrate >= MIN_WINRATE && s.profit > 0;
  }

  // =======================
  // TOP DE MẠNH NHẤT
  // =======================
  final strongDes = roiStats.entries.where((e) => isGoodDe(e.value)).toList();

  strongDes.sort(
    (a, b) => b.value.powerScore(COST).compareTo(
          a.value.powerScore(COST),
        ),
  );
  int index = 0;
  print('\n========= TOP DE MẠNH NHẤT =========');
  for (final e in strongDes.take(25)) {
    final de = e.key;
    final s = e.value;
    print(
      '${index++}.DE $de | '
      'Hit ${s.hit}/${s.total} | '
      'Winrate ${s.winrate.toStringAsFixed(2)}% | '
      'Profit ${s.profit} | '
      'ROI/lần ${s.roiPerTurn.toStringAsFixed(0)} | '
      'Power ${s.powerScore(COST).toStringAsFixed(2)}',
    );
  }

  // =======================
  // DỰ ĐOÁN NGÀY MAI
  // =======================
  final latestDe = data.last.de;
  final predTop3 = top3ByDe[latestDe] ?? [];

  print('\n===================================================');
  print('DE NGÀY GẦN NHẤT: $latestDe');
  print('→ TOP 3 DỰ ĐOÁN: $predTop3');

  if (roiStats.containsKey(latestDe)) {
    final s = roiStats[latestDe]!;
    print(
      'Hit ${s.hit}/${s.total} | '
      'Winrate ${s.winrate.toStringAsFixed(2)}% | '
      'Profit ${s.profit} | '
      'ROI/lần ${s.roiPerTurn.toStringAsFixed(0)}',
    );
    print(isGoodDe(s) ? '✅ DE NÀY ĐÁNG ĐÁNH' : '❌ DE NÀY KHÔNG NÊN ĐÁNH');
  } else {
    print('Chưa có dữ liệu lịch sử cho DE này');
  }

  print('===================================================');
}
