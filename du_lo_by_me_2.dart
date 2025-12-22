import 'dart:io';

import 'data_model.dart';

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
/// CONFIG
/// =======================
const int TOP_N_NUMBERS = 2; // chỉ lấy top 2
const int MIN_OCCURRENCES = 15; // Tần suất xuất hiện tối thiểu để đảm bảo dữ liệu đủ tin cậy
const double MIN_WINRATE = 53.0; // Winrate tối thiểu
const int RECENT_DAYS_1 = 30; // 30 ngày gần nhất
const double WEIGHT_RECENT_1 = 2.0; // Trọng số cho 30 ngày gần nhất
const int RECENT_DAYS_2 = 60; // 60 ngày tiếp theo (từ ngày 31-90)
const double WEIGHT_RECENT_2 = 1.5; // Trọng số cho 60 ngày tiếp theo
const double WEIGHT_OLD = 1.0; // Trọng số cho dữ liệu cũ

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  // =======================
  // LOAD + SORT
  // =======================
  final data = await loadDataModels('data.csv');

  final dataWithDate = data
      .map((d) => (
            model: d,
            dateTime: DateTime.parse(d.date),
          ))
      .toList();
  dataWithDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final sortedData = dataWithDate.map((e) => e.model).toList();
  final totalDays = sortedData.length;

  // =======================
  // THỐNG KÊ: Với mỗi số trong others của ngày A,
  // đếm các số xuất hiện trong others của ngày A+1
  // Áp dụng WEIGHTED: ưu tiên dữ liệu gần đây
  // =======================
  // Map: key = số trong others của ngày A
  //      value = Map<số trong others ngày A+1, tổng trọng số>
  final Map<int, Map<int, double>> weightedStats = {};

  for (int i = 0; i < sortedData.length - 1; i++) {
    final othersToday = sortedData[i].others;
    final othersNextDay = sortedData[i + 1].others;

    // Tính trọng số dựa trên vị trí trong lịch sử (ngày càng gần thì weight càng cao)
    // i = 0 là ngày xa nhất, i gần totalDays là ngày gần nhất
    final daysFromEnd = totalDays - 1 - i;
    double weight;
    if (daysFromEnd <= RECENT_DAYS_1) {
      weight = WEIGHT_RECENT_1; // 30 ngày gần nhất
    } else if (daysFromEnd <= RECENT_DAYS_1 + RECENT_DAYS_2) {
      weight = WEIGHT_RECENT_2; // 60 ngày tiếp theo
    } else {
      weight = WEIGHT_OLD; // Dữ liệu cũ
    }

    // Với mỗi số trong others của ngày A
    for (final keyNum in othersToday) {
      weightedStats.putIfAbsent(keyNum, () => <int, double>{});
      final counter = weightedStats[keyNum]!;

      // Đếm các số xuất hiện trong others của ngày A+1 (có trọng số)
      for (final num in othersNextDay) {
        counter[num] = (counter[num] ?? 0) + weight;
      }
    }
  }

  // =======================
  // TÍNH TOP N VÀ WINRATE (CÓ TRỌNG SỐ)
  // =======================
  // Với mỗi số key, lấy top N số xuất hiện nhiều nhất (có trọng số) trong others ngày A+1
  // Tính winrate có trọng số: weighted wins / weighted total
  final Map<int, List<int>> topNByKey = {};
  final Map<int, double> weightedTotalOccurrences = {}; // Tổng trọng số của key
  final Map<int, double> weightedWinCount = {}; // Tổng trọng số WIN
  final Map<int, int> rawTotalOccurrences = {}; // Số lần thực tế (không có trọng số) để kiểm tra MIN_OCCURRENCES

  // Tính top N cho mỗi key (dựa trên trọng số)
  weightedStats.forEach((key, counter) {
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topNByKey[key] = sorted.take(TOP_N_NUMBERS).map((e) => e.key).toList();
  });

  // Tính winrate có trọng số
  for (int i = 0; i < sortedData.length - 1; i++) {
    final othersToday = sortedData[i].others;
    final othersNextDaySet = sortedData[i + 1].others.toSet();

    // Tính trọng số
    final daysFromEnd = totalDays - 1 - i;
    double weight;
    if (daysFromEnd <= RECENT_DAYS_1) {
      weight = WEIGHT_RECENT_1;
    } else if (daysFromEnd <= RECENT_DAYS_1 + RECENT_DAYS_2) {
      weight = WEIGHT_RECENT_2;
    } else {
      weight = WEIGHT_OLD;
    }

    for (final keyNum in othersToday) {
      rawTotalOccurrences[keyNum] = (rawTotalOccurrences[keyNum] ?? 0) + 1;
      weightedTotalOccurrences[keyNum] = (weightedTotalOccurrences[keyNum] ?? 0) + weight;

      final topN = topNByKey[keyNum];
      if (topN != null && topN.isNotEmpty) {
        // Nếu có số nào trong topN xuất hiện trong others ngày A+1 thì tính là WIN (có trọng số)
        final hit = topN.any((n) => othersNextDaySet.contains(n));
        if (hit) {
          weightedWinCount[keyNum] = (weightedWinCount[keyNum] ?? 0) + weight;
        }
      }
    }
  }

  // =======================
  // IN LOG (chỉ các số có winrate >= MIN_WINRATE và xuất hiện >= MIN_OCCURRENCES lần)
  // =======================
  // Lấy các số trong others của ngày gần nhất
  final latestOthers = sortedData.last.others;

  print('→ TOP $TOP_N_NUMBERS DỰ ĐOÁN (Winrate >= ${MIN_WINRATE}% với weighted, xuất hiện >= $MIN_OCCURRENCES lần):');
  print('   [Weighted: ${RECENT_DAYS_1} ngày gần nhất x${WEIGHT_RECENT_1}, ${RECENT_DAYS_2} ngày tiếp theo x${WEIGHT_RECENT_2}, còn lại x${WEIGHT_OLD}]');

  // Lưu danh sách các số có winrate cao và đủ dữ liệu để tổng hợp sau
  final List<int> keysWithHighWinrate = [];

  // Với mỗi số trong others của ngày gần nhất, chỉ xét nếu đủ điều kiện
  for (final keyNum in latestOthers) {
    final topN = topNByKey[keyNum] ?? [];
    final rawTotal = rawTotalOccurrences[keyNum] ?? 0;
    final weightedTotal = weightedTotalOccurrences[keyNum] ?? 0.0;
    final weightedWins = weightedWinCount[keyNum] ?? 0.0;
    final weightedWinrate = weightedTotal > 0 ? (weightedWins / weightedTotal * 100) : 0.0;

    // Bỏ qua các số không đủ điều kiện:
    // 1. Winrate có trọng số < MIN_WINRATE
    // 2. Tần suất xuất hiện thực tế < MIN_OCCURRENCES (thiếu dữ liệu, không đáng tin cậy)
    if (weightedWinrate < MIN_WINRATE || rawTotal < MIN_OCCURRENCES) continue;

    keysWithHighWinrate.add(keyNum);

    // Lấy số lần xuất hiện có trọng số của top N
    final counter = weightedStats[keyNum] ?? {};
    
    print('\nSố $keyNum:');
    print('  Top $TOP_N_NUMBERS: $topN');
    
    // In số lần xuất hiện có trọng số của từng số trong top N
    for (final num in topN) {
      final weightedCount = counter[num] ?? 0.0;
      print('    Số ${num.toString().padLeft(2, '0')}: ${weightedCount.toStringAsFixed(1)} (weighted)');
    }
    
    print('  Winrate (weighted): ${weightedWinrate.toStringAsFixed(2)}% (${weightedWins.toStringAsFixed(1)}/${weightedTotal.toStringAsFixed(1)})');
    print('  Số lần xuất hiện thực tế: $rawTotal');
  }

  // =======================
  // TỔNG HỢP: Đếm số lần xuất hiện của các số trùng nhau trong tất cả top 2
  // Chỉ lấy từ các số có winrate cao và đủ dữ liệu
  // =======================
  final Map<int, int> aggregatedCounts = {};

  // Thu thập tất cả các số trong top 2 của các số có winrate cao và đủ dữ liệu
  for (final keyNum in keysWithHighWinrate) {
    final topN = topNByKey[keyNum] ?? [];
    for (final num in topN) {
      aggregatedCounts[num] = (aggregatedCounts[num] ?? 0) + 1;
    }
  }

  // Sắp xếp theo số lần xuất hiện giảm dần
  final sortedAggregated = aggregatedCounts.entries.toList()
    ..sort((a, b) {
      // Sắp xếp theo số lần xuất hiện giảm dần, nếu bằng thì sắp xếp theo số tăng dần
      if (b.value != a.value) {
        return b.value.compareTo(a.value);
      }
      return a.key.compareTo(b.key);
    });

  // In kết quả tổng hợp
  if (sortedAggregated.isNotEmpty) {
    print('\n📊 TỔNG HỢP TOP 2 (số lần xuất hiện):');
    for (final entry in sortedAggregated) {
      print('  Số ${entry.key.toString().padLeft(2, '0')}: ${entry.value} lần');
    }

    // =======================
    // CẦU W/L: Đánh top 2 số từ tổng hợp
    // =======================
    final top2Numbers = sortedAggregated.take(2).map((e) => e.key).toList();
    if (top2Numbers.length == 2) {
      print('\n🎯 ĐÁNH 2 SỐ: $top2Numbers');
      
      // Duyệt lịch sử để tính cầu W/L
      final List<bool> cauHistory = [];
      int hitCount = 0;
      
      for (int i = 0; i < sortedData.length - 1; i++) {
        final othersNextDaySet = sortedData[i + 1].others.toSet();
        // Kiểm tra xem có số nào trong top 2 xuất hiện trong others ngày A+1 không
        final hit = top2Numbers.any((n) => othersNextDaySet.contains(n));
        cauHistory.add(hit);
        if (hit) hitCount++;
      }

      // Tính chuỗi cầu
      final cauStr = cauHistory.map((e) => e ? 'W' : 'L').join('');
      
      // Tính current streak
      int currentStreak = 0;
      bool? currentIsWin;
      for (int i = cauHistory.length - 1; i >= 0; i--) {
        if (currentIsWin == null) {
          currentIsWin = cauHistory[i];
          currentStreak = 1;
        } else if (cauHistory[i] == currentIsWin) {
          currentStreak++;
        } else {
          break;
        }
      }

      // Tính max streaks
      int maxWinStreak = 0;
      int maxLoseStreak = 0;
      int curWin = 0;
      int curLose = 0;
      
      for (final h in cauHistory) {
        if (h) {
          curWin++;
          curLose = 0;
          maxWinStreak = maxWinStreak > curWin ? maxWinStreak : curWin;
        } else {
          curLose++;
          curWin = 0;
          maxLoseStreak = maxLoseStreak > curLose ? maxLoseStreak : curLose;
        }
      }

      final total = cauHistory.length;
      final winrate = total > 0 ? (hitCount / total * 100) : 0.0;
      final stateLabel = currentIsWin == true ? 'WIN' : 'LOSE';

      print('Chuỗi cầu: $cauStr');
      print('Hiện tại: $stateLabel $currentStreak');
      print('✅ Max WIN liên tiếp: $maxWinStreak');
      print('❌ Max LOSE liên tiếp: $maxLoseStreak');
      print('Winrate: ${winrate.toStringAsFixed(2)}% ($hitCount/$total)');
    }
  }

  // =======================
  // THỐNG KÊ: Ngày A có số N thì ngày A+1 xuất hiện số N
  // Chỉ lấy winrate > 90% và đủ dữ liệu (áp dụng weighted)
  // =======================
  final Map<int, double> numberWeightedTotalCount = {}; // Tổng trọng số của số N
  final Map<int, double> numberWeightedHitCount = {}; // Tổng trọng số khi số N xuất hiện lại
  final Map<int, int> numberRawTotalCount = {}; // Số lần thực tế (để kiểm tra MIN_OCCURRENCES)

  for (int i = 0; i < sortedData.length - 1; i++) {
    final othersToday = sortedData[i].others;
    final othersNextDaySet = sortedData[i + 1].others.toSet();

    // Tính trọng số
    final daysFromEnd = totalDays - 1 - i;
    double weight;
    if (daysFromEnd <= RECENT_DAYS_1) {
      weight = WEIGHT_RECENT_1;
    } else if (daysFromEnd <= RECENT_DAYS_1 + RECENT_DAYS_2) {
      weight = WEIGHT_RECENT_2;
    } else {
      weight = WEIGHT_OLD;
    }

    // Với mỗi số N trong others của ngày A
    for (final num in othersToday) {
      numberRawTotalCount[num] = (numberRawTotalCount[num] ?? 0) + 1;
      numberWeightedTotalCount[num] = (numberWeightedTotalCount[num] ?? 0) + weight;

      // Kiểm tra xem số N có xuất hiện trong others ngày A+1 không
      if (othersNextDaySet.contains(num)) {
        numberWeightedHitCount[num] = (numberWeightedHitCount[num] ?? 0) + weight;
      }
    }
  }

  // Tính winrate có trọng số và lọc các số có winrate > 90% và đủ dữ liệu
  final List<MapEntry<int, double>> highWinrateNumbers = [];

  numberWeightedTotalCount.forEach((num, weightedTotal) {
    // Chỉ xét các số có đủ dữ liệu
    final rawTotal = numberRawTotalCount[num] ?? 0;
    if (rawTotal < MIN_OCCURRENCES) return;

    final weightedHits = numberWeightedHitCount[num] ?? 0.0;
    final weightedWinrate = weightedTotal > 0 ? (weightedHits / weightedTotal * 100) : 0.0;

    // Chỉ lấy các số có winrate > 90% (có trọng số) và đủ dữ liệu
    if (weightedWinrate > 90.0) {
      highWinrateNumbers.add(MapEntry(num, weightedWinrate));
    }
  });

  // Sắp xếp theo winrate giảm dần
  highWinrateNumbers.sort((a, b) => b.value.compareTo(a.value));

  // In kết quả
  if (highWinrateNumbers.isNotEmpty) {
    print('\n🎯 SỐ CÓ WINRATE > 90% (Ngày A có số N → Ngày A+1 xuất hiện số N, weighted, xuất hiện >= $MIN_OCCURRENCES lần):');
    for (final entry in highWinrateNumbers) {
      final num = entry.key;
      final weightedWinrate = entry.value;
      final weightedTotal = numberWeightedTotalCount[num] ?? 0.0;
      final weightedHits = numberWeightedHitCount[num] ?? 0.0;
      final rawTotal = numberRawTotalCount[num] ?? 0;
      print('  Số ${num.toString().padLeft(2, '0')}: ${weightedWinrate.toStringAsFixed(2)}% (weighted: ${weightedHits.toStringAsFixed(1)}/${weightedTotal.toStringAsFixed(1)}, thực tế: $rawTotal)');
    }
  } else {
    print('\n❌ Không có số nào có winrate > 90% (weighted) và xuất hiện >= $MIN_OCCURRENCES lần');
  }
}
