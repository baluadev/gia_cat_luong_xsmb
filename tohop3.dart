import 'dart:io';

/// =======================
/// CONFIG
/// =======================
const int COST_PER_POINT = 22500;
const int PROFIT_PER_POINT = 80000;
const int TOP1_POINT = 10;
const int TOP2_POINT = 5;

/// =======================
/// DATA MODEL
/// =======================
class DataModel {
  final DateTime date;
  final int de;
  final List<int> others;

  DataModel(this.date, this.de, this.others);
}

/// =======================
/// DAILY PICK (FREEZE)
/// =======================
class DailyPick {
  final DateTime date;
  final int de;
  final List<int> top; // [top1, top2]

  DailyPick(this.date, this.de, this.top);
}

/// =======================
/// LOAD CSV
/// =======================
Future<List<DataModel>> loadData(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0);

  return lines.map((l) {
    final p = l.split(',');
    return DataModel(
      DateTime.parse(p[0]),
      int.parse(p[1]),
      p.sublist(2).map(int.parse).toList(),
    );
  }).toList();
}

/// =======================
/// BUILD TOP FROM HISTORY
/// =======================
List<int> buildTop(
  List<DataModel> history,
  int de,
) {
  final freq = <int, int>{};

  for (int i = 0; i < history.length - 1; i++) {
    if (history[i].de == de) {
      for (final n in history[i + 1].others) {
        freq[n] = (freq[n] ?? 0) + 1;
      }
    }
  }

  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.map((e) => e.key).take(2).toList();
}

/// =======================
/// TIME KEYS
/// =======================
String weekKey(DateTime d) {
  final monday = d.subtract(Duration(days: d.weekday - 1));
  final firstMonday = DateTime(monday.year, 1, 1)
      .subtract(Duration(days: DateTime(monday.year, 1, 1).weekday - 1));
  final week = monday.difference(firstMonday).inDays ~/ 7 + 1;
  return '${monday.year}-W${week.toString().padLeft(2, '0')}';
}

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  final data = await loadData('data.csv');
  data.sort((a, b) => a.date.compareTo(b.date));

  /// =======================
  /// STEP 1: FREEZE DAILY PICKS
  /// =======================
  final List<DailyPick> picks = [];

  for (int i = 0; i < data.length - 1; i++) {
    final history = data.sublist(0, i + 1);
    final today = data[i];

    final top = buildTop(history, today.de);
    if (top.length == 2) {
      picks.add(DailyPick(today.date, today.de, top));
    }
  }

  /// =======================
  /// STEP 2: BACKTEST
  /// =======================
  final profitByWeek = <String, int>{};
  final daysByWeek = <String, int>{};

  print('\n=========== 10 NGÀY GẦN NHẤT ===========');

  for (final pick in picks) {
    final idx = data.indexWhere((d) => d.date == pick.date);
    if (idx == -1 || idx + 1 >= data.length) continue;

    final tomorrow = data[idx + 1];

    final hit1 = tomorrow.others.contains(pick.top[0]);
    final hit2 = tomorrow.others.contains(pick.top[1]);

    int profit = 0;

// TOP1
    profit += (hit1 ? TOP1_POINT * PROFIT_PER_POINT : 0) -
        TOP1_POINT * COST_PER_POINT;

// TOP2
    profit += (hit2 ? TOP2_POINT * PROFIT_PER_POINT : 0) -
        TOP2_POINT * COST_PER_POINT;

    final wk = weekKey(pick.date);

    profitByWeek[wk] = (profitByWeek[wk] ?? 0) + profit;
    daysByWeek[wk] = (daysByWeek[wk] ?? 0) + 1;

    // Print last 10 days
    if (picks.length - picks.indexOf(pick) <= 10) {
      print('${pick.date.toIso8601String().split("T").first}'
          ' | DE ${pick.de}'
          ' | TOP ${pick.top}'
          ' | HIT ${(hit1 ? "✔" : "✘")}/${(hit2 ? "✔" : "✘")}'
          ' | Profit $profit');
    }
  }

  /// =======================
  /// OUTPUT WEEK
  /// =======================
  print('\n=========== PROFIT THEO TUẦN ===========');
  final newL = profitByWeek.keys.toList()..sort();
  for (final w in newL.sublist(newL.length-10, newL.length-1)) {
    final p = profitByWeek[w]!;
    final d = daysByWeek[w]!;
    print('$w | Profit: $p | Days: $d | TB/ngày: ${(p / d).round()}');
  }

  /// =======================
  /// TOMORROW SUGGESTION
  /// =======================
  final latest = data.last;
  final topTomorrow = buildTop(data, latest.de);

  print('\n=========== GỢI Ý NGÀY MAI ===========');
  print('DE HÔM NAY: ${latest.de}');
  print('TOP1,2: $topTomorrow');
}
