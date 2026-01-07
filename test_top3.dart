import 'dart:io';
import 'dart:math';
import 'data_model.dart';

const int TOP_N_NUMBERS = 3; // Thay đổi từ 3 sang 5

/// =======================
/// BACKTEST: TOP N VỚI LOGIC ƯU TIÊN
/// =======================
Future<void> main() async {
  final data = await loadDataModels('data.csv');
  
  // Sort by date
  final dataWithDate = data
      .map((d) => (
            model: d,
            dateTime: DateTime.parse(d.date),
          ))
      .toList();
  dataWithDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final sortedData = dataWithDate.map((e) => e.model).toList();

  // =======================
  // BACKTEST: Top N với logic ưu tiên
  // =======================
  final Map<int, int> deWinCount = {}; // DE -> số lần win
  final Map<int, int> deTotalCount = {}; // DE -> tổng số lần test
  final Map<int, List<bool>> deResults = {}; // DE -> danh sách kết quả

  int totalWin = 0;
  int totalTest = 0;

  for (int i = 0; i < sortedData.length - 1; i++) {
    final today = sortedData[i];
    final tomorrow = sortedData[i + 1];
    final de = today.de;

    // Tìm tất cả các ngày trước đó có cùng DE
    final Map<int, int> numberCounts = {}; // Số -> số lần xuất hiện
    
    for (int j = 0; j < i; j++) {
      if (sortedData[j].de == de) {
        // Lấy others của ngày tiếp theo sau ngày j
        if (j + 1 < sortedData.length) {
          final nextDayOthers = sortedData[j + 1].others.toSet();
          for (final num in nextDayOthers) {
            numberCounts[num] = (numberCounts[num] ?? 0) + 1;
          }
        }
      }
    }

    // Nếu có history, tạo top N với logic ưu tiên
    if (numberCounts.isNotEmpty) {
      // Lấy candidate numbers (top N * 2 để có đủ để sắp xếp)
      final sorted = numberCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final candidateNumbers = sorted.take(TOP_N_NUMBERS * 2).map((e) => e.key).toList();
      
      // Phân tích cầu cho các số candidate
      final Map<int, CauAnalysis> candidateCauAnalyses = {};
      for (var num in candidateNumbers) {
        candidateCauAnalyses[num] = analyzeCau(sortedData, de, num, i);
      }
      
      // Sắp xếp lại theo logic ưu tiên
      candidateNumbers.sort((a, b) {
        final freqA = numberCounts[a] ?? 0;
        final freqB = numberCounts[b] ?? 0;
        
        // Ưu tiên 1: Tần suất xuất hiện (giảm dần)
        if (freqA != freqB) {
          return freqB.compareTo(freqA);
        }
        
        final cauA = candidateCauAnalyses[a]!;
        final cauB = candidateCauAnalyses[b]!;
        
        // Ưu tiên 2: Cầu LOSE ngắn nhất (maxLoseStreak thấp nhất)
        final maxLoseA = cauA.maxLoseStreak;
        final maxLoseB = cauB.maxLoseStreak;
        if (maxLoseA != maxLoseB) {
          return maxLoseA.compareTo(maxLoseB); // Thấp hơn → ưu tiên hơn
        }
        
        // Ưu tiên 3: Nếu đang L → ưu tiên số nào có currentLoseStreak gần với maxLoseStreak nhất
        final inCauA = cauA.inCurrentCau;
        final inCauB = cauB.inCurrentCau;
        
        if (!inCauA && !inCauB) {
          // Cả 2 đang L: ưu tiên số nào có currentLoseStreak gần với maxLoseStreak nhất
          final curLoseA = cauA.currentLoseStreak;
          final curLoseB = cauB.currentLoseStreak;
          final diffA = (maxLoseA - curLoseA).abs(); // Khoảng cách đến maxLoseStreak
          final diffB = (maxLoseB - curLoseB).abs();
          if (diffA != diffB) {
            return diffA.compareTo(diffB); // Gần hơn → ưu tiên hơn
          }
        } else if (inCauA && inCauB) {
          // Ưu tiên 4: Nếu đang W → ưu tiên cầu W dài nhất
          final cauLengthA = cauA.currentCauLength;
          final cauLengthB = cauB.currentCauLength;
          if (cauLengthA != cauLengthB) {
            return cauLengthB.compareTo(cauLengthA); // Dài hơn → ưu tiên hơn
          }
        } else {
          // Một đang W, một đang L → ưu tiên đang W
          return inCauB ? 1 : -1; // inCauB (W) → ưu tiên hơn
        }
        
        // Ưu tiên 5: Giữ nguyên thứ tự (so sánh số)
        return a.compareTo(b);
      });
      
      final topN = candidateNumbers.take(TOP_N_NUMBERS).toList();
      
      // Kiểm tra top N có trong others của ngày mai không
      final tomorrowOthersSet = tomorrow.others.toSet();
      final win = topN.any((num) => tomorrowOthersSet.contains(num));

      // Cập nhật thống kê
      deWinCount[de] = (deWinCount[de] ?? 0) + (win ? 1 : 0);
      deTotalCount[de] = (deTotalCount[de] ?? 0) + 1;
      deResults.putIfAbsent(de, () => []).add(win);

      totalWin += win ? 1 : 0;
      totalTest++;
    }
  }

  // =======================
  // HIỂN THỊ KẾT QUẢ
  // =======================
  final separator = List.filled(60, '=').join('');
  print(separator);
  print('BACKTEST: TOP $TOP_N_NUMBERS VỚI LOGIC ƯU TIÊN');
  print(separator);
  print('\n📊 TỔNG QUAN:');
  print('   Tổng số lần test: $totalTest');
  print('   Tổng số lần WIN: $totalWin');
  print('   Winrate tổng thể: ${totalTest > 0 ? (totalWin / totalTest * 100).toStringAsFixed(2) : 0}%');
  print('   Tổng số lần LOSE: ${totalTest - totalWin}');
  print('   Lose rate: ${totalTest > 0 ? ((totalTest - totalWin) / totalTest * 100).toStringAsFixed(2) : 0}%');

  // =======================
  // THỐNG KÊ THEO DE
  // =======================
  print('\n📈 THỐNG KÊ THEO DE:');
  
  // Tạo danh sách tất cả DE từ 00-99
  final allDeStats = <Map<String, dynamic>>[];
  for (int de = 0; de < 100; de++) {
    final total = deTotalCount[de] ?? 0;
    final win = deWinCount[de] ?? 0;
    final winrate = total > 0 ? (win / total * 100) : -1.0; // -1 để đánh dấu chưa có data
    
    // Tính maxLoseStreak
    final results = deResults[de] ?? [];
    int maxLoseStreak = 0;
    int currentLose = 0;
    for (final r in results) {
      if (!r) {
        currentLose++;
        maxLoseStreak = currentLose > maxLoseStreak ? currentLose : maxLoseStreak;
      } else {
        currentLose = 0;
      }
    }
    
    allDeStats.add({
      'de': de,
      'total': total,
      'win': win,
      'winrate': winrate,
      'maxLoseStreak': maxLoseStreak,
      'hasData': total > 0,
    });
  }

  // Sắp xếp: DE có data trước, sau đó sắp xếp theo winrate
  allDeStats.sort((a, b) {
    final hasDataA = a['hasData'] as bool;
    final hasDataB = b['hasData'] as bool;
    
    // DE có data trước, DE chưa có data sau
    if (hasDataA != hasDataB) {
      return hasDataB ? 1 : -1;
    }
    
    // Nếu cả 2 đều có data hoặc cả 2 đều chưa có data, sắp xếp theo winrate
    final winrateA = a['winrate'] as double;
    final winrateB = b['winrate'] as double;
    return winrateA.compareTo(winrateB);
  });

  // Chỉ lấy DE có data để hiển thị top/bottom
  final deStatsWithData = allDeStats.where((s) => s['hasData'] as bool).toList();
  
  print('\n🔴 TOP 10 DE XẤU NHẤT (Winrate thấp nhất, có data):');
  for (int i = 0; i < 10 && i < deStatsWithData.length; i++) {
    final stat = deStatsWithData[i];
    final winrate = stat['winrate'] as double;
    print('   DE ${stat['de']!.toString().padLeft(2, '0')}: Win ${stat['win']}/${stat['total']} = ${winrate.toStringAsFixed(1)}% | MaxLoseStreak: ${stat['maxLoseStreak']}');
  }

  print('\n🟢 TOP 10 DE TỐT NHẤT (Winrate cao nhất, có data):');
  for (int i = deStatsWithData.length - 1; i >= 0 && i >= deStatsWithData.length - 10; i--) {
    final stat = deStatsWithData[i];
    final winrate = stat['winrate'] as double;
    print('   DE ${stat['de']!.toString().padLeft(2, '0')}: Win ${stat['win']}/${stat['total']} = ${winrate.toStringAsFixed(1)}% | MaxLoseStreak: ${stat['maxLoseStreak']}');
  }

  // =======================
  // PHÂN TÍCH DE XẤU
  // =======================
  print('\n⚠️  DE XẤU (Winrate < 50% và total >= 8):');
  final badDe = deStatsWithData.where((s) => (s['winrate'] as double) < 50.0 && s['total']! >= 8).toList();
  if (badDe.isEmpty) {
    print('   Không có DE nào thỏa điều kiện');
  } else {
    for (final stat in badDe) {
      final winrate = stat['winrate'] as double;
      print('   DE ${stat['de']!.toString().padLeft(2, '0')}: Win ${stat['win']}/${stat['total']} = ${winrate.toStringAsFixed(1)}% | MaxLoseStreak: ${stat['maxLoseStreak']}');
    }
  }

  // =======================
  // PHÂN TÍCH DE RẤT XẤU
  // =======================
  print('\n🔴 DE RẤT XẤU (Winrate < 40% và total >= 8):');
  final veryBadDe = deStatsWithData.where((s) => (s['winrate'] as double) < 40.0 && s['total']! >= 8).toList();
  if (veryBadDe.isEmpty) {
    print('   Không có DE nào thỏa điều kiện');
  } else {
    for (final stat in veryBadDe) {
      final winrate = stat['winrate'] as double;
      print('   DE ${stat['de']!.toString().padLeft(2, '0')}: Win ${stat['win']}/${stat['total']} = ${winrate.toStringAsFixed(1)}% | MaxLoseStreak: ${stat['maxLoseStreak']}');
    }
  }

  // =======================
  // HIỂN THỊ TẤT CẢ DE (00-99)
  // =======================
  print('\n📋 TẤT CẢ DE (00-99):');
  
  // Sắp xếp lại theo số DE (00-99)
  allDeStats.sort((a, b) => (a['de'] as int).compareTo(b['de'] as int));
  
  for (final stat in allDeStats) {
    final de = stat['de'] as int;
    final hasData = stat['hasData'] as bool;
    
    if (hasData) {
      final total = stat['total'] as int;
      final win = stat['win'] as int;
      final winrate = stat['winrate'] as double;
      final maxLoseStreak = stat['maxLoseStreak'] as int;
      print('   DE ${de.toString().padLeft(2, '0')}: Win $win/$total = ${winrate.toStringAsFixed(1)}% | MaxLoseStreak: $maxLoseStreak');
    } else {
      print('   DE ${de.toString().padLeft(2, '0')}: Chưa có data');
    }
  }

  print('\n$separator');
}

/// =======================
/// PHÂN TÍCH CẦU
/// =======================
class CauAnalysis {
  final int lastOccurrenceDays;
  final int maxCauLength;
  final int maxCauPosition;
  final int minCauLength;
  final int minCauPosition;
  final int currentCauLength;
  final bool inCurrentCau;
  final int maxLoseStreak;
  final int minLoseStreak;
  final int currentLoseStreak;

  CauAnalysis({
    required this.lastOccurrenceDays,
    required this.maxCauLength,
    required this.maxCauPosition,
    required this.minCauLength,
    required this.minCauPosition,
    required this.currentCauLength,
    required this.inCurrentCau,
    required this.maxLoseStreak,
    required this.minLoseStreak,
    required this.currentLoseStreak,
  });
}

CauAnalysis analyzeCau(List<DataModel> sortedData, int de, int number, int currentIndex) {
  // Chỉ xét đến ngày hiện tại (currentIndex), không dùng dữ liệu tương lai
  final List<bool> occurrences = [];

  for (int i = 0; i < currentIndex && i < sortedData.length - 1; i++) {
    if (sortedData[i].de == de) {
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
      currentCauLength: 0,
      inCurrentCau: false,
      maxLoseStreak: 0,
      minLoseStreak: 0,
      currentLoseStreak: 0,
    );
  }

  // Tìm lần xuất hiện gần nhất
  int lastOccurrenceDays = -1;
  for (int i = occurrences.length - 1; i >= 0; i--) {
    if (occurrences[i]) {
      lastOccurrenceDays = occurrences.length - 1 - i + 1;
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

  // Tìm cầu hiện tại
  int currentCauLengthNow = 0;
  int currentCauPosition = 0;
  bool inCurrentCau = false;

  if (occurrences.isNotEmpty) {
    if (occurrences.last) {
      inCurrentCau = true;
      for (int i = occurrences.length - 1; i >= 0; i--) {
        if (occurrences[i]) {
          currentCauLengthNow++;
          currentCauPosition++;
        } else {
          break;
        }
      }
    }
  }

  // Tìm max và min cầu
  List<int> allCauLengths = List.from(cauLengths);
  if (inCurrentCau && currentCauLengthNow > 0) {
    allCauLengths.add(currentCauLengthNow);
  }

  int maxCauLength = allCauLengths.isNotEmpty ? allCauLengths.reduce(max) : 0;
  int minCauLength = allCauLengths.isNotEmpty ? allCauLengths.reduce(min) : 0;

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

  // Tính maxLoseStreak và minLoseStreak
  int maxLoseStreak = 0;
  int minLoseStreak = 0;
  List<int> loseStreaks = [];
  int currentLose = 0;
  for (final occ in occurrences) {
    if (!occ) {
      currentLose++;
    } else {
      if (currentLose > 0) {
        loseStreaks.add(currentLose);
        currentLose = 0;
      }
    }
  }
  if (currentLose > 0) {
    loseStreaks.add(currentLose);
  }
  
  if (loseStreaks.isNotEmpty) {
    maxLoseStreak = loseStreaks.reduce(max);
    minLoseStreak = loseStreaks.reduce(min);
  }

  // Tính currentLoseStreak
  int currentLoseStreakNow = 0;
  if (!inCurrentCau) {
    for (int i = occurrences.length - 1; i >= 0; i--) {
      if (!occurrences[i]) {
        currentLoseStreakNow++;
      } else {
        break;
      }
    }
  }

  return CauAnalysis(
    lastOccurrenceDays: lastOccurrenceDays,
    maxCauLength: maxCauLength,
    maxCauPosition: maxCauPosition,
    minCauLength: minCauLength,
    minCauPosition: minCauPosition,
    currentCauLength: currentCauLengthNow,
    inCurrentCau: inCurrentCau,
    maxLoseStreak: maxLoseStreak,
    minLoseStreak: minLoseStreak,
    currentLoseStreak: currentLoseStreakNow,
  );
}

/// =======================
/// LOAD CSV
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
