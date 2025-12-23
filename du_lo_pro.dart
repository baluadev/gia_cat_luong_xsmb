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
  
  /// Tính TopN các chuỗi lose dài nhất
  List<int> getTopNLoseStreaks(int n) {
    final List<int> loseStreaks = [];
    int currentLoseCount = 0;
    
    for (final appeared in history) {
      if (!appeared) {
        currentLoseCount++;
      } else {
        if (currentLoseCount > 0) {
          loseStreaks.add(currentLoseCount);
          currentLoseCount = 0;
        }
      }
    }
    // Xử lý trường hợp chuỗi lose ở cuối
    if (currentLoseCount > 0) {
      loseStreaks.add(currentLoseCount);
    }
    
    // Sắp xếp giảm dần và lấy top N
    loseStreaks.sort((a, b) => b.compareTo(a));
    return loseStreaks.take(n).toList();
  }
  
  /// Lấy danh sách các chuỗi lose theo thứ tự thời gian (từ gần nhất đến xa nhất)
  /// Mỗi phần tử là (độ dài, vị trí kết thúc trong history)
  List<({int length, int endIndex})> getLoseStreaksByTime() {
    final List<({int length, int endIndex})> streaks = [];
    int currentLoseCount = 0;
    
    for (int i = 0; i < history.length; i++) {
      if (!history[i]) {
        currentLoseCount++;
      } else {
        if (currentLoseCount > 0) {
          streaks.add((length: currentLoseCount, endIndex: i - 1));
          currentLoseCount = 0;
        }
      }
    }
    // Xử lý trường hợp chuỗi lose ở cuối (chưa kết thúc)
    if (currentLoseCount > 0) {
      streaks.add((length: currentLoseCount, endIndex: history.length - 1));
    }
    
    // Đảo ngược để có thứ tự từ gần nhất đến xa nhất
    return streaks.reversed.toList();
  }
  
  /// Tìm dây max lose gần nhất đã chạp đến (đã đạt được) trong topN (max1, max2, max3)
  /// Trả về thông tin về dây cầu đó: (maxLevel: 1, 2, hoặc 3, length: độ dài, daysAgo: số ngày trước)
  /// Trả về null nếu chưa chạp đến bất kỳ max nào
  ({int maxLevel, int length, int daysAgo})? getNearestMaxLoseReached() {
    if (history.isEmpty) return null;
    
    final top3Lose = getTopNLoseStreaks(3);
    if (top3Lose.isEmpty) return null;
    
    final max1 = top3Lose[0];
    final max2 = top3Lose.length > 1 ? top3Lose[1] : 0;
    final max3 = top3Lose.length > 2 ? top3Lose[2] : 0;
    
    // Kiểm tra chuỗi lose hiện tại (nếu đang lose)
    if (currentLoseStreak > 0) {
      if (currentLoseStreak >= max1) {
        // Đang trong hoặc đã vượt quá max1
        return (maxLevel: 1, length: currentLoseStreak, daysAgo: 0);
      } else if (max2 > 0 && currentLoseStreak >= max2) {
        // Đang trong hoặc đã vượt quá max2
        return (maxLevel: 2, length: currentLoseStreak, daysAgo: 0);
      } else if (max3 > 0 && currentLoseStreak >= max3) {
        // Đang trong hoặc đã vượt quá max3
        return (maxLevel: 3, length: currentLoseStreak, daysAgo: 0);
      }
    }
    
    // Nếu chuỗi lose hiện tại chưa chạp đến max nào, tìm chuỗi lose gần nhất đã kết thúc
    // Lấy danh sách các chuỗi lose theo thứ tự thời gian (từ gần nhất)
    final loseStreaksByTime = getLoseStreaksByTime();
    
    // Bỏ qua chuỗi lose đầu tiên nếu đó là chuỗi lose hiện tại (chưa kết thúc)
    final startIndex = (currentLoseStreak > 0 && loseStreaksByTime.isNotEmpty) ? 1 : 0;
    
    // Tìm chuỗi lose gần nhất đã kết thúc mà đã chạp đến (đã đạt được) max1, max2, hoặc max3
    for (int i = startIndex; i < loseStreaksByTime.length; i++) {
      final streak = loseStreaksByTime[i];
      // Kiểm tra xem chuỗi lose này có đạt được max nào không
      if (streak.length >= max1) {
        // Đã chạp đến max1
        final daysAgo = history.length - 1 - streak.endIndex;
        return (maxLevel: 1, length: streak.length, daysAgo: daysAgo);
      } else if (max2 > 0 && streak.length >= max2) {
        // Đã chạp đến max2
        final daysAgo = history.length - 1 - streak.endIndex;
        return (maxLevel: 2, length: streak.length, daysAgo: daysAgo);
      } else if (max3 > 0 && streak.length >= max3) {
        // Đã chạp đến max3
        final daysAgo = history.length - 1 - streak.endIndex;
        return (maxLevel: 3, length: streak.length, daysAgo: daysAgo);
      }
    }
    
    return null;
  }
  
  /// Tìm dây lose gần nhất (bất kỳ độ dài nào, không nhất thiết phải thuộc Max1, Max2, Max3)
  /// Trả về thông tin về dây lose đó: (length: độ dài, daysAgo: số ngày trước, isCurrent: có phải đang diễn ra không)
  /// Trả về null nếu không có dây lose nào
  ({int length, int daysAgo, bool isCurrent})? getNearestLoseStreak() {
    if (history.isEmpty) return null;
    
    // Kiểm tra chuỗi lose hiện tại (nếu đang lose)
    if (currentLoseStreak > 0) {
      return (length: currentLoseStreak, daysAgo: 0, isCurrent: true);
    }
    
    // Nếu không đang lose, tìm chuỗi lose gần nhất đã kết thúc
    final loseStreaksByTime = getLoseStreaksByTime();
    
    if (loseStreaksByTime.isEmpty) return null;
    
    // Lấy chuỗi lose gần nhất (đầu tiên trong danh sách đã được sắp xếp từ gần nhất)
    final nearestStreak = loseStreaksByTime.first;
    final daysAgo = history.length - 1 - nearestStreak.endIndex;
    
    return (length: nearestStreak.length, daysAgo: daysAgo, isCurrent: false);
  }
  
  /// Tìm ngày xuất hiện đầu tiên và gần nhất trong history
  /// Trả về (firstAppearIndex: vị trí xuất hiện đầu tiên, lastAppearIndex: vị trí xuất hiện gần nhất)
  /// Trả về null nếu chưa từng xuất hiện
  ({int firstAppearIndex, int lastAppearIndex})? getAppearIndices() {
    if (history.isEmpty) return null;
    
    int? firstAppearIndex;
    int? lastAppearIndex;
    
    for (int i = 0; i < history.length; i++) {
      if (history[i]) {
        if (firstAppearIndex == null) {
          firstAppearIndex = i;
        }
        lastAppearIndex = i;
      }
    }
    
    if (firstAppearIndex == null) return null;
    
    return (firstAppearIndex: firstAppearIndex, lastAppearIndex: lastAppearIndex!);
  }
  
  /// Tìm max lose hay lặp lại nhiều nhất (độ dài chuỗi lose nào xuất hiện nhiều lần nhất)
  /// Trả về (length: độ dài, count: số lần lặp lại) hoặc null nếu không có
  ({int length, int count})? getMostRepeatedLoseStreak() {
    if (history.isEmpty) return null;
    
    // Lấy tất cả các chuỗi lose
    final List<int> allLoseStreaks = [];
    int currentLoseCount = 0;
    
    for (final appeared in history) {
      if (!appeared) {
        currentLoseCount++;
      } else {
        if (currentLoseCount > 0) {
          allLoseStreaks.add(currentLoseCount);
          currentLoseCount = 0;
        }
      }
    }
    // Xử lý trường hợp chuỗi lose ở cuối
    if (currentLoseCount > 0) {
      allLoseStreaks.add(currentLoseCount);
    }
    
    if (allLoseStreaks.isEmpty) return null;
    
    // Đếm số lần xuất hiện của mỗi độ dài
    final Map<int, int> countMap = {};
    for (final length in allLoseStreaks) {
      countMap[length] = (countMap[length] ?? 0) + 1;
    }
    
    // Tìm độ dài có số lần xuất hiện nhiều nhất
    int maxCount = 0;
    int mostRepeatedLength = 0;
    
    for (final entry in countMap.entries) {
      if (entry.value > maxCount || (entry.value == maxCount && entry.key > mostRepeatedLength)) {
        maxCount = entry.value;
        mostRepeatedLength = entry.key;
      }
    }
    
    if (maxCount == 0) return null;
    
    return (length: mostRepeatedLength, count: maxCount);
  }
  
  /// Thống kê số cầu (chuỗi lose) có độ dài bằng Max1, Max2, Max3, Max4, Max5
  /// Trả về (max1Count: số cầu có độ dài = Max1, max2Count: số cầu có độ dài = Max2, max3Count: số cầu có độ dài = Max3, max4Count: số cầu có độ dài = Max4, max5Count: số cầu có độ dài = Max5, totalCount: tổng số cầu)
  ({int max1Count, int max2Count, int max3Count, int max4Count, int max5Count, int totalCount}) getMaxLoseRepeatStats() {
    if (history.isEmpty) return (max1Count: 0, max2Count: 0, max3Count: 0, max4Count: 0, max5Count: 0, totalCount: 0);
    
    final top5Lose = getTopNLoseStreaks(5);
    if (top5Lose.isEmpty) return (max1Count: 0, max2Count: 0, max3Count: 0, max4Count: 0, max5Count: 0, totalCount: 0);
    
    final max1 = top5Lose[0];
    final max2 = top5Lose.length > 1 ? top5Lose[1] : 0;
    final max3 = top5Lose.length > 2 ? top5Lose[2] : 0;
    final max4 = top5Lose.length > 3 ? top5Lose[3] : 0;
    final max5 = top5Lose.length > 4 ? top5Lose[4] : 0;
    
    // Lấy tất cả các chuỗi lose (cầu)
    final List<int> allLoseStreaks = [];
    int currentLoseCount = 0;
    
    for (final appeared in history) {
      if (!appeared) {
        currentLoseCount++;
      } else {
        if (currentLoseCount > 0) {
          allLoseStreaks.add(currentLoseCount);
          currentLoseCount = 0;
        }
      }
    }
    // Xử lý trường hợp chuỗi lose ở cuối
    if (currentLoseCount > 0) {
      allLoseStreaks.add(currentLoseCount);
    }
    
    final totalCount = allLoseStreaks.length;
    
    // Đếm số cầu có độ dài = Max1, Max2, Max3, Max4, Max5
    int max1Count = 0;
    int max2Count = 0;
    int max3Count = 0;
    int max4Count = 0;
    int max5Count = 0;
    
    for (final length in allLoseStreaks) {
      if (length == max1) {
        max1Count++;
      }
      if (max2 > 0 && length == max2) {
        max2Count++;
      }
      if (max3 > 0 && length == max3) {
        max3Count++;
      }
      if (max4 > 0 && length == max4) {
        max4Count++;
      }
      if (max5 > 0 && length == max5) {
        max5Count++;
      }
    }
    
    return (max1Count: max1Count, max2Count: max2Count, max3Count: max3Count, max4Count: max4Count, max5Count: max5Count, totalCount: totalCount);
  }
  
  /// Lấy lịch sử tất cả các lần chạm Max1, Max2, Max3
  /// Trả về danh sách các lần chạm: (maxLevel: 1, 2, hoặc 3, length: độ dài, endIndex: vị trí kết thúc trong history, daysAgo: số ngày trước)
  List<({int maxLevel, int length, int endIndex, int daysAgo})> getMaxHitHistory() {
    if (history.isEmpty) return [];
    
    // Lấy tất cả các max levels (lấy top 20 để đảm bảo có đủ)
    final allMaxLose = getTopNLoseStreaks(20);
    if (allMaxLose.isEmpty) return [];
    
    // Loại bỏ các giá trị trùng lặp và sắp xếp giảm dần
    final uniqueMaxLose = allMaxLose.toSet().toList()..sort((a, b) => b.compareTo(a));
    
    final List<({int maxLevel, int length, int endIndex, int daysAgo})> hits = [];
    
    // Lấy tất cả các chuỗi lose theo thời gian
    final loseStreaksByTime = getLoseStreaksByTime();
    
    // Duyệt qua từng chuỗi lose và kiểm tra xem có chạm Max nào không
    for (final streak in loseStreaksByTime) {
      // Tìm max level cao nhất mà streak này đạt được
      int? maxLevel;
      for (int i = 0; i < uniqueMaxLose.length; i++) {
        if (streak.length >= uniqueMaxLose[i]) {
          maxLevel = i + 1; // maxLevel bắt đầu từ 1 (MAX1, MAX2, ...)
          break; // Lấy max level cao nhất
        }
      }
      
      if (maxLevel != null) {
        final daysAgo = history.length - 1 - streak.endIndex;
        hits.add((maxLevel: maxLevel, length: streak.length, endIndex: streak.endIndex, daysAgo: daysAgo));
      }
    }
    
    // Sắp xếp theo thời gian (từ gần nhất đến xa nhất)
    hits.sort((a, b) => b.endIndex.compareTo(a.endIndex));
    
    return hits;
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

  // Thống kê cầu cho tất cả các số từ 00-99
  final Map<int, CauStat> numberStats = {};
  
  // Khởi tạo CauStat cho tất cả các số từ 00-99
  for (int i = 0; i <= 99; i++) {
    numberStats[i] = CauStat();
  }
  
  // Duyệt qua từng ngày và kiểm tra xem số nào xuất hiện trong others
  for (final day in sortedData) {
    final othersSet = day.others.toSet();
    
    // Với mỗi số từ 00-99, kiểm tra xem có xuất hiện không
    for (int num = 0; num <= 99; num++) {
      final appeared = othersSet.contains(num);
      numberStats[num]!.add(appeared);
    }
  }

  // Chuyển đổi thành list để sắp xếp
  final List<Map<String, dynamic>> statsList = [];
  for (int num = 0; num <= 99; num++) {
    final stat = numberStats[num]!;
    final top5Lose = stat.getTopNLoseStreaks(5);
    final nearestLoseStreak = stat.getNearestLoseStreak();
    final maxLoseRepeatStats = stat.getMaxLoseRepeatStats();
    statsList.add({
      'number': num,
      'cauStat': stat,
      'maxLoseStreak': stat.maxLoseStreak,
      'currentLoseStreak': stat.currentLoseStreak,
      'maxWinStreak': stat.maxWinStreak,
      'currentWinStreak': stat.currentWinStreak,
      'winrate': stat.winrate,
      'totalWins': stat.totalWins,
      'totalDays': stat.totalDays,
      'currentState': stat.currentState,
      'isCurrentlyLosing': stat.currentLoseStreak > 0,
      'max1': top5Lose.isNotEmpty ? top5Lose[0] : 0,
      'max2': top5Lose.length > 1 ? top5Lose[1] : 0,
      'max3': top5Lose.length > 2 ? top5Lose[2] : 0,
      'max4': top5Lose.length > 3 ? top5Lose[3] : 0,
      'max5': top5Lose.length > 4 ? top5Lose[4] : 0,
      'nearestLoseStreak': nearestLoseStreak,
      'maxLoseRepeatStats': maxLoseRepeatStats,
    });
  }

  // Sắp xếp theo max lose streak giảm dần (dài nhất trước), sau đó theo current lose streak
  statsList.sort((a, b) {
    // Ưu tiên max lose streak dài nhất
    if (a['maxLoseStreak'] != b['maxLoseStreak']) {
      return (b['maxLoseStreak'] as int).compareTo(a['maxLoseStreak'] as int);
    }
    // Nếu bằng nhau, ưu tiên current lose streak dài nhất
    if (a['currentLoseStreak'] != b['currentLoseStreak']) {
      return (b['currentLoseStreak'] as int).compareTo(a['currentLoseStreak'] as int);
    }
    // Nếu vẫn bằng nhau, sắp xếp theo số
    return (a['number'] as int).compareTo(b['number'] as int);
  });

  // Hiển thị kết quả
  print('📊 THỐNG KÊ CẦU TẤT CẢ CÁC SỐ (00-99) TRONG OTHERS');
  print('============================================================');
  print('  Tổng số ngày: ${sortedData.length}');
  print('');
  
  // Hiển thị tất cả các số, sắp xếp theo max lose streak
  print('📋 DANH SÁCH TẤT CẢ CÁC SỐ (Sắp xếp theo Max LOSE giảm dần):');
  print('============================================================');
  print('  ${'Số'.padRight(5)} | ${'Max LOSE'.padRight(10)} | ${'LOSE hiện tại'.padRight(15)} | ${'Max WIN'.padRight(10)} | ${'Winrate'.padRight(10)} | ${'Hiện tại'.padRight(15)}');
  print('  ${'-' * 5} | ${'-' * 10} | ${'-' * 15} | ${'-' * 10} | ${'-' * 10} | ${'-' * 15}');
  
  for (final stat in statsList) {
    final num = stat['number'] as int;
    final maxLose = stat['maxLoseStreak'] as int;
    final currentLose = stat['currentLoseStreak'] as int;
    final maxWin = stat['maxWinStreak'] as int;
    final winrate = stat['winrate'] as double;
    final currentState = stat['currentState'] as String;
    final isCurrentlyLosing = stat['isCurrentlyLosing'] as bool;
    
    // Highlight các số đang lose
    final numStr = num.toString().padLeft(2, '0');
    final currentLoseStr = currentLose > 0 ? currentLose.toString() : '-';
    final highlight = isCurrentlyLosing ? '⚠️ ' : '  ';
    
    print('  $highlight${numStr.padRight(3)} | ${maxLose.toString().padLeft(10)} | ${currentLoseStr.padLeft(15)} | ${maxWin.toString().padLeft(10)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${currentState.padLeft(15)}');
  }

  // Thống kê các số có max lose streak cao nhất
  print('\n\n🔴 TOP 20 SỐ CÓ MAX LOSE STREAK DÀI NHẤT:');
  print('============================================================');
  final top20MaxLose = statsList.take(20).toList();
  for (int i = 0; i < top20MaxLose.length; i++) {
    final stat = top20MaxLose[i];
    final num = stat['number'] as int;
    final maxLose = stat['maxLoseStreak'] as int;
    final currentLose = stat['currentLoseStreak'] as int;
    final winrate = stat['winrate'] as double;
    final currentState = stat['currentState'] as String;
    
    print('  ${(i + 1).toString().padLeft(2)}. Số ${num.toString().padLeft(2, '0')}: Max LOSE = $maxLose, LOSE hiện tại = ${currentLose > 0 ? currentLose : 0}, Winrate = ${winrate.toStringAsFixed(2)}%, ${currentState}');
  }

  // Thống kê các số đang lose hiện tại
  final currentlyLosing = statsList.where((s) => (s['isCurrentlyLosing'] as bool)).toList();
  currentlyLosing.sort((a, b) => (b['currentLoseStreak'] as int).compareTo(a['currentLoseStreak'] as int));
  
  print('\n\n⚠️  CÁC SỐ ĐANG LOSE HIỆN TẠI (Sắp xếp theo LOSE hiện tại giảm dần):');
  print('============================================================');
  if (currentlyLosing.isEmpty) {
    print('  Không có số nào đang lose!');
  } else {
    print('  ${'Số'.padRight(5)} | ${'LOSE hiện tại'.padRight(15)} | ${'Max LOSE'.padRight(10)} | ${'Winrate'.padRight(10)} | ${'Hiện tại'.padRight(15)}');
    print('  ${'-' * 5} | ${'-' * 15} | ${'-' * 10} | ${'-' * 10} | ${'-' * 15}');
    
    for (final stat in currentlyLosing) {
      final num = stat['number'] as int;
      final currentLose = stat['currentLoseStreak'] as int;
      final maxLose = stat['maxLoseStreak'] as int;
      final winrate = stat['winrate'] as double;
      final currentState = stat['currentState'] as String;
      
      final numStr = num.toString().padLeft(2, '0');
      print('  ${numStr.padRight(5)} | ${currentLose.toString().padLeft(15)} | ${maxLose.toString().padLeft(10)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${currentState.padLeft(15)}');
    }
  }

  // Thống kê TopN max lose (max1, max2, max3, max4, max5) và max lose hay lặp lại nhiều nhất cho tất cả các số từ 00-99
  print('\n\n🏆 TOPN MAX LOSE (MAX1, MAX2, MAX3, MAX4, MAX5) VÀ MAX LOSE HAY LẶP LẠI NHIỀU NHẤT CỦA TẤT CẢ CÁC SỐ (00-99):');
  print('============================================================');
  // Sắp xếp lại theo số tăng dần
  final allNumbersSorted = List<Map<String, dynamic>>.from(statsList);
  allNumbersSorted.sort((a, b) {
    // Ưu tiên sắp xếp theo số tăng dần (00, 01, 02, ...)
    return (a['number'] as int).compareTo(b['number'] as int);
  });
  
  print('  ${'Số'.padRight(5)} | ${'LOSE hiện tại'.padRight(15)} | ${'MAX1'.padRight(8)} | ${'MAX2'.padRight(8)} | ${'MAX3'.padRight(8)} | ${'MAX4'.padRight(8)} | ${'MAX5'.padRight(8)} | ${'Max lose lặp lại'.padRight(70)} | ${'Dây cầu gần nhất'.padRight(25)} | ${'Winrate'.padRight(10)}');
  print('  ${'-' * 5} | ${'-' * 15} | ${'-' * 8} | ${'-' * 8} | ${'-' * 8} | ${'-' * 8} | ${'-' * 8} | ${'-' * 70} | ${'-' * 25} | ${'-' * 10}');
  
  for (final stat in allNumbersSorted) {
    final num = stat['number'] as int;
    final currentLose = stat['currentLoseStreak'] as int;
    final max1 = stat['max1'] as int;
    final max2 = stat['max2'] as int;
    final max3 = stat['max3'] as int;
    final max4 = stat['max4'] as int;
    final max5 = stat['max5'] as int;
    final maxLoseRepeatStats = stat['maxLoseRepeatStats'] as ({int max1Count, int max2Count, int max3Count, int max4Count, int max5Count, int totalCount});
    final nearestLoseStreak = stat['nearestLoseStreak'] as ({int length, int daysAgo, bool isCurrent})?;
    final winrate = stat['winrate'] as double;
    
    final numStr = num.toString().padLeft(2, '0');
    final max1Str = max1 > 0 ? max1.toString() : '-';
    final max2Str = max2 > 0 ? max2.toString() : '-';
    final max3Str = max3 > 0 ? max3.toString() : '-';
    final max4Str = max4 > 0 ? max4.toString() : '-';
    final max5Str = max5 > 0 ? max5.toString() : '-';
    
    String repeatedStr;
    if (maxLoseRepeatStats.totalCount > 0) {
      final parts = <String>[];
      parts.add('Tổng: ${maxLoseRepeatStats.totalCount}');
      if (max1 > 0 && maxLoseRepeatStats.max1Count > 0) {
        final percentage = (maxLoseRepeatStats.max1Count / maxLoseRepeatStats.totalCount * 100).toStringAsFixed(1);
        parts.add('Max1: ${maxLoseRepeatStats.max1Count}($percentage%)');
      }
      if (max2 > 0 && maxLoseRepeatStats.max2Count > 0) {
        final percentage = (maxLoseRepeatStats.max2Count / maxLoseRepeatStats.totalCount * 100).toStringAsFixed(1);
        parts.add('Max2: ${maxLoseRepeatStats.max2Count}($percentage%)');
      }
      if (max3 > 0 && maxLoseRepeatStats.max3Count > 0) {
        final percentage = (maxLoseRepeatStats.max3Count / maxLoseRepeatStats.totalCount * 100).toStringAsFixed(1);
        parts.add('Max3: ${maxLoseRepeatStats.max3Count}($percentage%)');
      }
      if (max4 > 0 && maxLoseRepeatStats.max4Count > 0) {
        final percentage = (maxLoseRepeatStats.max4Count / maxLoseRepeatStats.totalCount * 100).toStringAsFixed(1);
        parts.add('Max4: ${maxLoseRepeatStats.max4Count}($percentage%)');
      }
      if (max5 > 0 && maxLoseRepeatStats.max5Count > 0) {
        final percentage = (maxLoseRepeatStats.max5Count / maxLoseRepeatStats.totalCount * 100).toStringAsFixed(1);
        parts.add('Max5: ${maxLoseRepeatStats.max5Count}($percentage%)');
      }
      repeatedStr = parts.join(', ');
    } else {
      repeatedStr = '-';
    }
    
    String cauStr;
    if (nearestLoseStreak != null) {
      if (nearestLoseStreak.isCurrent) {
        cauStr = 'LOSE ${nearestLoseStreak.length} - Đang trong';
      } else {
        cauStr = 'LOSE ${nearestLoseStreak.length} - ${nearestLoseStreak.daysAgo} ngày trước';
      }
    } else {
      cauStr = 'Chưa có dây LOSE';
    }
    
    final currentLoseStr = currentLose > 0 ? currentLose.toString() : '-';
    print('  ${numStr.padRight(5)} | ${currentLoseStr.padLeft(15)} | ${max1Str.padLeft(8)} | ${max2Str.padLeft(8)} | ${max3Str.padLeft(8)} | ${max4Str.padLeft(8)} | ${max5Str.padLeft(8)} | ${repeatedStr.padLeft(70)} | ${cauStr.padLeft(25)} | ${winrate.toStringAsFixed(2).padLeft(9)}%');
  }

  // Thống kê phân bố max lose streak
  final Map<int, int> maxLoseDistribution = {};
  for (final stat in statsList) {
    final maxLose = stat['maxLoseStreak'] as int;
    maxLoseDistribution[maxLose] = (maxLoseDistribution[maxLose] ?? 0) + 1;
  }
  
  print('\n\n📊 PHÂN BỐ MAX LOSE STREAK:');
  print('============================================================');
  final sortedDistribution = maxLoseDistribution.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  
  for (final entry in sortedDistribution) {
    final streak = entry.key;
    final count = entry.value;
    final percentage = (count / statsList.length * 100);
    print('  Max LOSE = ${streak.toString().padLeft(2)}: $count số (${percentage.toStringAsFixed(1)}%)');
  }

  // Thống kê cặp 2 số xuất hiện cùng ngày có max lose streak thấp nhất
  print('\n\n🔗 THỐNG KÊ CẶP 2 SỐ XUẤT HIỆN CÙNG NGÀY (Sắp xếp theo Max LOSE thấp nhất):');
  print('============================================================');
  
  // Tạo map để lưu thống kê cho mỗi cặp 2 số (chỉ tạo khi cặp xuất hiện lần đầu)
  final Map<String, CauStat> pair2Stats = {};
  final Set<String> allPair2Keys = {}; // Lưu tất cả các cặp đã từng xuất hiện
  final Map<String, int> pair2FirstAppearIndex = {}; // Lưu index trong sortedData của ngày đầu tiên cặp xuất hiện
  
  // Duyệt qua từng ngày và kiểm tra các cặp xuất hiện cùng nhau
  for (int dayIndex = 0; dayIndex < sortedData.length; dayIndex++) {
    final day = sortedData[dayIndex];
    // Lấy danh sách các số unique (không trùng lặp) để đảm bảo mỗi cặp chỉ được đếm 1 lần mỗi ngày
    final othersUnique = day.others.toSet().toList()..sort();
    
    // Set để lưu các cặp đã được thêm true trong ngày này (tránh trùng lặp)
    final Set<String> pairsAppearedToday = {};
    
    // Kiểm tra tất cả các cặp 2 số trong others unique của ngày đó
    for (int i = 0; i < othersUnique.length; i++) {
      for (int j = i + 1; j < othersUnique.length; j++) {
        final num1 = othersUnique[i];
        final num2 = othersUnique[j];
        
        // Đảm bảo 2 số khác nhau
        if (num1 != num2) {
          final pairKey = '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}';
          
          // Chỉ thêm true một lần cho mỗi cặp trong mỗi ngày
          if (!pairsAppearedToday.contains(pairKey)) {
            // Tạo CauStat nếu chưa có
            if (!pair2Stats.containsKey(pairKey)) {
              pair2Stats[pairKey] = CauStat();
              pair2FirstAppearIndex[pairKey] = dayIndex; // Lưu index trong sortedData của ngày đầu tiên
            }
            allPair2Keys.add(pairKey);
            pair2Stats[pairKey]!.add(true); // Xuất hiện cùng nhau
            pairsAppearedToday.add(pairKey);
          }
        }
      }
    }
    
    // Với tất cả các cặp đã từng xuất hiện (đã có trong pair2Stats) nhưng không xuất hiện trong ngày này, thêm false
    for (final pairKey in pair2Stats.keys) {
      // Nếu cặp này không có trong danh sách các cặp xuất hiện hôm nay, thêm false
      if (!pairsAppearedToday.contains(pairKey)) {
        pair2Stats[pairKey]!.add(false); // Không xuất hiện cùng nhau
      }
    }
  }
  
  // Chuyển đổi thành list và sắp xếp theo max lose streak thấp nhất
  final List<Map<String, dynamic>> pair2List = [];
  for (final entry in pair2Stats.entries) {
    final stat = entry.value;
    if (stat.totalDays > 0) { // Chỉ lấy các cặp đã có dữ liệu
      final nearestMaxLose = stat.getNearestMaxLoseReached();
      final maxHistory = stat.getMaxHitHistory();
      
      // Đếm số lần chạm Max1, Max2, Max3
      int max1HitCount = 0;
      int max2HitCount = 0;
      int max3HitCount = 0;
      
      for (final hit in maxHistory) {
        if (hit.maxLevel == 1) max1HitCount++;
        if (hit.maxLevel == 2) max2HitCount++;
        if (hit.maxLevel == 3) max3HitCount++;
      }
      
      final totalMaxHits = max1HitCount + max2HitCount + max3HitCount;
      
      pair2List.add({
        'pair': entry.key,
        'cauStat': stat,
        'currentLoseStreak': stat.currentLoseStreak,
        'maxLoseStreak': stat.maxLoseStreak,
        'totalWins': stat.totalWins,
        'winrate': stat.winrate,
        'cauString': stat.cauString,
        'currentState': stat.currentState,
        'nearestMaxLose': nearestMaxLose,
        'max1HitCount': max1HitCount,
        'totalMaxHits': totalMaxHits,
      });
    }
  }
  
  // Sắp xếp theo max lose streak tăng dần (thấp nhất trước)
  pair2List.sort((a, b) {
    final maxLoseA = a['maxLoseStreak'] as int;
    final maxLoseB = b['maxLoseStreak'] as int;
    if (maxLoseA != maxLoseB) {
      return maxLoseA.compareTo(maxLoseB);
    }
    // Nếu bằng nhau, sắp xếp theo current lose streak
    return (a['currentLoseStreak'] as int).compareTo(b['currentLoseStreak'] as int);
  });
  
  // Hiển thị top 30 cặp có max lose streak thấp nhất
  print('  ${'Cặp'.padRight(8)} | ${'LOSE hiện tại'.padRight(15)} | ${'Max LOSE'.padRight(10)} | ${'Số lần xuất hiện'.padRight(18)} | ${'Max1(lần/tổng)'.padRight(20)} | ${'Winrate'.padRight(10)} | ${'Dây cầu lose gần nhất'.padRight(25)} | ${'Cầu hiện tại'.padRight(20)}');
  print('  ${'-' * 8} | ${'-' * 15} | ${'-' * 10} | ${'-' * 18} | ${'-' * 20} | ${'-' * 10} | ${'-' * 25} | ${'-' * 20}');
  
  final top30Pairs2 = pair2List.take(30).toList();
  for (final pair in top30Pairs2) {
    final pairKey = pair['pair'] as String;
    final currentLose = pair['currentLoseStreak'] as int;
    final maxLose = pair['maxLoseStreak'] as int;
    final totalWins = pair['totalWins'] as int;
    final winrate = pair['winrate'] as double;
    final cauString = pair['cauString'] as String;
    final nearestMaxLose = pair['nearestMaxLose'] as ({int maxLevel, int length, int daysAgo})?;
    final max1HitCount = pair['max1HitCount'] as int;
    final totalMaxHits = pair['totalMaxHits'] as int;
    
    // Lấy 20 ký tự cuối cùng của cầu để hiển thị
    final cauDisplay = cauString.length > 20 ? '...${cauString.substring(cauString.length - 20)}' : cauString;
    
    String nearestStr;
    if (nearestMaxLose != null) {
      if (nearestMaxLose.daysAgo == 0) {
        nearestStr = 'MAX${nearestMaxLose.maxLevel} (${nearestMaxLose.length}) - Đang trong';
      } else {
        nearestStr = 'MAX${nearestMaxLose.maxLevel} (${nearestMaxLose.length}) - ${nearestMaxLose.daysAgo} ngày trước';
      }
    } else {
      nearestStr = 'Chưa chạp đến MAX';
    }
    
    String max1RatioStr;
    if (totalMaxHits > 0) {
      max1RatioStr = 'Max1($max1HitCount/$totalMaxHits)';
    } else {
      max1RatioStr = '-';
    }
    
    print('  ${pairKey.padRight(8)} | ${currentLose.toString().padLeft(15)} | ${maxLose.toString().padLeft(10)} | ${totalWins.toString().padLeft(18)} | ${max1RatioStr.padLeft(20)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${nearestStr.padLeft(25)} | ${cauDisplay.padLeft(20)}');
    
    // Debug cho tất cả các cặp trong top 30
    if (pair2Stats.containsKey(pairKey) && pair2FirstAppearIndex.containsKey(pairKey)) {
      final stat = pair2Stats[pairKey]!;
      final firstAppearDayIndex = pair2FirstAppearIndex[pairKey]!;
      final totalDays = stat.totalDays;
      final totalWinsDebug = stat.totalWins;
      
      // Tìm tất cả các ngày xuất hiện
      final List<String> appearDates = [];
      for (int i = 0; i < stat.history.length; i++) {
        if (stat.history[i]) {
          // Map history index sang sortedData index
          // firstAppearDayIndex là index trong sortedData của ngày đầu tiên cặp xuất hiện
          // history[0] tương ứng với sortedData[firstAppearDayIndex]
          // Vậy history[i] tương ứng với sortedData[firstAppearDayIndex + i]
          final sortedDataIndex = firstAppearDayIndex + i;
          if (sortedDataIndex < sortedData.length) {
            final date = sortedData[sortedDataIndex].date.split(' ').first;
            appearDates.add(date);
          }
        }
      }
      
      print('    [DEBUG $pairKey] Tổng số ngày: $totalDays, Số lần xuất hiện: $totalWinsDebug');
      print('    [DEBUG $pairKey] LOSE hiện tại: $currentLose, Max LOSE: $maxLose');
      print('    [DEBUG $pairKey] History length: ${stat.history.length}, Total days in data: ${sortedData.length}');
      print('    [DEBUG $pairKey] Tất cả các ngày xuất hiện (${appearDates.length} ngày): ${appearDates.join(', ')}');
      print('    [DEBUG $pairKey] Cầu 50 ký tự cuối: ${stat.cauString.length > 50 ? stat.cauString.substring(stat.cauString.length - 50) : stat.cauString}');
    }
  }

  // Thống kê cặp 3 số xuất hiện cùng ngày có max lose streak thấp nhất
  print('\n\n🔗 THỐNG KÊ CẶP 3 SỐ XUẤT HIỆN CÙNG NGÀY (Sắp xếp theo Max LOSE thấp nhất):');
  print('============================================================');
  
  // Tạo map để lưu thống kê cho mỗi cặp 3 số (chỉ tạo khi cặp xuất hiện lần đầu)
  final Map<String, CauStat> pair3Stats = {};
  final Set<String> allPair3Keys = {}; // Lưu tất cả các cặp đã từng xuất hiện
  final Map<String, int> pair3FirstAppearIndex = {}; // Lưu index trong sortedData của ngày đầu tiên cặp xuất hiện
  
  // Duyệt qua từng ngày và kiểm tra các cặp 3 số xuất hiện cùng nhau
  for (int dayIndex = 0; dayIndex < sortedData.length; dayIndex++) {
    final day = sortedData[dayIndex];
    // Lấy danh sách các số unique (không trùng lặp) để đảm bảo mỗi cặp chỉ được đếm 1 lần mỗi ngày
    final othersUnique = day.others.toSet().toList()..sort();
    
    // Set để lưu các cặp đã được thêm true trong ngày này (tránh trùng lặp)
    final Set<String> pairsAppearedToday = {};
    
    // Kiểm tra tất cả các cặp 3 số trong others unique của ngày đó
    for (int i = 0; i < othersUnique.length; i++) {
      for (int j = i + 1; j < othersUnique.length; j++) {
        for (int k = j + 1; k < othersUnique.length; k++) {
          final num1 = othersUnique[i];
          final num2 = othersUnique[j];
          final num3 = othersUnique[k];
          
          // Đảm bảo 3 số khác nhau
          if (num1 != num2 && num2 != num3 && num1 != num3) {
            // Sắp xếp để có key nhất quán
            final nums = [num1, num2, num3]..sort();
            final pairKey = '${nums[0].toString().padLeft(2, '0')}-${nums[1].toString().padLeft(2, '0')}-${nums[2].toString().padLeft(2, '0')}';
            
            // Chỉ thêm true một lần cho mỗi cặp trong mỗi ngày
            if (!pairsAppearedToday.contains(pairKey)) {
              // Tạo CauStat nếu chưa có
              if (!pair3Stats.containsKey(pairKey)) {
                pair3Stats[pairKey] = CauStat();
                pair3FirstAppearIndex[pairKey] = dayIndex; // Lưu index trong sortedData của ngày đầu tiên
              }
              allPair3Keys.add(pairKey);
              pair3Stats[pairKey]!.add(true); // Xuất hiện cùng nhau
              pairsAppearedToday.add(pairKey);
            }
          }
        }
      }
    }
    
    // Với tất cả các cặp đã từng xuất hiện (đã có trong pair3Stats) nhưng không xuất hiện trong ngày này, thêm false
    for (final pairKey in pair3Stats.keys) {
      // Nếu cặp này không có trong danh sách các cặp xuất hiện hôm nay, thêm false
      if (!pairsAppearedToday.contains(pairKey)) {
        pair3Stats[pairKey]!.add(false); // Không xuất hiện cùng nhau
      }
    }
  }
  
  // Chuyển đổi thành list và sắp xếp theo max lose streak thấp nhất
  final List<Map<String, dynamic>> pair3List = [];
  for (final entry in pair3Stats.entries) {
    final stat = entry.value;
    if (stat.totalDays > 0) { // Chỉ lấy các cặp đã có dữ liệu
      final nearestMaxLose = stat.getNearestMaxLoseReached();
      pair3List.add({
        'pair': entry.key,
        'cauStat': stat,
        'currentLoseStreak': stat.currentLoseStreak,
        'maxLoseStreak': stat.maxLoseStreak,
        'totalWins': stat.totalWins,
        'winrate': stat.winrate,
        'cauString': stat.cauString,
        'currentState': stat.currentState,
        'nearestMaxLose': nearestMaxLose,
      });
    }
  }
  
  // Sắp xếp theo max lose streak tăng dần (thấp nhất trước)
  pair3List.sort((a, b) {
    final maxLoseA = a['maxLoseStreak'] as int;
    final maxLoseB = b['maxLoseStreak'] as int;
    if (maxLoseA != maxLoseB) {
      return maxLoseA.compareTo(maxLoseB);
    }
    // Nếu bằng nhau, sắp xếp theo current lose streak
    return (a['currentLoseStreak'] as int).compareTo(b['currentLoseStreak'] as int);
  });
  
  // Hiển thị top 30 cặp có max lose streak thấp nhất
  print('  ${'Cặp'.padRight(12)} | ${'LOSE hiện tại'.padRight(15)} | ${'Max LOSE'.padRight(10)} | ${'Số lần xuất hiện'.padRight(18)} | ${'Winrate'.padRight(10)} | ${'Dây cầu lose gần nhất'.padRight(25)} | ${'Cầu hiện tại'.padRight(20)}');
  print('  ${'-' * 12} | ${'-' * 15} | ${'-' * 10} | ${'-' * 18} | ${'-' * 10} | ${'-' * 25} | ${'-' * 20}');
  
  final top30Pairs3 = pair3List.take(30).toList();
  for (final pair in top30Pairs3) {
    final pairKey = pair['pair'] as String;
    final currentLose = pair['currentLoseStreak'] as int;
    final maxLose = pair['maxLoseStreak'] as int;
    final totalWins = pair['totalWins'] as int;
    final winrate = pair['winrate'] as double;
    final cauString = pair['cauString'] as String;
    final nearestMaxLose = pair['nearestMaxLose'] as ({int maxLevel, int length, int daysAgo})?;
    
    // Lấy 20 ký tự cuối cùng của cầu để hiển thị
    final cauDisplay = cauString.length > 20 ? '...${cauString.substring(cauString.length - 20)}' : cauString;
    
    String nearestStr;
    if (nearestMaxLose != null) {
      if (nearestMaxLose.daysAgo == 0) {
        nearestStr = 'MAX${nearestMaxLose.maxLevel} (${nearestMaxLose.length}) - Đang trong';
      } else {
        nearestStr = 'MAX${nearestMaxLose.maxLevel} (${nearestMaxLose.length}) - ${nearestMaxLose.daysAgo} ngày trước';
      }
    } else {
      nearestStr = 'Chưa chạp đến MAX';
    }
    
    print('  ${pairKey.padRight(12)} | ${currentLose.toString().padLeft(15)} | ${maxLose.toString().padLeft(10)} | ${totalWins.toString().padLeft(18)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${nearestStr.padLeft(25)} | ${cauDisplay.padLeft(20)}');
    
    // Debug cho tất cả các cặp trong top 30
    if (pair3Stats.containsKey(pairKey) && pair3FirstAppearIndex.containsKey(pairKey)) {
      final stat = pair3Stats[pairKey]!;
      final firstAppearDayIndex = pair3FirstAppearIndex[pairKey]!;
      final totalDays = stat.totalDays;
      final totalWinsDebug = stat.totalWins;
      
      // Tìm tất cả các ngày xuất hiện
      final List<String> appearDates = [];
      for (int i = 0; i < stat.history.length; i++) {
        if (stat.history[i]) {
          // Map history index sang sortedData index
          // firstAppearDayIndex là index trong sortedData của ngày đầu tiên cặp xuất hiện
          // history[0] tương ứng với sortedData[firstAppearDayIndex]
          // Vậy history[i] tương ứng với sortedData[firstAppearDayIndex + i]
          final sortedDataIndex = firstAppearDayIndex + i;
          if (sortedDataIndex < sortedData.length) {
            final date = sortedData[sortedDataIndex].date.split(' ').first;
            appearDates.add(date);
          }
        }
      }
      
      print('    [DEBUG $pairKey] Tổng số ngày: $totalDays, Số lần xuất hiện: $totalWinsDebug');
      print('    [DEBUG $pairKey] LOSE hiện tại: $currentLose, Max LOSE: $maxLose');
      print('    [DEBUG $pairKey] History length: ${stat.history.length}, Total days in data: ${sortedData.length}');
      print('    [DEBUG $pairKey] Tất cả các ngày xuất hiện (${appearDates.length} ngày): ${appearDates.join(', ')}');
      print('    [DEBUG $pairKey] Cầu 50 ký tự cuối: ${stat.cauString.length > 50 ? stat.cauString.substring(stat.cauString.length - 50) : stat.cauString}');
    }
  }

  // Thống kê ngày gần nhất
  if (sortedData.isNotEmpty) {
    final latestDay = sortedData.last;
    
    print('\n\n📅 NGÀY GẦN NHẤT (${latestDay.date.split(' ').first}):');
    print('============================================================');
    print('  Các số xuất hiện trong others: ${latestDay.others.map((n) => n.toString().padLeft(2, '0')).join(', ')}');
    print('  Tổng số: ${latestDay.others.length} số');
  }

  // Thống kê các cặp 2 số có LOSE hiện tại đã chạm/vượt MAX1
  print('\n\n🔴 CÁC CẶP 2 SỐ ĐÃ CHẠM MAX1 (Sắp xếp theo số lần chạm MAX1):');
  print('============================================================');
  
  final List<Map<String, dynamic>> hitMaxPairs2 = [];
  for (final entry in pair2Stats.entries) {
    final stat = entry.value;
    if (stat.totalDays > 0 && stat.currentLoseStreak > 0) {
      final top3Lose = stat.getTopNLoseStreaks(3);
      if (top3Lose.isNotEmpty) {
        final max1 = top3Lose[0];
        final currentLose = stat.currentLoseStreak;
        
        // Chỉ kiểm tra MAX1
        if (currentLose >= max1) {
          final exceedBy = currentLose - max1;
          
          // Chỉ thêm các cặp có vượt quá (exceedBy > 0)
          if (exceedBy > 0) {
            // Đếm số lần chạm MAX1 từ lịch sử
            final maxHistory = stat.getMaxHitHistory();
            final max1HitCount = maxHistory.where((hit) => hit.maxLevel == 1).length;
            
            hitMaxPairs2.add({
              'pair': entry.key,
              'currentLose': currentLose,
              'max1': max1,
              'exceedBy': exceedBy,
              'winrate': stat.winrate,
              'max1HitCount': max1HitCount,
            });
          }
        }
      }
    }
  }
  
  // Sắp xếp theo số lần chạm MAX1 giảm dần (nhiều nhất trước)
  hitMaxPairs2.sort((a, b) {
    final countA = a['max1HitCount'] as int;
    final countB = b['max1HitCount'] as int;
    if (countA != countB) {
      return countB.compareTo(countA); // Nhiều nhất trước
    }
    // Nếu bằng nhau, sắp xếp theo currentLose giảm dần
    return (b['currentLose'] as int).compareTo(a['currentLose'] as int);
  });
  
  if (hitMaxPairs2.isEmpty) {
    print('  Không có cặp 2 số nào có LOSE hiện tại vượt quá MAX1');
  } else {
    print('  ${'Cặp'.padRight(8)} | ${'Số lần chạm MAX1'.padRight(18)} | ${'LOSE hiện tại'.padRight(15)} | ${'Vượt quá'.padRight(10)} | ${'MAX1'.padRight(8)} | ${'Winrate'.padRight(10)}');
    print('  ${'-' * 8} | ${'-' * 18} | ${'-' * 15} | ${'-' * 10} | ${'-' * 8} | ${'-' * 10}');
    
    final top30HitMax2 = hitMaxPairs2.take(30).toList();
    for (final pair in top30HitMax2) {
      final pairKey = pair['pair'] as String;
      final currentLose = pair['currentLose'] as int;
      final exceedBy = pair['exceedBy'] as int;
      final max1 = pair['max1'] as int;
      final winrate = pair['winrate'] as double;
      final max1HitCount = pair['max1HitCount'] as int;
      
      final exceedStr = '+$exceedBy'; // exceedBy luôn > 0 vì chỉ lấy các cặp có currentLose > max1
      print('  ${pairKey.padRight(8)} | ${max1HitCount.toString().padLeft(18)} | ${currentLose.toString().padLeft(15)} | ${exceedStr.padLeft(10)} | ${max1.toString().padLeft(8)} | ${winrate.toStringAsFixed(2).padLeft(9)}%');
    }
  }

  // Thống kê các cặp 3 số có LOSE hiện tại đã chạm/vượt MAX1
  print('\n\n🔴 CÁC CẶP 3 SỐ ĐÃ CHẠM MAX1 (Sắp xếp theo số lần chạm MAX1):');
  print('============================================================');
  
  final List<Map<String, dynamic>> hitMaxPairs3 = [];
  for (final entry in pair3Stats.entries) {
    final stat = entry.value;
    if (stat.totalDays > 0 && stat.currentLoseStreak > 0) {
      final top3Lose = stat.getTopNLoseStreaks(3);
      if (top3Lose.isNotEmpty) {
        final max1 = top3Lose[0];
        final currentLose = stat.currentLoseStreak;
        
        // Chỉ kiểm tra MAX1
        if (currentLose >= max1) {
          final exceedBy = currentLose - max1;
          
          // Chỉ thêm các cặp có vượt quá (exceedBy > 0)
          if (exceedBy > 0) {
            // Đếm số lần chạm MAX1 từ lịch sử
            final maxHistory = stat.getMaxHitHistory();
            final max1HitCount = maxHistory.where((hit) => hit.maxLevel == 1).length;
            
            hitMaxPairs3.add({
              'pair': entry.key,
              'currentLose': currentLose,
              'max1': max1,
              'exceedBy': exceedBy,
              'winrate': stat.winrate,
              'max1HitCount': max1HitCount,
            });
          }
        }
      }
    }
  }
  
  // Sắp xếp theo số lần chạm MAX1 giảm dần (nhiều nhất trước)
  hitMaxPairs3.sort((a, b) {
    final countA = a['max1HitCount'] as int;
    final countB = b['max1HitCount'] as int;
    if (countA != countB) {
      return countB.compareTo(countA); // Nhiều nhất trước
    }
    // Nếu bằng nhau, sắp xếp theo currentLose giảm dần
    return (b['currentLose'] as int).compareTo(a['currentLose'] as int);
  });
  
  if (hitMaxPairs3.isEmpty) {
    print('  Không có cặp 3 số nào có LOSE hiện tại vượt quá MAX1');
  } else {
    print('  ${'Cặp'.padRight(12)} | ${'Số lần chạm MAX1'.padRight(18)} | ${'LOSE hiện tại'.padRight(15)} | ${'Vượt quá'.padRight(10)} | ${'MAX1'.padRight(8)} | ${'Winrate'.padRight(10)}');
    print('  ${'-' * 12} | ${'-' * 18} | ${'-' * 15} | ${'-' * 10} | ${'-' * 8} | ${'-' * 10}');
    
    final top30HitMax3 = hitMaxPairs3.take(30).toList();
    for (final pair in top30HitMax3) {
      final pairKey = pair['pair'] as String;
      final currentLose = pair['currentLose'] as int;
      final exceedBy = pair['exceedBy'] as int;
      final max1 = pair['max1'] as int;
      final winrate = pair['winrate'] as double;
      final max1HitCount = pair['max1HitCount'] as int;
      
      final exceedStr = '+$exceedBy'; // exceedBy luôn > 0 vì chỉ lấy các cặp có currentLose > max1
      print('  ${pairKey.padRight(12)} | ${max1HitCount.toString().padLeft(18)} | ${currentLose.toString().padLeft(15)} | ${exceedStr.padLeft(10)} | ${max1.toString().padLeft(8)} | ${winrate.toStringAsFixed(2).padLeft(9)}%');
      
      // Debug cho cặp 36-39-58
      if (pairKey == '36-39-58') {
        if (pair3Stats.containsKey(pairKey)) {
          final stat = pair3Stats[pairKey]!;
          final appearIndices = stat.getAppearIndices();
          if (appearIndices != null) {
            final firstAppearDayIndex = appearIndices.firstAppearIndex;
            final lastAppearDayIndex = appearIndices.lastAppearIndex;
            final firstAppearDate = firstAppearDayIndex < sortedData.length 
                ? sortedData[firstAppearDayIndex].date.split(' ').first 
                : 'N/A';
            final lastAppearDate = lastAppearDayIndex < sortedData.length 
                ? sortedData[lastAppearDayIndex].date.split(' ').first 
                : 'N/A';
            final totalDays = stat.totalDays;
            final totalWins = stat.totalWins;
            
            // Tính ngày dự kiến nếu lose streak = 181
            final expectedLastAppearIndex = sortedData.length - 1 - currentLose;
            final expectedLastAppearDate = expectedLastAppearIndex >= 0 && expectedLastAppearIndex < sortedData.length
                ? sortedData[expectedLastAppearIndex].date.split(' ').first
                : 'N/A';
            
            print('    [DEBUG 36-39-58] Tổng số ngày: $totalDays, Số lần xuất hiện: $totalWins');
            print('    [DEBUG 36-39-58] Ngày xuất hiện đầu tiên (index $firstAppearDayIndex): $firstAppearDate');
            print('    [DEBUG 36-39-58] Ngày xuất hiện gần nhất (index $lastAppearDayIndex): $lastAppearDate');
            print('    [DEBUG 36-39-58] Ngày dự kiến nếu LOSE=$currentLose (index $expectedLastAppearIndex): $expectedLastAppearDate');
            print('    [DEBUG 36-39-58] LOSE hiện tại: $currentLose, MAX1: $max1');
            print('    [DEBUG 36-39-58] History length: ${stat.history.length}, Total days in data: ${sortedData.length}');
            print('    [DEBUG 36-39-58] Cầu 50 ký tự cuối: ${stat.cauString.length > 50 ? stat.cauString.substring(stat.cauString.length - 50) : stat.cauString}');
          }
        }
      }
    }
  }

  // Nhập và hiển thị lịch sử chạm Max của cặp
  print('\n\n🔍 TRA CỨU LỊCH SỬ CHẠM MAX CỦA CẶP:');
  print('============================================================');
  print('  Nhập cặp số (ví dụ: 01-23 cho cặp 2 số, hoặc 01-23-45 cho cặp 3 số):');
  print('  Nhấn Enter để bỏ qua, hoặc nhập "exit" để thoát');
  
  final input = stdin.readLineSync()?.trim() ?? '';
  
  if (input.isNotEmpty && input.toLowerCase() != 'exit') {
    final parts = input.split('-');
    
    if (parts.length == 2) {
      // Cặp 2 số
      try {
        final num1 = int.parse(parts[0]);
        final num2 = int.parse(parts[1]);
        final pairKey = num1 < num2 
            ? '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}'
            : '${num2.toString().padLeft(2, '0')}-${num1.toString().padLeft(2, '0')}';
        
        if (pair2Stats.containsKey(pairKey)) {
          final stat = pair2Stats[pairKey]!;
          final maxHistory = stat.getMaxHitHistory();
          final top10Lose = stat.getTopNLoseStreaks(10);
          
          print('\n  📊 LỊCH SỬ CHẠM MAX CỦA CẶP 2 SỐ: $pairKey');
          print('  ============================================================');
          print('  Tổng số ngày theo dõi: ${stat.totalDays}');
          print('  Số lần xuất hiện (W): ${stat.totalWins}');
          print('  Số lần không xuất hiện (L): ${stat.totalDays - stat.totalWins}');
          
          // Hiển thị top 10 max LOSE
          final maxLoseStr = top10Lose.asMap().entries.map((e) => 'MAX${e.key + 1} = ${e.value}').join(', ');
          print('  Max LOSE: $maxLoseStr');
          
          print('  LOSE hiện tại: ${stat.currentLoseStreak}');
          print('  Winrate: ${stat.winrate.toStringAsFixed(2)}%');
          print('');
          
          if (maxHistory.isEmpty) {
            print('  Chưa có lần nào chạm MAX');
          } else {
            print('  📈 CÁC LẦN CHẠM MAX (${maxHistory.length} lần):');
            print('  ${'Lần'.padRight(5)} | ${'Max Level'.padRight(12)} | ${'Độ dài'.padRight(10)} | ${'Số ngày trước'.padRight(15)} | ${'Ngày'.padRight(12)}');
            print('  ${'-' * 5} | ${'-' * 12} | ${'-' * 10} | ${'-' * 15} | ${'-' * 12}');
            
            for (int i = 0; i < maxHistory.length; i++) {
              final hit = maxHistory[i];
              final dayIndex = sortedData.length - 1 - hit.daysAgo;
              final dateStr = dayIndex >= 0 && dayIndex < sortedData.length 
                  ? sortedData[dayIndex].date.split(' ').first 
                  : 'N/A';
              
              print('  ${(i + 1).toString().padLeft(5)} | MAX${hit.maxLevel}'.padRight(12) + ' | ${hit.length.toString().padLeft(10)} | ${hit.daysAgo.toString().padLeft(15)} | ${dateStr.padLeft(12)}');
            }
          }
          
          // Hiển thị một số lần xuất hiện gần nhất để kiểm tra
          print('');
          print('  📋 MỘT SỐ LẦN XUẤT HIỆN GẦN NHẤT (để kiểm tra):');
          final cauString = stat.cauString;
          if (cauString.isNotEmpty) {
            final last30 = cauString.length > 30 ? cauString.substring(cauString.length - 30) : cauString;
            print('  Cầu 30 ngày gần nhất: $last30');
            print('  (W = xuất hiện, L = không xuất hiện)');
            
            // Đếm số lần W trong 30 ngày gần nhất
            final wCount = last30.split('').where((c) => c == 'W').length;
            print('  Số lần xuất hiện trong 30 ngày gần nhất: $wCount');
          }
        } else {
          print('  ❌ Không tìm thấy cặp 2 số: $pairKey');
        }
      } catch (e) {
        print('  ❌ Định dạng không hợp lệ. Vui lòng nhập theo định dạng: 01-23');
      }
    } else if (parts.length == 3) {
      // Cặp 3 số
      try {
        final num1 = int.parse(parts[0]);
        final num2 = int.parse(parts[1]);
        final num3 = int.parse(parts[2]);
        
        final nums = [num1, num2, num3]..sort();
        final pairKey = '${nums[0].toString().padLeft(2, '0')}-${nums[1].toString().padLeft(2, '0')}-${nums[2].toString().padLeft(2, '0')}';
        
        if (pair3Stats.containsKey(pairKey)) {
          final stat = pair3Stats[pairKey]!;
          final maxHistory = stat.getMaxHitHistory();
          final top10Lose = stat.getTopNLoseStreaks(10);
          
          print('\n  📊 LỊCH SỬ CHẠM MAX CỦA CẶP 3 SỐ: $pairKey');
          print('  ============================================================');
          print('  Tổng số ngày theo dõi: ${stat.totalDays}');
          print('  Số lần xuất hiện (W): ${stat.totalWins}');
          print('  Số lần không xuất hiện (L): ${stat.totalDays - stat.totalWins}');
          
          // Hiển thị top 10 max LOSE
          final maxLoseStr = top10Lose.asMap().entries.map((e) => 'MAX${e.key + 1} = ${e.value}').join(', ');
          print('  Max LOSE: $maxLoseStr');
          
          print('  LOSE hiện tại: ${stat.currentLoseStreak}');
          print('  Winrate: ${stat.winrate.toStringAsFixed(2)}%');
          print('');
          
          if (maxHistory.isEmpty) {
            print('  Chưa có lần nào chạm MAX');
          } else {
            print('  📈 CÁC LẦN CHẠM MAX (${maxHistory.length} lần):');
            print('  ${'Lần'.padRight(5)} | ${'Max Level'.padRight(12)} | ${'Độ dài'.padRight(10)} | ${'Số ngày trước'.padRight(15)} | ${'Ngày'.padRight(12)}');
            print('  ${'-' * 5} | ${'-' * 12} | ${'-' * 10} | ${'-' * 15} | ${'-' * 12}');
            
            for (int i = 0; i < maxHistory.length; i++) {
              final hit = maxHistory[i];
              final dayIndex = sortedData.length - 1 - hit.daysAgo;
              final dateStr = dayIndex >= 0 && dayIndex < sortedData.length 
                  ? sortedData[dayIndex].date.split(' ').first 
                  : 'N/A';
              
              print('  ${(i + 1).toString().padLeft(5)} | MAX${hit.maxLevel}'.padRight(12) + ' | ${hit.length.toString().padLeft(10)} | ${hit.daysAgo.toString().padLeft(15)} | ${dateStr.padLeft(12)}');
            }
          }
          
          // Hiển thị một số lần xuất hiện gần nhất để kiểm tra
          print('');
          print('  📋 MỘT SỐ LẦN XUẤT HIỆN GẦN NHẤT (để kiểm tra):');
          final cauString = stat.cauString;
          if (cauString.isNotEmpty) {
            final last30 = cauString.length > 30 ? cauString.substring(cauString.length - 30) : cauString;
            print('  Cầu 30 ngày gần nhất: $last30');
            print('  (W = xuất hiện, L = không xuất hiện)');
            
            // Đếm số lần W trong 30 ngày gần nhất
            final wCount = last30.split('').where((c) => c == 'W').length;
            print('  Số lần xuất hiện trong 30 ngày gần nhất: $wCount');
          }
        } else {
          print('  ❌ Không tìm thấy cặp 3 số: $pairKey');
        }
      } catch (e) {
        print('  ❌ Định dạng không hợp lệ. Vui lòng nhập theo định dạng: 01-23-45');
      }
    } else {
      print('  ❌ Định dạng không hợp lệ. Vui lòng nhập cặp 2 số (01-23) hoặc cặp 3 số (01-23-45)');
    }
  }
}