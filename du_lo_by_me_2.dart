import 'dart:io';

/// =======================
/// DATA MODEL
/// =======================
class DataModel {
  final String date;
  final List<int> others;

  DataModel({required this.date, required this.others});
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
/// MAIN
/// =======================
Future<void> main() async {
  final data = await loadData('data.csv');
  data.sort(
    (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)),
  );

  final todayIndex = data.length - 1;
  final today = data[todayIndex];

  print('📅 Ngày phân tích: ${today.date.split(" ").first}');
  print('Others hôm nay: ${today.others}\n');

  /// 🔥 MERGE CUỐI CÙNG
  final Map<int, int> globalVotes = {};

  /// =======================
  /// DUYỆT MỖI SỐ X
  /// =======================
  for (final x in today.others) {
    final Map<int, int> futureFreq = {};
    final Map<int, int> pastFreq = {};

    /// ===== PHƯƠNG ÁN A: X → date +1 =====
    for (int i = 0; i < data.length - 1; i++) {
      if (data[i].others.contains(x)) {
        for (final n in data[i + 1].others) {
          futureFreq[n] = (futureFreq[n] ?? 0) + 1;
        }
      }
    }

    /// ===== PHƯƠNG ÁN B: date -1 -2 -3 =====
    for (int k = 1; k <= 3; k++) {
      final idx = todayIndex - k;
      if (idx < 0) continue;
      for (final n in data[idx].others) {
        pastFreq[n] = (pastFreq[n] ?? 0) + 1;
      }
    }

    final topFuture = topN(futureFreq, 5);
    final topPast = topN(pastFreq, 5);

    /// ===== MERGE CHO RIÊNG X =====
    final Map<int, int> localVotes = {};

    for (final n in topFuture) {
      localVotes[n] = (localVotes[n] ?? 0) + 1;
    }
    for (final n in topPast) {
      localVotes[n] = (localVotes[n] ?? 0) + 1;
    }

    final top3X = topN(localVotes, 3);

    /// ===== ĐẨY VÀO MERGE TOÀN CỤC =====
    for (final n in top3X) {
      globalVotes[n] = (globalVotes[n] ?? 0) + 1;
    }

    /// ===== LOG =====
    print('X = ${x.toString().padLeft(2, '0')}'
        ' → TOP3: ${top3X.map((e) => e.toString().padLeft(2, '0')).toList()}');
  }

  /// =======================
  /// KẾT QUẢ CUỐI
  /// =======================
  final finalTop3 = topN(globalVotes, 3);

  print('\n=========== 🎯 GỢI Ý CUỐI ==========');
  print('TOP 3 SỐ MẠNH NHẤT: '
      '${finalTop3.map((e) => e.toString().padLeft(2, '0')).toList()}');

  print('\nChi tiết vote: ${globalVotes.length}');
  globalVotes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))
    ..forEach((e) {
      print('${e.key.toString().padLeft(2, '0')} : ${e.value}');
    });
}
