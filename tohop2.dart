import 'dart:io';
import 'dart:math';

import 'data_model.dart';

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
/// CẦU TỔNG
/// =======================
class TotalCauStat {
  int maxWinStreak = 0;
  int maxLoseStreak = 0;
  int currentWin = 0;
  int currentLose = 0;

  final List<bool> history = [];

  void add(bool win) {
    history.add(win);
    if (win) {
      currentWin++;
      currentLose = 0;
      maxWinStreak = max(maxWinStreak, currentWin);
    } else {
      currentLose++;
      currentWin = 0;
      maxLoseStreak = max(maxLoseStreak, currentLose);
    }
  }

  String get text => history.map((e) => e ? 'W' : 'L').join('');
}

/// =======================
/// DE STAT
/// =======================
class DeCauStat {
  int win = 0;
  int total = 0;

  int currentWin = 0;
  int maxWinStreak = 0;

  void add(bool isWin) {
    total++;
    if (isWin) {
      win++;
      currentWin++;
      maxWinStreak = max(maxWinStreak, currentWin);
    } else {
      currentWin = 0;
    }
  }

  double get winrate => total == 0 ? 0 : win / total * 100;
}

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  final data = await loadDataModels('data.csv');
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  final Map<int, List<int>> historyStats = {};
  final totalCau = TotalCauStat();

  /// 👉 thống kê theo DE
  final Map<int, DeCauStat> deStats = {};

  for (int i = 0; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];

    final pastNums = historyStats[today.de];
    if (pastNums != null && pastNums.isNotEmpty) {
      final counter = <int, int>{};
      for (final n in pastNums) {
        counter[n] = (counter[n] ?? 0) + 1;
      }

      final sorted = counter.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final picks = sorted.take(2).map((e) => e.key).toList();
      final win = picks.any(tomorrow.others.contains);

      totalCau.add(win);

      deStats.putIfAbsent(today.de, () => DeCauStat());
      deStats[today.de]!.add(win);

      print(
        '${today.date.split(" ").first} | DE ${today.de.toString().padLeft(2, '0')} '
        '→ ${picks.map((e) => e.toString().padLeft(2, '0')).toList()} '
        '=> ${win ? "WIN" : "LOSE"}',
      );
    }

    historyStats.putIfAbsent(today.de, () => []);
    historyStats[today.de]!.addAll(tomorrow.others);
  }

  /// =======================
  /// KẾT QUẢ CẦU TỔNG
  /// =======================
  print('\n================ CẦU TỔNG =================');
  print('Chuỗi cầu: ${totalCau.text}');
  print('✅ Max WIN liên tiếp: ${totalCau.maxWinStreak}');
  print('❌ Max LOSE liên tiếp: ${totalCau.maxLoseStreak}');
  print(
    '➡ Hiện tại: ${totalCau.currentWin > 0 ? "WIN ${totalCau.currentWin}" : "LOSE ${totalCau.currentLose}"}',
  );

  /// =======================
  /// DE XUẤT SẮC
  /// =======================
  const int MIN_SAMPLE = 10;
  const double MIN_WINRATE = 55;

  final bestDes = deStats.entries
      .where((e) =>
          e.value.total >= MIN_SAMPLE &&
          e.value.winrate >= MIN_WINRATE)
      .toList()
    ..sort((a, b) => b.value.winrate.compareTo(a.value.winrate));

  print('\n================ DE XUẤT SẮC =================');
  for (final e in bestDes.take(10)) {
    final d = e.key;
    final s = e.value;
    print(
      'DE ${d.toString().padLeft(2, '0')} | '
      'Win ${s.win}/${s.total} '
      '| Winrate ${s.winrate.toStringAsFixed(2)}% '
      '| MaxWin ${s.maxWinStreak}',
    );
  }
}
