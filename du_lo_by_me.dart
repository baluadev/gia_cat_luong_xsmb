import 'dart:io';
import 'dart:math';

import 'data_model.dart';

class RoiStat {
  int hit = 0;
  int total = 0;
  int profit = 0;

  double get winrate => total == 0 ? 0 : hit / total * 100;
  double get roiPerTurn => total == 0 ? 0 : profit / total;
}

class CauItem {
  final bool win;
  final int de;
  final String date; // dd/MM/yyyy

  CauItem({
    required this.win,
    required this.de,
    required this.date,
  });
}

/// =======================
/// CẦU TỔNG & CẦU THEO DE
/// =======================
class TotalCauStat {
  int maxWinStreak = 0;
  int maxLoseStreak = 0;
  int currentWin = 0;
  int currentLose = 0;

  final List<CauItem> history = [];

  void add(
    bool win,
    int de,
    String date,
  ) {
    history.add(CauItem(win: win, de: de, date: date));

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

  /// ✅ WWL(20/12/2025 - 16)
  String textWithLatestDe(int latestDe, String? latestDate) {
    final sb = StringBuffer();

    for (final item in history) {
      final char = item.win ? 'W' : 'L';
      if (item.de == latestDe) {
        sb.write('$char(${item.date.split(' ').first} - ${item.de})');
      } else {
        sb.write(char);
      }
    }

    // Thêm '?' cho ngày cuối cùng nếu nó có DE=latestDe nhưng chưa có trong history
    if (latestDate != null && !history.any((item) => item.date == latestDate)) {
      sb.write('?(${latestDate.split(' ').first} - $latestDe)');
    }

    return sb.toString();
  }
}

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
/// =======================git
const int POINT_PER_NUMBER = 5; // mặc định nếu đánh đều 3 số
const int COST_PER_POINT = 22500;
const int PROFIT_PER_HIT_PER_POINT = 80000; // ví dụ lợi nhuận 1 điểm trúng
const int TOP_N_NUMBERS = 3; // số lượng số top để dự đoán
const int TOTAL_POINTS_TODAY = 15; // tổng điểm muốn đánh hôm nay
const int MIN_DE_SAMPLE =
    8; // tối thiểu số lần DE xuất hiện để coi là đủ dữ liệu
const int MIN_HIT_PER_NUMBER =
    3; // tối thiểu số lần 1 số WIN sau DE này để coi là đủ dày
const double MIN_TRUST_WINRATE =
    50.0; // winrate tối thiểu để coi là có thể cân nhắc

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  // =======================
  // LOAD + SORT (cache DateTime để tối ưu)
  // =======================
  final data = await loadDataModels('data.csv');

  // Cache DateTime để tránh parse nhiều lần
  final dataWithDate = data
      .map((d) => (
            model: d,
            dateTime: DateTime.parse(d.date),
          ))
      .toList();
  dataWithDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final sortedData = dataWithDate.map((e) => e.model).toList();
  print(sortedData.first.date);

  // =======================
  // MAP: DE -> COUNTS (tối ưu: tính counts trực tiếp, không cần lưu list)
  // =======================
  final Map<int, Map<int, int>> nextDayCounts = {}; // Cache counts để dùng sau

  for (int i = 0; i < sortedData.length - 1; i++) {
    final deToday = sortedData[i].de;
    final nextDayOthers = sortedData[i + 1].others;

    // Tính counts trực tiếp, không cần lưu list
    nextDayCounts.putIfAbsent(deToday, () => <int, int>{});
    final counter = nextDayCounts[deToday]!;
    for (final n in nextDayOthers) {
      counter[n] = (counter[n] ?? 0) + 1;
    }
  }

  // =======================
  // TOP N BY DE
  // =======================
  final Map<int, List<int>> topNByDe = {};
  nextDayCounts.forEach((de, counter) {
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    topNByDe[de] = sorted.take(TOP_N_NUMBERS).map((e) => e.key).toList();
  });

  // =======================
  // ROI: HIT + TOTAL (tối ưu: dùng Set cho contains check)
  // =======================
  final Map<int, RoiStat> roiStats = {};
  final Map<int, List<bool>> deHitHistory = {}; // lưu chuỗi W/L cho từng DE
  for (int i = 0; i < sortedData.length - 1; i++) {
    final deToday = sortedData[i].de;
    final topN = topNByDe[deToday];
    if (topN == null || topN.isEmpty) continue;

    // Tối ưu: convert others sang Set để O(1) lookup
    final nextDayOthersSet = sortedData[i + 1].others.toSet();
    final hit = topN.any((n) => nextDayOthersSet.contains(n));

    roiStats.putIfAbsent(deToday, () => RoiStat());
    final s = roiStats[deToday]!;
    deHitHistory.putIfAbsent(deToday, () => <bool>[]);
    deHitHistory[deToday]!.add(hit);

    s.total++;
    if (hit) s.hit++;
  }

  // =======================
  // TÍNH PROFIT (CHUẨN)
  // =======================
  roiStats.forEach((_, s) {
    final miss = s.total - s.hit;
    s.profit = s.hit * PROFIT_PER_HIT_PER_POINT * POINT_PER_NUMBER -
        miss * POINT_PER_NUMBER * COST_PER_POINT;
  });

  // =======================
  // DỰ ĐOÁN + PHÂN BỐ ĐIỂM
  // =======================
  final latestDe = sortedData.last.de;
  final predTopN = topNByDe[latestDe] ?? [];
  final latestDeHistory = deHitHistory[latestDe] ?? const <bool>[];

  print('\n=====================START==============================');
  print('DE NGÀY GẦN NHẤT: $latestDe');
  print('→ TOP $TOP_N_NUMBERS DỰ ĐOÁN: $predTopN');

  if (latestDeHistory.isNotEmpty) {
    final historyStr = latestDeHistory.map((e) => e ? 'W' : 'L').join('');

    int currentStreak = 0;
    bool? currentIsWin;
    for (int i = latestDeHistory.length - 1; i >= 0; i--) {
      if (currentIsWin == null) {
        currentIsWin = latestDeHistory[i];
        currentStreak = 1;
      } else if (latestDeHistory[i] == currentIsWin) {
        currentStreak++;
      } else {
        break;
      }
    }

    final stateLabel = currentIsWin == true ? 'WIN' : 'LOSE';

    print('Chuỗi cầu riêng DE $latestDe: $historyStr');
    print('Hiện tại cầu DE $latestDe: $stateLabel $currentStreak');

    // Thống kê max L liên tiếp cho DE này để đón đổi cầu
    int maxLoseStreakDe = 0;
    int curLose = 0;
    for (final h in latestDeHistory) {
      if (!h) {
        curLose++;
        if (curLose > maxLoseStreakDe) {
          maxLoseStreakDe = curLose;
        }
      } else {
        curLose = 0;
      }
    }

    if (maxLoseStreakDe > 0) {
      print('Max LOSE liên tiếp DE $latestDe: $maxLoseStreakDe');
      if (stateLabel == 'LOSE') {
        if (currentStreak >= maxLoseStreakDe) {
          print(
              '➡ Cầu DE $latestDe đang L $currentStreak, đã chạm/qua max L lịch sử → dễ đổi cầu sang W');
        } else if (currentStreak == maxLoseStreakDe - 1) {
          print(
              '➡ Cầu DE $latestDe đang L $currentStreak/${maxLoseStreakDe}, sắp chạm vùng L cực đại → có thể chuẩn bị đổi cầu');
        } else {
          print(
              '➡ Cầu DE $latestDe đang L $currentStreak/${maxLoseStreakDe}, còn room L thêm trước khi tới vùng đổi cầu');
        }
      }
    }
  }

  if (roiStats.containsKey(latestDe)) {
    final s = roiStats[latestDe]!;
    print(
        'Hit ${s.hit}/${s.total} | Winrate ${s.winrate.toStringAsFixed(2)}% | Profit ${s.profit} | ROI/lần ${s.roiPerTurn.toStringAsFixed(0)}');

    final evCalc = EvCalculator(
      payout: PROFIT_PER_HIT_PER_POINT.toDouble(),
      stake: COST_PER_POINT.toDouble(),
    );

    // Tối ưu: dùng cached counts thay vì tính lại
    final counts = nextDayCounts[latestDe] ?? {};

    // Lọc bớt các số quá mỏng dữ liệu (ít lần WIN sau DE này)
    final eligibleNumbers =
        predTopN.where((n) => (counts[n] ?? 0) >= MIN_HIT_PER_NUMBER).toList();

    final evDecisions = evCalc.decide(
      eligibleNumbers.isEmpty ? predTopN : eligibleNumbers,
      counts,
      s.total,
      minEv: 0.0,
    );

    if (evDecisions.isEmpty) {
      print('❌ Không con nào đủ EV → nghỉ hôm nay');
    } else {
      print('✅ Quyết định đánh ngày mai:');

      // Cảnh báo: nếu cầu DE vừa có chuỗi W dài và hiện đang L ngắn => dễ L tiếp
      double pointsFactor = 1.0;
      if (latestDeHistory.length >= 2) {
        // Tính current streak
        bool? curState;
        int curLen = 0;
        for (int i = latestDeHistory.length - 1; i >= 0; i--) {
          if (curState == null) {
            curState = latestDeHistory[i];
            curLen = 1;
          } else if (latestDeHistory[i] == curState) {
            curLen++;
          } else {
            break;
          }
        }
        // Tính đoạn ngay trước current streak
        bool? prevState;
        int prevLen = 0;
        for (int i = latestDeHistory.length - curLen - 1; i >= 0; i--) {
          if (prevState == null) {
            prevState = latestDeHistory[i];
            prevLen = 1;
          } else if (latestDeHistory[i] == prevState) {
            prevLen++;
          } else {
            break;
          }
        }
        const int WARN_WIN_STREAK = 5; // cầu W dài
        const int WARN_LOSE_AFTER_WIN = 2; // vừa gãy, L ngắn
        final bool caution = curState == false &&
            curLen <= WARN_LOSE_AFTER_WIN &&
            prevState == true &&
            prevLen >= WARN_WIN_STREAK;
        if (caution) {
          pointsFactor = 0.6; // giảm 40% tổng điểm đánh
          print(
              '⚠ Cảnh báo: Cầu DE $latestDe vừa gãy sau chuỗi W $prevLen, hiện đang L $curLen → giảm điểm đánh (x0.6)');
        }
      }

      // Tính tần suất xuất hiện của topN cho 'de' này
      final counts = nextDayCounts[latestDe] ?? {};
      final totalOccurrences =
          counts.values.fold<int>(0, (sum, count) => sum + count);

      print('\n📊 TẦN SUẤT XUẤT HIỆN CỦA TOP $TOP_N_NUMBERS (DE=$latestDe):');
      print('   Tổng số lần xuất hiện tất cả số: $totalOccurrences');
      print('   Số ngày DE=$latestDe xuất hiện: ${s.total}');

      // Phân tích cầu cho từng số trong topN
      final Map<int, CauAnalysis> cauAnalyses = {};
      for (var num in predTopN) {
        cauAnalyses[num] = analyzeCau(sortedData, latestDe, num);
      }

      for (var num in predTopN) {
        final frequency = counts[num] ?? 0;
        final percentage = s.total > 0 ? (frequency / s.total * 100) : 0.0;
        final avgPerDay = s.total > 0 ? (frequency / s.total) : 0.0;
        final cau = cauAnalyses[num]!;
        print(
            '   Số ${num.toString().padLeft(2, '0')}: $frequency lần (${percentage.toStringAsFixed(1)}% ngày, trung bình ${avgPerDay.toStringAsFixed(2)} lần/ngày)');
        print(
            '      Lần xuất hiện gần nhất: ${cau.lastOccurrenceDays == 0 ? "Hôm nay" : cau.lastOccurrenceDays > 0 ? "${cau.lastOccurrenceDays} ngày trước" : "Chưa từng xuất hiện"}');

        String maxCauInfo = '${cau.maxCauLength} ngày';
        if (cau.maxCauPosition > 0) {
          // đang ở trong cầu WIN (vì cầu được định nghĩa theo chuỗi xuất hiện - W)
          maxCauInfo +=
              ' (đang ở vị trí ${cau.maxCauPosition}/${cau.maxCauLength} - cầu W)';
        } else if (cau.maxCauLength > 0) {
          maxCauInfo += ' (không trong cầu này, hiện tại là L)';
        }

        String minCauInfo = '${cau.minCauLength} ngày';
        if (cau.minCauPosition > 0) {
          // đang ở trong cầu WIN ngắn nhất
          minCauInfo +=
              ' (đang ở vị trí ${cau.minCauPosition}/${cau.minCauLength} - cầu W)';
        } else if (cau.minCauLength > 0) {
          minCauInfo += ' (không trong cầu này, hiện tại là L)';
        }

        print('      Cầu dài nhất: $maxCauInfo');
        print('      Cầu ngắn nhất: $minCauInfo');
      }
      print('');

      for (var d in evDecisions) {
        final frequency = counts[d.number] ?? 0;
        final percentage = s.total > 0 ? (frequency / s.total * 100) : 0.0;
        int totalPointsToday = (TOTAL_POINTS_TODAY * pointsFactor).round();
        int pointsForNumber = max(1, (totalPointsToday * d.fraction).round());
        int cost = pointsForNumber * COST_PER_POINT;
        int profit = pointsForNumber * PROFIT_PER_HIT_PER_POINT;
        print(
            'Number ${d.number.toString().padLeft(2, '0')} → Points: $pointsForNumber | Cost: $cost | Profit: $profit | Fraction: ${(d.fraction * 100).toStringAsFixed(1)}% | EV: ${d.ev.toStringAsFixed(2)} | Tần suất: $frequency lần (${percentage.toStringAsFixed(1)}%)');
      }

      // =======================
      // TÓM TẮT ĐÁNH GIÁ TỰ ĐỘNG
      // =======================
      print('\n📌 TÓM TẮT ĐÁNH GIÁ:');

      String trustLevel;
      if (s.total >= MIN_DE_SAMPLE && s.winrate >= (MIN_TRUST_WINRATE + 10)) {
        trustLevel = 'CAO';
      } else if (s.total >= MIN_DE_SAMPLE && s.winrate >= MIN_TRUST_WINRATE) {
        trustLevel = 'TRUNG BÌNH';
      } else {
        trustLevel = 'THẤP';
      }

      print(
          'Độ tin cậy cầu DE $latestDe: $trustLevel (Win ${s.hit}/${s.total} ≈ ${s.winrate.toStringAsFixed(1)}%)');

      for (var num in predTopN) {
        final cau = cauAnalyses[num]!;
        final freq = counts[num] ?? 0;

        final lastText = cau.lastOccurrenceDays == 0
            ? 'vừa trúng gần nhất (hôm nay)'
            : cau.lastOccurrenceDays > 0
                ? 'trúng cách đây ${cau.lastOccurrenceDays} lần xuất hiện DE này'
                : 'chưa từng trúng sau DE này';

        final inWinNow = (cau.maxCauPosition > 0 || cau.minCauPosition > 0) &&
            cau.lastOccurrenceDays == 0;

        String dataText;
        if (freq >= MIN_HIT_PER_NUMBER) {
          dataText = 'data dày';
        } else if (freq >= 1) {
          dataText = 'data mỏng (chỉ $freq lần thắng)';
        } else {
          dataText = 'chưa có mẫu thắng';
        }

        final stateText = inWinNow
            ? 'đang ở trong cầu W'
            : 'đang ở pha L so với các cầu lịch sử';

        print(
            '  - Số ${num.toString().padLeft(2, '0')}: xuất hiện $freq lần ($dataText), $lastText, $stateText');
      }
    }
  } else {
    print('Chưa có dữ liệu lịch sử cho DE này');
  }

  // =======================
  // SOI CẦU TỔNG HỢP (từ tohop2.dart)
  // =======================
  runCauAnalysis(sortedData, pickCount: TOP_N_NUMBERS);

  print('========================END===========================');
}

/// =======================
/// SOI CẦU (từ tohop2.dart)
/// =======================
void runCauAnalysis(List<DataModel> sortedData,
    {int pickCount = TOP_N_NUMBERS}) {
  final Map<int, List<int>> historyStats = {};
  final totalCau = TotalCauStat();
  final Map<int, DeCauStat> deStats = {};

  for (int i = 0; i < sortedData.length - 1; i++) {
    final today = sortedData[i];
    final tomorrow = sortedData[i + 1];

    final pastNums = historyStats[today.de];
    if (pastNums != null && pastNums.isNotEmpty) {
      final counter = <int, int>{};
      for (final n in pastNums) {
        counter[n] = (counter[n] ?? 0) + 1;
      }

      final sorted = counter.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final picks = sorted.take(pickCount).map((e) => e.key).toList();
      final win = picks.any(tomorrow.others.contains);

      totalCau.add(win, today.de, today.date);

      deStats.putIfAbsent(today.de, () => DeCauStat());
      deStats[today.de]!.add(win);

      // print(
      //   '${today.date.split(" ").first} | DE ${today.de.toString().padLeft(2, '0')} '
      //   '→ ${picks.map((e) => e.toString().padLeft(2, '0')).toList()} '
      //   '=> ${win ? "WIN" : "LOSE"}',
      // );
    }

    historyStats.putIfAbsent(today.de, () => []);
    historyStats[today.de]!.addAll(tomorrow.others);
  }
  final latestDe = sortedData.last.de;
  final latestDate = sortedData.last.date;
  // Kết quả cầu tổng
  print('\n================ CẦU TỔNG =================');
  print('Chuỗi cầu: ${totalCau.textWithLatestDe(latestDe, latestDate)}');
  print('✅ Max WIN liên tiếp: ${totalCau.maxWinStreak}');
  print('❌ Max LOSE liên tiếp: ${totalCau.maxLoseStreak}');
  print(
    '➡ Hiện tại: ${totalCau.currentWin > 0 ? "WIN ${totalCau.currentWin}" : "LOSE ${totalCau.currentLose}"}',
  );
}

/// =======================
/// PHÂN TÍCH CẦU
/// =======================
class CauAnalysis {
  final int lastOccurrenceDays; // Số ngày từ lần xuất hiện gần nhất
  final int maxCauLength; // Độ dài cầu dài nhất
  final int maxCauPosition; // Vị trí hiện tại trong cầu dài nhất
  final int minCauLength; // Độ dài cầu ngắn nhất
  final int minCauPosition; // Vị trí hiện tại trong cầu ngắn nhất

  CauAnalysis({
    required this.lastOccurrenceDays,
    required this.maxCauLength,
    required this.maxCauPosition,
    required this.minCauLength,
    required this.minCauPosition,
  });
}

CauAnalysis analyzeCau(List<DataModel> sortedData, int de, int number) {
  // Tìm tất cả các ngày có DE = de và kiểm tra số có xuất hiện trong others ngày tiếp theo không
  final List<bool> occurrences = [];
  final List<int> dayIndices = []; // Lưu index của các ngày có DE = de

  for (int i = 0; i < sortedData.length - 1; i++) {
    if (sortedData[i].de == de) {
      dayIndices.add(i);
      final nextDayOthers = sortedData[i + 1].others.toSet();
      occurrences.add(nextDayOthers.contains(number));
    }
  }

  if (occurrences.isEmpty) {
    return CauAnalysis(
      lastOccurrenceDays: -1,
      maxCauLength: 0,
      maxCauPosition: 0,
      minCauLength: 0,
      minCauPosition: 0,
    );
  }

  // Tìm lần xuất hiện gần nhất (từ cuối lên)
  int lastOccurrenceDays = -1;
  for (int i = occurrences.length - 1; i >= 0; i--) {
    if (occurrences[i]) {
      lastOccurrenceDays = occurrences.length - 1 - i;
      break;
    }
  }

  // Phân tích cầu: tìm các chuỗi liên tiếp
  List<int> cauLengths = [];
  int currentCauLength = 0;
  bool inCau = false;

  for (int i = 0; i < occurrences.length; i++) {
    if (occurrences[i]) {
      if (!inCau) {
        inCau = true;
        currentCauLength = 1;
      } else {
        currentCauLength++;
      }
    } else {
      if (inCau) {
        cauLengths.add(currentCauLength);
        currentCauLength = 0;
        inCau = false;
      }
    }
  }
  if (inCau) {
    cauLengths.add(currentCauLength);
  }

  // Tìm cầu hiện tại (cầu cuối cùng nếu đang trong cầu)
  int currentCauLengthNow = 0;
  int currentCauPosition = 0;
  bool inCurrentCau = false;

  for (int i = occurrences.length - 1; i >= 0; i--) {
    if (occurrences[i]) {
      if (!inCurrentCau) {
        inCurrentCau = true;
        currentCauLengthNow = 1;
        currentCauPosition = 1;
      } else {
        currentCauLengthNow++;
        currentCauPosition++;
      }
    } else {
      if (inCurrentCau) {
        break;
      }
    }
  }

  // Tìm max và min cầu từ lịch sử (bao gồm cả cầu hiện tại nếu có)
  List<int> allCauLengths = List.from(cauLengths);
  if (inCurrentCau && currentCauLengthNow > 0) {
    allCauLengths.add(currentCauLengthNow);
  }

  int maxCauLength = allCauLengths.isNotEmpty ? allCauLengths.reduce(max) : 0;
  int minCauLength = allCauLengths.isNotEmpty ? allCauLengths.reduce(min) : 0;

  // Vị trí trong cầu: nếu đang trong cầu và cầu đó = max/min thì hiển thị vị trí, ngược lại = 0
  int maxCauPosition = 0;
  int minCauPosition = 0;

  if (inCurrentCau && currentCauLengthNow > 0) {
    if (currentCauLengthNow == maxCauLength) {
      maxCauPosition = currentCauPosition;
    }
    if (currentCauLengthNow == minCauLength) {
      minCauPosition = currentCauPosition;
    }
  }

  return CauAnalysis(
    lastOccurrenceDays: lastOccurrenceDays,
    maxCauLength: maxCauLength,
    maxCauPosition: maxCauPosition,
    minCauLength: minCauLength,
    minCauPosition: minCauPosition,
  );
}

/// =======================
/// TÍNH EV & DECIDE
/// =======================
class EvDecision {
  final int number;
  final double ev;
  double fraction;
  EvDecision(this.number, this.ev, this.fraction);

  @override
  String toString() =>
      'Number: ${number.toString().padLeft(2, '0')} | EV: ${ev.toStringAsFixed(3)} | Fraction: ${(fraction * 100).toStringAsFixed(1)}%';
}

class EvCalculator {
  final double payout; // lợi nhuận trên 1 điểm
  final double stake; // COST mỗi điểm

  EvCalculator({this.payout = 3.55, this.stake = 1.0});

  double computeEv(double probability) =>
      probability * payout - (1 - probability) * stake;

  List<EvDecision> decide(
      List<int> numbers, Map<int, int> counts, int totalDays,
      {double minEv = 0.0}) {
    final List<EvDecision> list = [];
    double totalEv = 0;

    for (var n in numbers) {
      final p = (counts[n] ?? 0) / totalDays;
      final ev = computeEv(p);
      if (ev >= minEv) {
        list.add(EvDecision(n, ev, 0.0));
        totalEv += ev;
      }
    }

    if (list.isEmpty) return [];

    for (var d in list) {
      d.fraction = d.ev / totalEv;
    }

    list.sort((a, b) => b.ev.compareTo(a.ev));
    return list;
  }
}
