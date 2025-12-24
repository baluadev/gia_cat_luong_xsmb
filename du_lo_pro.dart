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
  
  // Chuyển đổi thành list và tính toán các thống kê
  final List<Map<String, dynamic>> pair2List = [];
  for (final entry in pair2Stats.entries) {
    final stat = entry.value;
    if (stat.totalDays > 0) { // Chỉ lấy các cặp đã có dữ liệu
      final maxHistory = stat.getMaxHitHistory();
      
      // Đếm số lần xuất hiện của mỗi max level
      final Map<int, int> maxLevelHitCount = {}; // Map<maxLevel, count>
      
      for (final hit in maxHistory) {
        maxLevelHitCount[hit.maxLevel] = (maxLevelHitCount[hit.maxLevel] ?? 0) + 1;
      }
      
      // Lấy top 3 max levels có số lần xuất hiện nhiều nhất
      final top3MaxHits = maxLevelHitCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3MaxHitsList = top3MaxHits.take(3).toList();
      
      // Tính độ dài trung bình của mỗi max level từ maxHistory (thay vì lấy từ topNLose)
      final Map<int, int> maxLevelLength = {}; // Map<maxLevel, averageLength>
      for (final level in maxLevelHitCount.keys) {
        // Lấy tất cả các lần chạm max của level này
        final hitsForLevel = maxHistory.where((hit) => hit.maxLevel == level).toList();
        if (hitsForLevel.isNotEmpty) {
          // Tính độ dài trung bình (làm tròn)
          final totalLength = hitsForLevel.fold<int>(0, (sum, hit) => sum + hit.length);
          final avgLength = (totalLength / hitsForLevel.length).round();
          maxLevelLength[level] = avgLength;
        }
      }
      
      // Tính khoảng cách giữa currentLose và maxLose (để sắp xếp)
      final distanceToMax = (stat.currentLoseStreak - stat.maxLoseStreak).abs();
      
      // Tìm lần chạm max gần nhất (daysAgo nhỏ nhất)
      final nearestMaxHit = maxHistory.isNotEmpty 
          ? maxHistory.reduce((a, b) => a.daysAgo < b.daysAgo ? a : b)
          : null;
      
      pair2List.add({
        'pair': entry.key,
        'cauStat': stat,
        'currentLoseStreak': stat.currentLoseStreak,
        'maxLoseStreak': stat.maxLoseStreak,
        'totalWins': stat.totalWins,
        'winrate': stat.winrate,
        'cauString': stat.cauString,
        'currentState': stat.currentState,
        'maxLevelHitCount': maxLevelHitCount, // Map<maxLevel, count>
        'maxLevelLength': maxLevelLength, // Map<maxLevel, length> - độ dài lose streak
        'top3MaxHits': top3MaxHitsList, // List<MapEntry<maxLevel, count>>
        'distanceToMax': distanceToMax,
        'nearestMaxHit': nearestMaxHit, // Lần chạm max gần nhất
      });
    }
  }
  
  // Sắp xếp theo tiêu chí: lose ngắn nhất, lose hiện tại gần với lose ngắn nhất, số lần xuất hiện nhiều nhất
  pair2List.sort((a, b) {
    final maxLoseA = a['maxLoseStreak'] as int;
    final maxLoseB = b['maxLoseStreak'] as int;
    
    // 1. Ưu tiên lose ngắn nhất (maxLoseStreak thấp nhất)
    if (maxLoseA != maxLoseB) {
      return maxLoseA.compareTo(maxLoseB);
    }
    
    // 2. Nếu bằng nhau, ưu tiên lose hiện tại gần với lose ngắn nhất (distanceToMax nhỏ nhất)
    final distanceA = a['distanceToMax'] as int;
    final distanceB = b['distanceToMax'] as int;
    if (distanceA != distanceB) {
      return distanceA.compareTo(distanceB);
    }
    
    // 3. Nếu vẫn bằng nhau, ưu tiên số lần xuất hiện nhiều nhất
    final totalWinsA = a['totalWins'] as int;
    final totalWinsB = b['totalWins'] as int;
    return totalWinsB.compareTo(totalWinsA);
  });
  
  // Hiển thị top 5 cặp theo tiêu chí mới
  print('  ${'Cặp'.padRight(8)} | ${'LOSE hiện tại'.padRight(15)} | ${'Max LOSE'.padRight(10)} | ${'Số lần xuất hiện'.padRight(18)} | ${'3 Max(n) xuất hiện nhiều nhất'.padRight(35)} | ${'Winrate'.padRight(10)} | ${'Lose đã xuất hiện gần nhất'.padRight(30)} | ${'Cầu hiện tại'.padRight(20)}');
  print('  ${'-' * 8} | ${'-' * 15} | ${'-' * 10} | ${'-' * 18} | ${'-' * 35} | ${'-' * 10} | ${'-' * 30} | ${'-' * 20}');
  
  final top5Pairs2 = pair2List.take(5).toList();
  for (final pair in top5Pairs2) {
    final pairKey = pair['pair'] as String;
    final currentLose = pair['currentLoseStreak'] as int;
    final maxLose = pair['maxLoseStreak'] as int;
    final totalWins = pair['totalWins'] as int;
    final winrate = pair['winrate'] as double;
    final cauString = pair['cauString'] as String;
    final maxLevelHitCount = pair['maxLevelHitCount'] as Map<int, int>;
    final maxLevelLength = pair['maxLevelLength'] as Map<int, int>;
    final top3MaxHits = pair['top3MaxHits'] as List<MapEntry<int, int>>;
    final nearestMaxHit = pair['nearestMaxHit'] as ({int maxLevel, int length, int endIndex, int daysAgo})?;
    
    // Lấy 20 ký tự cuối cùng của cầu để hiển thị
    final cauDisplay = cauString.length > 20 ? '...${cauString.substring(cauString.length - 20)}' : cauString;
    
    // Tạo chuỗi "3 Max(n) xuất hiện nhiều nhất" - format: Max(n, số lần chạm, dây lose)
    String top3MaxHitsStr;
    if (top3MaxHits.isNotEmpty) {
      top3MaxHitsStr = top3MaxHits.map((e) {
        final level = e.key;
        final count = e.value; // số lần chạm
        final length = maxLevelLength[level] ?? 0; // dây lose (độ dài trung bình)
        return 'Max($level, $count, $length)';
      }).join(', ');
    } else {
      top3MaxHitsStr = '-';
    }
    
    // Tạo chuỗi "Lose đã xuất hiện gần nhất" - format: Max(n, số lần chạm, dây lose)
    String loseAppearedStr;
    if (nearestMaxHit != null) {
      final count = maxLevelHitCount[nearestMaxHit.maxLevel] ?? 0; // số lần chạm
      loseAppearedStr = 'Max(${nearestMaxHit.maxLevel}, $count, ${nearestMaxHit.length})';
    } else {
      loseAppearedStr = '-';
    }
    
    print('  ${pairKey.padRight(8)} | ${currentLose.toString().padLeft(15)} | ${maxLose.toString().padLeft(10)} | ${totalWins.toString().padLeft(18)} | ${top3MaxHitsStr.padLeft(35)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${loseAppearedStr.padLeft(30)} | ${cauDisplay.padLeft(20)}');
    
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
  
  // Chuyển đổi thành list và tính toán các thống kê
  final List<Map<String, dynamic>> pair3List = [];
  for (final entry in pair3Stats.entries) {
    final stat = entry.value;
    if (stat.totalDays > 0) { // Chỉ lấy các cặp đã có dữ liệu
      final maxHistory = stat.getMaxHitHistory();
      
      // Đếm số lần xuất hiện của mỗi max level
      final Map<int, int> maxLevelHitCount = {}; // Map<maxLevel, count>
      
      for (final hit in maxHistory) {
        maxLevelHitCount[hit.maxLevel] = (maxLevelHitCount[hit.maxLevel] ?? 0) + 1;
      }
      
      // Lấy top 3 max levels có số lần xuất hiện nhiều nhất
      final top3MaxHits = maxLevelHitCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3MaxHitsList = top3MaxHits.take(3).toList();
      
      // Tính độ dài trung bình của mỗi max level từ maxHistory (thay vì lấy từ topNLose)
      final Map<int, int> maxLevelLength = {}; // Map<maxLevel, averageLength>
      for (final level in maxLevelHitCount.keys) {
        // Lấy tất cả các lần chạm max của level này
        final hitsForLevel = maxHistory.where((hit) => hit.maxLevel == level).toList();
        if (hitsForLevel.isNotEmpty) {
          // Tính độ dài trung bình (làm tròn)
          final totalLength = hitsForLevel.fold<int>(0, (sum, hit) => sum + hit.length);
          final avgLength = (totalLength / hitsForLevel.length).round();
          maxLevelLength[level] = avgLength;
        }
      }
      
      // Tính khoảng cách giữa currentLose và maxLose (để sắp xếp)
      final distanceToMax = (stat.currentLoseStreak - stat.maxLoseStreak).abs();
      
      // Tìm lần chạm max gần nhất (daysAgo nhỏ nhất)
      final nearestMaxHit = maxHistory.isNotEmpty 
          ? maxHistory.reduce((a, b) => a.daysAgo < b.daysAgo ? a : b)
          : null;
      
      pair3List.add({
        'pair': entry.key,
        'cauStat': stat,
        'currentLoseStreak': stat.currentLoseStreak,
        'maxLoseStreak': stat.maxLoseStreak,
        'totalWins': stat.totalWins,
        'winrate': stat.winrate,
        'cauString': stat.cauString,
        'currentState': stat.currentState,
        'maxLevelHitCount': maxLevelHitCount, // Map<maxLevel, count>
        'maxLevelLength': maxLevelLength, // Map<maxLevel, length> - độ dài lose streak
        'top3MaxHits': top3MaxHitsList, // List<MapEntry<maxLevel, count>>
        'distanceToMax': distanceToMax,
        'nearestMaxHit': nearestMaxHit, // Lần chạm max gần nhất
      });
    }
  }
  
  // Lọc chỉ lấy các cặp có số lần xuất hiện >= 15
  final filteredPair3List = pair3List.where((pair) {
    final totalWins = pair['totalWins'] as int;
    return totalWins >= 15;
  }).toList();
  
  // Sắp xếp theo tiêu chí: lose ngắn nhất, lose hiện tại gần với lose ngắn nhất, số lần xuất hiện nhiều nhất
  filteredPair3List.sort((a, b) {
    final maxLoseA = a['maxLoseStreak'] as int;
    final maxLoseB = b['maxLoseStreak'] as int;
    
    // 1. Ưu tiên lose ngắn nhất (maxLoseStreak thấp nhất)
    if (maxLoseA != maxLoseB) {
      return maxLoseA.compareTo(maxLoseB);
    }
    
    // 2. Nếu bằng nhau, ưu tiên lose hiện tại gần với lose ngắn nhất (distanceToMax nhỏ nhất)
    final distanceA = a['distanceToMax'] as int;
    final distanceB = b['distanceToMax'] as int;
    if (distanceA != distanceB) {
      return distanceA.compareTo(distanceB);
    }
    
    // 3. Nếu vẫn bằng nhau, ưu tiên số lần xuất hiện nhiều nhất
    final totalWinsA = a['totalWins'] as int;
    final totalWinsB = b['totalWins'] as int;
    return totalWinsB.compareTo(totalWinsA);
  });
  
  // Hiển thị top 5 cặp theo tiêu chí mới (chỉ lấy các cặp có số lần xuất hiện >= 15)
  print('  ${'Cặp'.padRight(12)} | ${'LOSE hiện tại'.padRight(15)} | ${'Max LOSE'.padRight(10)} | ${'Số lần xuất hiện'.padRight(18)} | ${'3 Max(n) xuất hiện nhiều nhất'.padRight(35)} | ${'Winrate'.padRight(10)} | ${'Lose đã xuất hiện gần nhất'.padRight(30)} | ${'Cầu hiện tại'.padRight(20)}');
  print('  ${'-' * 12} | ${'-' * 15} | ${'-' * 10} | ${'-' * 18} | ${'-' * 35} | ${'-' * 10} | ${'-' * 30} | ${'-' * 20}');
  
  final top5Pairs3 = filteredPair3List.take(5).toList();
  for (final pair in top5Pairs3) {
    final pairKey = pair['pair'] as String;
    final currentLose = pair['currentLoseStreak'] as int;
    final maxLose = pair['maxLoseStreak'] as int;
    final totalWins = pair['totalWins'] as int;
    final winrate = pair['winrate'] as double;
    final cauString = pair['cauString'] as String;
    final maxLevelHitCount = pair['maxLevelHitCount'] as Map<int, int>;
    final maxLevelLength = pair['maxLevelLength'] as Map<int, int>;
    final top3MaxHits = pair['top3MaxHits'] as List<MapEntry<int, int>>;
    final nearestMaxHit = pair['nearestMaxHit'] as ({int maxLevel, int length, int endIndex, int daysAgo})?;
    
    // Lấy 20 ký tự cuối cùng của cầu để hiển thị
    final cauDisplay = cauString.length > 20 ? '...${cauString.substring(cauString.length - 20)}' : cauString;
    
    // Tạo chuỗi "3 Max(n) xuất hiện nhiều nhất" - format: Max(n, số lần chạm, dây lose)
    String top3MaxHitsStr;
    if (top3MaxHits.isNotEmpty) {
      top3MaxHitsStr = top3MaxHits.map((e) {
        final level = e.key;
        final count = e.value; // số lần chạm
        final length = maxLevelLength[level] ?? 0; // dây lose (độ dài trung bình)
        return 'Max($level, $count, $length)';
      }).join(', ');
    } else {
      top3MaxHitsStr = '-';
    }
    
    // Tạo chuỗi "Lose đã xuất hiện gần nhất" - format: Max(n, số lần chạm, dây lose)
    String loseAppearedStr;
    if (nearestMaxHit != null) {
      final count = maxLevelHitCount[nearestMaxHit.maxLevel] ?? 0; // số lần chạm
      loseAppearedStr = 'Max(${nearestMaxHit.maxLevel}, $count, ${nearestMaxHit.length})';
    } else {
      loseAppearedStr = '-';
    }
    
    print('  ${pairKey.padRight(12)} | ${currentLose.toString().padLeft(15)} | ${maxLose.toString().padLeft(10)} | ${totalWins.toString().padLeft(18)} | ${top3MaxHitsStr.padLeft(35)} | ${winrate.toStringAsFixed(2).padLeft(9)}% | ${loseAppearedStr.padLeft(30)} | ${cauDisplay.padLeft(20)}');
    
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
          final topNLose = stat.getTopNLoseStreaks(20);
          
          // Đếm số lần xuất hiện của mỗi max level
          final Map<int, int> maxLevelHitCount = {};
          for (final hit in maxHistory) {
            maxLevelHitCount[hit.maxLevel] = (maxLevelHitCount[hit.maxLevel] ?? 0) + 1;
          }
          
          // Lấy top 3 max levels có số lần xuất hiện nhiều nhất
          final top3MaxHits = maxLevelHitCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top3MaxHitsList = top3MaxHits.take(3).toList();
          
          // Tạo map maxLevelLength từ topNLose
          final Map<int, int> maxLevelLength = {};
          for (int i = 0; i < topNLose.length; i++) {
            maxLevelLength[i + 1] = topNLose[i];
          }
          
          // Tìm lần chạm max gần nhất
          final nearestMaxHit = maxHistory.isNotEmpty 
              ? maxHistory.reduce((a, b) => a.daysAgo < b.daysAgo ? a : b)
              : null;
          
          print('\n  📊 LỊCH SỬ CHẠM MAX CỦA CẶP 2 SỐ: $pairKey');
          print('  ============================================================');
          print('  LOSE hiện tại: ${stat.currentLoseStreak}');
          print('  Max LOSE: ${stat.maxLoseStreak}');
          print('  Số lần xuất hiện: ${stat.totalWins}');
          
          // Hiển thị 3 Max(n) xuất hiện nhiều nhất - format: Max(n, số lần chạm, dây lose)
          String top3MaxHitsStr;
          if (top3MaxHitsList.isNotEmpty) {
            top3MaxHitsStr = top3MaxHitsList.map((e) {
              final level = e.key;
              final count = e.value; // số lần chạm
              final length = maxLevelLength[level] ?? 0; // dây lose (độ dài trung bình)
              return 'Max($level, $count, $length)';
            }).join(', ');
          } else {
            top3MaxHitsStr = '-';
          }
          print('  3 Max(n) xuất hiện nhiều nhất: $top3MaxHitsStr');
          
          // Hiển thị Lose đã xuất hiện gần nhất có ngày - format: Max(n, số lần chạm, dây lose)
          if (nearestMaxHit != null && pair2FirstAppearIndex.containsKey(pairKey)) {
            final firstAppearIndex = pair2FirstAppearIndex[pairKey]!;
            // endIndex là index trong history của ngày kết thúc lose streak (ngày có win, sau khi lose streak kết thúc)
            // Để hiển thị ngày cuối cùng của lose streak: dùng endIndex - 1 (ngày trước ngày có win)
            // Map từ history sang sortedData index
            // firstAppearIndex là index trong sortedData của ngày đầu tiên cặp xuất hiện
            // Vậy sortedDataIndex của ngày cuối cùng lose streak = firstAppearIndex + endIndex - 1
            final sortedDataIndex = firstAppearIndex + nearestMaxHit.endIndex - 1;
            
            final count = maxLevelHitCount[nearestMaxHit.maxLevel] ?? 0; // số lần chạm
            if (sortedDataIndex >= 0 && sortedDataIndex < sortedData.length) {
              final dateStr = sortedData[sortedDataIndex].date.split(' ').first;
              print('  Lose đã xuất hiện gần nhất: Max(${nearestMaxHit.maxLevel}, $count, ${nearestMaxHit.length}) - Ngày: $dateStr');
            } else {
              print('  Lose đã xuất hiện gần nhất: Max(${nearestMaxHit.maxLevel}, $count, ${nearestMaxHit.length}) - Ngày: N/A');
            }
          } else {
            print('  Lose đã xuất hiện gần nhất: -');
          }
          
          // Hiển thị Cầu hiện tại (toàn bộ W/L)
          final cauString = stat.cauString;
          print('  Cầu hiện tại: $cauString');
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
          final topNLose = stat.getTopNLoseStreaks(20);
          
          // Đếm số lần xuất hiện của mỗi max level
          final Map<int, int> maxLevelHitCount = {};
          for (final hit in maxHistory) {
            maxLevelHitCount[hit.maxLevel] = (maxLevelHitCount[hit.maxLevel] ?? 0) + 1;
          }
          
          // Lấy top 3 max levels có số lần xuất hiện nhiều nhất
          final top3MaxHits = maxLevelHitCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top3MaxHitsList = top3MaxHits.take(3).toList();
          
          // Tạo map maxLevelLength từ topNLose
          final Map<int, int> maxLevelLength = {};
          for (int i = 0; i < topNLose.length; i++) {
            maxLevelLength[i + 1] = topNLose[i];
          }
          
          // Tìm lần chạm max gần nhất
          final nearestMaxHit = maxHistory.isNotEmpty 
              ? maxHistory.reduce((a, b) => a.daysAgo < b.daysAgo ? a : b)
              : null;
          
          print('\n  📊 LỊCH SỬ CHẠM MAX CỦA CẶP 3 SỐ: $pairKey');
          print('  ============================================================');
          print('  LOSE hiện tại: ${stat.currentLoseStreak}');
          print('  Max LOSE: ${stat.maxLoseStreak}');
          print('  Số lần xuất hiện: ${stat.totalWins}');
          
          // Hiển thị 3 Max(n) xuất hiện nhiều nhất - format: Max(n, số lần chạm, dây lose)
          String top3MaxHitsStr;
          if (top3MaxHitsList.isNotEmpty) {
            top3MaxHitsStr = top3MaxHitsList.map((e) {
              final level = e.key;
              final count = e.value; // số lần chạm
              final length = maxLevelLength[level] ?? 0; // dây lose (độ dài trung bình)
              return 'Max($level, $count, $length)';
            }).join(', ');
          } else {
            top3MaxHitsStr = '-';
          }
          print('  3 Max(n) xuất hiện nhiều nhất: $top3MaxHitsStr');
          
          // Hiển thị Lose đã xuất hiện gần nhất có ngày - format: Max(n, số lần chạm, dây lose)
          if (nearestMaxHit != null && pair3FirstAppearIndex.containsKey(pairKey)) {
            final firstAppearIndex = pair3FirstAppearIndex[pairKey]!;
            // endIndex là index trong history của ngày kết thúc lose streak (ngày có win, sau khi lose streak kết thúc)
            // Để hiển thị ngày cuối cùng của lose streak: dùng endIndex - 1 (ngày trước ngày có win)
            // Map từ history sang sortedData index
            // firstAppearIndex là index trong sortedData của ngày đầu tiên cặp xuất hiện
            // Vậy sortedDataIndex của ngày cuối cùng lose streak = firstAppearIndex + endIndex - 1
            final sortedDataIndex = firstAppearIndex + nearestMaxHit.endIndex - 1;
            
            final count = maxLevelHitCount[nearestMaxHit.maxLevel] ?? 0; // số lần chạm
            if (sortedDataIndex >= 0 && sortedDataIndex < sortedData.length) {
              final dateStr = sortedData[sortedDataIndex].date.split(' ').first;
              print('  Lose đã xuất hiện gần nhất: Max(${nearestMaxHit.maxLevel}, $count, ${nearestMaxHit.length}) - Ngày: $dateStr');
            } else {
              print('  Lose đã xuất hiện gần nhất: Max(${nearestMaxHit.maxLevel}, $count, ${nearestMaxHit.length}) - Ngày: N/A');
            }
          } else {
            print('  Lose đã xuất hiện gần nhất: -');
          }
          
          // Hiển thị Cầu hiện tại (toàn bộ W/L)
          final cauString = stat.cauString;
          print('  Cầu hiện tại: $cauString');
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