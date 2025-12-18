import 'dart:io';

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
Future<List<DataModel>> loadData(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0);

  return lines.map((l) {
    final p = l.split(',');
    return DataModel(
      date: p[0],
      de: int.parse(p[1]),
      others: p.sublist(2).map(int.parse).toList(),
    );
  }).toList();
}

/// =======================
/// UTILS
/// =======================
List<int> topN(Map<int, int> freq, int n) {
  final list = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list.take(n).map((e) => e.key).toList();
}

/// =======================
/// BUILD GLOBAL VOTES (CẦU)
/// =======================
Map<int, int> buildGlobalVotes(List<DataModel> data, int endIndex) {
  final today = data[endIndex];
  final Map<int, int> globalVotes = {};

  for (final x in today.others) {
    final Map<int, int> futureFreq = {};
    final Map<int, int> pastFreq = {};

    /// A: X xuất hiện → ngày sau ra gì
    for (int i = 0; i < endIndex; i++) {
      if (data[i].others.contains(x)) {
        for (final n in data[i + 1].others) {
          futureFreq[n] = (futureFreq[n] ?? 0) + 1;
        }
      }
    }

    /// B: 3 ngày trước
    for (int k = 1; k <= 3; k++) {
      final idx = endIndex - k;
      if (idx < 0) continue;
      for (final n in data[idx].others) {
        pastFreq[n] = (pastFreq[n] ?? 0) + 1;
      }
    }

    final topFuture = topN(futureFreq, 5);
    final topPast = topN(pastFreq, 5);

    final Map<int, int> localVotes = {};
    for (final n in topFuture) {
      localVotes[n] = (localVotes[n] ?? 0) + 1;
    }
    for (final n in topPast) {
      localVotes[n] = (localVotes[n] ?? 0) + 1;
    }

    final top3X = topN(localVotes, 3);
    for (final n in top3X) {
      globalVotes[n] = (globalVotes[n] ?? 0) + 1;
    }
  }

  return globalVotes;
}

Future<void> main() async {
  final data = await loadData('data.csv');
  data.sort(
    (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)),
  );

  int win = 0;
  int lose = 0;

  int currentLoseStreak = 0;
  int maxLoseStreak = 0;

  final List<String> wlHistory = [];

  /// DE → WIN / TOTAL
  final Map<int, int> deWin = {};
  final Map<int, int> deTotal = {};

  /// ========= BACKTEST =========
  for (int i = 5; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];

    final globalVotes = buildGlobalVotes(data, i);
    final picks = globalVotes.keys.toSet();

    final isWin = picks.contains(tomorrow.de);

    if (isWin) {
      win++;
      currentLoseStreak = 0;
    } else {
      lose++;
      currentLoseStreak++;
      if (currentLoseStreak > maxLoseStreak) {
        maxLoseStreak = currentLoseStreak;
      }
    }

    /// DE stats
    deTotal[today.de] = (deTotal[today.de] ?? 0) + 1;
    if (isWin) {
      deWin[today.de] = (deWin[today.de] ?? 0) + 1;
    }
  }

  /// ========= BUILD DE TỐT =========
  final Set<int> goodDEs = {};

  for (final de in deTotal.keys) {
    final total = deTotal[de]!;
    if (total < 5) continue;

    final w = deWin[de] ?? 0;
    final rate = w / total * 100;

    if (rate >= 55) {
      goodDEs.add(de);
    }
  }

  /// ========= RE-BACKTEST ĐỂ IN CHUỖI =========
  currentLoseStreak = 0;

  for (int i = 5; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];

    final globalVotes = buildGlobalVotes(data, i);
    final picks = globalVotes.keys.toSet();

    final isWin = picks.contains(tomorrow.de);
    final isGoodDE = goodDEs.contains(today.de);

    String tag;
    if (isGoodDE) {
      tag = '${isWin ? "W" : "L"}(${today.de.toString().padLeft(2, '0')})';
    } else {
      tag = isWin ? 'W' : 'L';
    }

    wlHistory.add(tag);
  }

  /// ========= OUTPUT =========
  print('\n=========== 📈 TỔNG KẾT ==========');
  print('WIN : $win');
  print('LOSE: $lose');
  print('Winrate: ${(win / (win + lose) * 100).toStringAsFixed(2)}%');

  print('\n=========== ❌ CẦU THUA ==========');
  print('❌ Max LOSE liên tiếp: $maxLoseStreak');
  print('Chuỗi W/L:\n');
  print(wlHistory.join(' '));

  print('\n=========== 🎯 DE THUỘC CẦU TỐT ==========');
  for (final de in goodDEs) {
    final w = deWin[de]!;
    final t = deTotal[de]!;
    print(
      'DE ${de.toString().padLeft(2, '0')} | Win $w/$t | ${(w / t * 100).toStringAsFixed(2)}%',
    );
  }
}
