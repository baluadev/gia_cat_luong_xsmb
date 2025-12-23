import 'dart:io';
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
/// THỐNG KÊ CẦU CHO MỘT SỐ
/// =======================
class CauStat {
  final List<bool> history = []; // true = xuất hiện (W), false = không xuất hiện (L)
  int maxWinStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int currentLoseStreak = 0;
  int totalWins = 0;
  int totalDays = 0;

  void add(bool appeared) {
    history.add(appeared);
    totalDays++;
    if (appeared) {
      totalWins++;
      currentWinStreak++;
      currentLoseStreak = 0;
      if (currentWinStreak > maxWinStreak) {
        maxWinStreak = currentWinStreak;
      }
    } else {
      currentLoseStreak++;
      currentWinStreak = 0;
      if (currentLoseStreak > maxLoseStreak) {
        maxLoseStreak = currentLoseStreak;
      }
    }
  }

  String get cauString => history.map((e) => e ? 'W' : 'L').join('');
  double get winrate => totalDays > 0 ? (totalWins / totalDays * 100) : 0.0;
  
  String get currentState {
    if (history.isEmpty) return 'N/A';
    final last = history.last;
    final streak = last ? currentWinStreak : currentLoseStreak;
    return last ? 'WIN $streak' : 'LOSE $streak';
  }
}

void main() async {
  // Load và sort data theo thời gian
  final data = await loadDataModels('data.csv');
  
  final dataWithDate = data
      .map((d) => (
            model: d,
            dateTime: DateTime.parse(d.date),
          ))
      .toList();
  dataWithDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final sortedData = dataWithDate.map((e) => e.model).toList();

  // Thống kê cầu cho cả 3 số (91, 92 và 93)
  final cauBoth = CauStat();

  // Duyệt qua từng ngày và kiểm tra xem có ít nhất 1 trong 3 số (91, 92 hoặc 93) xuất hiện không
  for (final day in sortedData) {
    final othersSet = day.others.toSet();
    
    // Kiểm tra có ít nhất 1 trong 3 số (WIN nếu có 1 hoặc nhiều số, LOSE nếu không có số nào)
    final has91 = othersSet.contains(91);
    final has92 = othersSet.contains(92);
    final has93 = othersSet.contains(93);
    final atLeastOne = has91 || has92 || has93;
    cauBoth.add(atLeastOne);
  }

  // In kết quả thống kê
  print('📊 THỐNG KÊ CẦU SỐ 91, 92 VÀ 93 TRONG OTHERS');
  print('============================================================');
  print('  (W = có ít nhất 1 trong 3 số xuất hiện, L = không có số nào)');
  
  print('\n🎯 CẦU TỔNG (91, 92 VÀ 93):');
  print('  Chuỗi cầu: ${cauBoth.cauString}');
  print('  Hiện tại: ${cauBoth.currentState}');
  print('  ✅ Max WIN liên tiếp: ${cauBoth.maxWinStreak}');
  print('  ❌ Max LOSE liên tiếp: ${cauBoth.maxLoseStreak}');
  print('  Winrate: ${cauBoth.winrate.toStringAsFixed(2)}% (${cauBoth.totalWins}/${cauBoth.totalDays})');

  // Thống kê ngày gần nhất
  if (sortedData.isNotEmpty) {
    final latestDay = sortedData.last;
    final latestOthersSet = latestDay.others.toSet();
    final latestHas91 = latestOthersSet.contains(91);
    final latestHas92 = latestOthersSet.contains(92);
    final latestHas93 = latestOthersSet.contains(93);
    final latestAtLeastOne = latestHas91 || latestHas92 || latestHas93;

    print('\n📅 NGÀY GẦN NHẤT (${latestDay.date.split(' ').first}):');
    print('  Kết quả: ${latestAtLeastOne ? "✅ WIN (có ít nhất 1 số)" : "❌ LOSE (không có số nào)"}');
  }

  // =======================
  // THỐNG KÊ SỐ CÓ ĐẦU 9 (90-99) TRONG OTHERS
  // =======================
  final Map<int, int> firstNineCounts = {}; // Đếm số lần xuất hiện của các số 90-99
  final totalDays = sortedData.length;

  // Khởi tạo các số từ 90-99
  for (int i = 90; i <= 99; i++) {
    firstNineCounts[i] = 0;
  }

  // Đếm số lần xuất hiện qua các ngày
  for (final day in sortedData) {
    final othersSet = day.others.toSet();
    for (int i = 90; i <= 99; i++) {
      if (othersSet.contains(i)) {
        firstNineCounts[i] = (firstNineCounts[i] ?? 0) + 1;
      }
    }
  }

  // Sắp xếp theo số lần xuất hiện giảm dần
  final sortedFirstNine = firstNineCounts.entries.toList()
    ..sort((a, b) {
      if (b.value != a.value) {
        return b.value.compareTo(a.value);
      }
      return a.key.compareTo(b.key);
    });

  print('\n📊 THỐNG KÊ SỐ CÓ ĐẦU 9 (90-99) TRONG OTHERS:');
  print('============================================================');
  print('  Tổng số ngày: $totalDays');
  print('');
  
  for (final entry in sortedFirstNine) {
    final num = entry.key;
    final count = entry.value;
    final percentage = totalDays > 0 ? (count / totalDays * 100) : 0.0;
    print('  ${num.toString().padLeft(2, '0')}: $count/$totalDays (${percentage.toStringAsFixed(2)}%)');
  }

  // =======================
  // BÀI TEST SO SÁNH: TÌM CẶP SỐ CÓ CẦU LOSE NGẮN NHẤT (00-99)
  // =======================
  print('\n\n🔬 BÀI TEST SO SÁNH: TÌM CẶP SỐ CÓ CẦU LOSE NGẮN NHẤT (00-99)');
  print('============================================================');
  print('  Đang tính toán... (Có thể mất vài giây)');
  
  final List<int> allNumbers = List.generate(100, (i) => i); // 00-99
  final List<Map<String, dynamic>> pairStats = [];
  
  // Tạo tất cả các cặp số từ 00-99
  int totalPairs = 0;
  for (int i = 0; i < allNumbers.length; i++) {
    for (int j = i + 1; j < allNumbers.length; j++) {
      totalPairs++;
      if (totalPairs % 500 == 0) {
        print('  Đã xử lý: $totalPairs/4950 cặp...');
      }
      
      final num1 = allNumbers[i];
      final num2 = allNumbers[j];
      
      // Tính thống kê cầu cho cặp số này
      final cauPair = CauStat();
      
      for (final day in sortedData) {
        final othersSet = day.others.toSet();
        final hasNum1 = othersSet.contains(num1);
        final hasNum2 = othersSet.contains(num2);
        final atLeastOne = hasNum1 || hasNum2;
        cauPair.add(atLeastOne);
      }
      
      pairStats.add({
        'num1': num1,
        'num2': num2,
        'cauStat': cauPair,
        'maxLoseStreak': cauPair.maxLoseStreak,
        'maxWinStreak': cauPair.maxWinStreak,
        'winrate': cauPair.winrate,
        'totalWins': cauPair.totalWins,
        'totalDays': cauPair.totalDays,
        'currentState': cauPair.currentState,
      });
    }
  }
  
  // Sắp xếp theo max lose streak tăng dần (ngắn nhất trước)
  print('  Đang sắp xếp kết quả...');
  pairStats.sort((a, b) {
    // Ưu tiên max lose streak ngắn nhất
    if (a['maxLoseStreak'] != b['maxLoseStreak']) {
      return (a['maxLoseStreak'] as int).compareTo(b['maxLoseStreak'] as int);
    }
    // Nếu bằng nhau, ưu tiên winrate cao hơn
    if ((b['winrate'] as double) != (a['winrate'] as double)) {
      return (b['winrate'] as double).compareTo(a['winrate'] as double);
    }
    // Nếu vẫn bằng nhau, sắp xếp theo số
    if (a['num1'] != b['num1']) {
      return (a['num1'] as int).compareTo(b['num1'] as int);
    }
    return (a['num2'] as int).compareTo(b['num2'] as int);
  });
  
  print('  Tổng số cặp số được test: ${pairStats.length}');
  print('  (Tất cả các cặp từ 00-99)');
  print('');
  
  // Tìm min max lose streak
  final minMaxLoseStreak = pairStats.isNotEmpty ? pairStats[0]['maxLoseStreak'] as int : 0;
  final bestPairs = pairStats.where((p) => (p['maxLoseStreak'] as int) == minMaxLoseStreak).toList();
  
  // Hiển thị top 20 cặp có max lose streak ngắn nhất
  print('🏆 TOP 20 CẶP SỐ CÓ CẦU LOSE NGẮN NHẤT:');
  print('============================================================');
  print('  ${'Cặp số'.padRight(10)} | ${'Max LOSE'.padRight(10)} | ${'Max WIN'.padRight(10)} | ${'Winrate'.padRight(10)} | ${'Hiện tại'.padRight(15)}');
  print('  ${'-' * 10} | ${'-' * 10} | ${'-' * 10} | ${'-' * 10} | ${'-' * 15}');
  
  final topN = pairStats.length < 20 ? pairStats.length : 20;
  for (int i = 0; i < topN; i++) {
    final stat = pairStats[i];
    final num1 = stat['num1'] as int;
    final num2 = stat['num2'] as int;
    final maxLose = stat['maxLoseStreak'] as int;
    final maxWin = stat['maxWinStreak'] as int;
    final winrate = stat['winrate'] as double;
    final currentState = stat['currentState'] as String;
    
    final pairStr = '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}';
    print('  ${pairStr.padRight(10)} | ${maxLose.toString().padLeft(10)} | ${maxWin.toString().padLeft(10)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${currentState.padLeft(15)}');
  }
  
  // Hiển thị số lượng cặp có cùng max lose streak ngắn nhất
  if (bestPairs.isNotEmpty) {
    print('\n📊 TỔNG KẾT:');
    print('  Max LOSE ngắn nhất: $minMaxLoseStreak');
    print('  Số cặp có Max LOSE = $minMaxLoseStreak: ${bestPairs.length} cặp');
    if (bestPairs.length <= 50) {
      print('\n  Danh sách tất cả các cặp có Max LOSE = $minMaxLoseStreak:');
      for (final pair in bestPairs) {
        final num1 = pair['num1'] as int;
        final num2 = pair['num2'] as int;
        final winrate = pair['winrate'] as double;
        final pairStr = '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}';
        print('    $pairStr (Winrate: ${winrate.toStringAsFixed(2)}%)');
      }
    } else {
      print('  (Có quá nhiều cặp, chỉ hiển thị top 20 ở trên)');
    }
  }
  
  // Hiển thị chi tiết cặp tốt nhất
  if (pairStats.isNotEmpty) {
    final bestPair = pairStats[0];
    final bestNum1 = bestPair['num1'] as int;
    final bestNum2 = bestPair['num2'] as int;
    final bestCauStat = bestPair['cauStat'] as CauStat;
    
    print('\n🥇 CẶP SỐ TỐT NHẤT: ${bestNum1.toString().padLeft(2, '0')} - ${bestNum2.toString().padLeft(2, '0')}');
    print('============================================================');
    print('  Max LOSE liên tiếp: ${bestCauStat.maxLoseStreak} (ngắn nhất)');
    print('  Max WIN liên tiếp: ${bestCauStat.maxWinStreak}');
    print('  Winrate: ${bestCauStat.winrate.toStringAsFixed(2)}% (${bestCauStat.totalWins}/${bestCauStat.totalDays})');
    print('  Hiện tại: ${bestCauStat.currentState}');
    print('  Chuỗi cầu (50 ký tự cuối): ...${bestCauStat.cauString.length > 50 ? bestCauStat.cauString.substring(bestCauStat.cauString.length - 50) : bestCauStat.cauString}');
    
    // Thống kê ngày gần nhất cho cặp tốt nhất
    if (sortedData.isNotEmpty) {
      final latestDay = sortedData.last;
      final latestOthersSet = latestDay.others.toSet();
      final latestHasNum1 = latestOthersSet.contains(bestNum1);
      final latestHasNum2 = latestOthersSet.contains(bestNum2);
      final latestAtLeastOne = latestHasNum1 || latestHasNum2;
      
      print('\n  📅 NGÀY GẦN NHẤT (${latestDay.date.split(' ').first}):');
      print('    Số ${bestNum1.toString().padLeft(2, '0')}: ${latestHasNum1 ? "✅ CÓ" : "❌ KHÔNG"}');
      print('    Số ${bestNum2.toString().padLeft(2, '0')}: ${latestHasNum2 ? "✅ CÓ" : "❌ KHÔNG"}');
      print('    Kết quả: ${latestAtLeastOne ? "✅ WIN (có ít nhất 1 số)" : "❌ LOSE (không có số nào)"}');
    }
  }
  
  // Thống kê phân bố max lose streak
  final Map<int, int> loseStreakDistribution = {};
  for (final stat in pairStats) {
    final maxLose = stat['maxLoseStreak'] as int;
    loseStreakDistribution[maxLose] = (loseStreakDistribution[maxLose] ?? 0) + 1;
  }
  
  print('\n📊 PHÂN BỐ MAX LOSE STREAK:');
  print('============================================================');
  final sortedDistribution = loseStreakDistribution.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  
  for (final entry in sortedDistribution) {
    final streak = entry.key;
    final count = entry.value;
    final percentage = (count / pairStats.length * 100);
    print('  Max LOSE = $streak: $count cặp (${percentage.toStringAsFixed(1)}%)');
  }
}
