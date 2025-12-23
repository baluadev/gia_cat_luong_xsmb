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
  
  /// Tìm dây max lose gần nhất đã chạp đến (đã đạt được) trong topN (max1, max2, max3, max4, max5)
  /// Trả về thông tin về dây cầu đó: (maxLevel: 1, 2, 3, 4, hoặc 5, length: độ dài, daysAgo: số ngày trước)
  /// Trả về null nếu chưa chạp đến bất kỳ max nào
  ({int maxLevel, int length, int daysAgo})? getNearestMaxLoseReached() {
    if (history.isEmpty) return null;
    
    final top5Lose = getTopNLoseStreaks(5);
    if (top5Lose.isEmpty) return null;
    
    final max1 = top5Lose[0];
    final max2 = top5Lose.length > 1 ? top5Lose[1] : 0;
    final max3 = top5Lose.length > 2 ? top5Lose[2] : 0;
    final max4 = top5Lose.length > 3 ? top5Lose[3] : 0;
    final max5 = top5Lose.length > 4 ? top5Lose[4] : 0;
    
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
      } else if (max4 > 0 && currentLoseStreak >= max4) {
        // Đang trong hoặc đã vượt quá max4
        return (maxLevel: 4, length: currentLoseStreak, daysAgo: 0);
      } else if (max5 > 0 && currentLoseStreak >= max5) {
        // Đang trong hoặc đã vượt quá max5
        return (maxLevel: 5, length: currentLoseStreak, daysAgo: 0);
      }
    }
    
    // Nếu chuỗi lose hiện tại chưa chạp đến max nào, tìm chuỗi lose gần nhất đã kết thúc
    // Lấy danh sách các chuỗi lose theo thứ tự thời gian (từ gần nhất)
    final loseStreaksByTime = getLoseStreaksByTime();
    
    // Bỏ qua chuỗi lose đầu tiên nếu đó là chuỗi lose hiện tại (chưa kết thúc)
    final startIndex = (currentLoseStreak > 0 && loseStreaksByTime.isNotEmpty) ? 1 : 0;
    
    // Tìm chuỗi lose gần nhất đã kết thúc mà đã chạp đến (đã đạt được) max1, max2, max3, max4, hoặc max5
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
      } else if (max4 > 0 && streak.length >= max4) {
        // Đã chạp đến max4
        final daysAgo = history.length - 1 - streak.endIndex;
        return (maxLevel: 4, length: streak.length, daysAgo: daysAgo);
      } else if (max5 > 0 && streak.length >= max5) {
        // Đã chạp đến max5
        final daysAgo = history.length - 1 - streak.endIndex;
        return (maxLevel: 5, length: streak.length, daysAgo: daysAgo);
      }
    }
    
    return null;
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
    final nearestMaxLose = stat.getNearestMaxLoseReached();
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
      'nearestMaxLose': nearestMaxLose,
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

  // Thống kê TopN max lose (max1, max2, max3, max4, max5) cho tất cả các số từ 00-99
  print('\n\n🏆 TOPN MAX LOSE (MAX1, MAX2, MAX3, MAX4, MAX5) CỦA TẤT CẢ CÁC SỐ (00-99):');
  print('============================================================');
  // Sắp xếp lại theo số tăng dần
  final allNumbersSorted = List<Map<String, dynamic>>.from(statsList);
  allNumbersSorted.sort((a, b) {
    // Ưu tiên sắp xếp theo số tăng dần (00, 01, 02, ...)
    return (a['number'] as int).compareTo(b['number'] as int);
  });
  
  print('  ${'Số'.padRight(5)} | ${'LOSE hiện tại'.padRight(15)} | ${'MAX1'.padRight(8)} | ${'MAX2'.padRight(8)} | ${'MAX3'.padRight(8)} | ${'MAX4'.padRight(8)} | ${'MAX5'.padRight(8)} | ${'Dây cầu gần nhất'.padRight(25)} | ${'Winrate'.padRight(10)}');
  print('  ${'-' * 5} | ${'-' * 15} | ${'-' * 8} | ${'-' * 8} | ${'-' * 8} | ${'-' * 8} | ${'-' * 8} | ${'-' * 25} | ${'-' * 10}');
  
  for (final stat in allNumbersSorted) {
    final num = stat['number'] as int;
    final currentLose = stat['currentLoseStreak'] as int;
    final max1 = stat['max1'] as int;
    final max2 = stat['max2'] as int;
    final max3 = stat['max3'] as int;
    final max4 = stat['max4'] as int;
    final max5 = stat['max5'] as int;
    final nearestMaxLose = stat['nearestMaxLose'] as ({int maxLevel, int length, int daysAgo})?;
    final winrate = stat['winrate'] as double;
    
    final numStr = num.toString().padLeft(2, '0');
    final max1Str = max1 > 0 ? max1.toString() : '-';
    final max2Str = max2 > 0 ? max2.toString() : '-';
    final max3Str = max3 > 0 ? max3.toString() : '-';
    final max4Str = max4 > 0 ? max4.toString() : '-';
    final max5Str = max5 > 0 ? max5.toString() : '-';
    
    String cauStr;
    if (nearestMaxLose != null) {
      if (nearestMaxLose.daysAgo == 0) {
        cauStr = 'MAX${nearestMaxLose.maxLevel} (${nearestMaxLose.length}) - Đang trong';
      } else {
        cauStr = 'MAX${nearestMaxLose.maxLevel} (${nearestMaxLose.length}) - ${nearestMaxLose.daysAgo} ngày trước';
      }
    } else {
      cauStr = 'Chưa chạp đến MAX';
    }
    
    final currentLoseStr = currentLose > 0 ? currentLose.toString() : '-';
    print('  ${numStr.padRight(5)} | ${currentLoseStr.padLeft(15)} | ${max1Str.padLeft(8)} | ${max2Str.padLeft(8)} | ${max3Str.padLeft(8)} | ${max4Str.padLeft(8)} | ${max5Str.padLeft(8)} | ${cauStr.padLeft(25)} | ${winrate.toStringAsFixed(2).padLeft(9)}%');
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

  // Thống kê ngày gần nhất
  if (sortedData.isNotEmpty) {
    final latestDay = sortedData.last;
    
    print('\n\n📅 NGÀY GẦN NHẤT (${latestDay.date.split(' ').first}):');
    print('============================================================');
    print('  Các số xuất hiện trong others: ${latestDay.others.map((n) => n.toString().padLeft(2, '0')).join(', ')}');
    print('  Tổng số: ${latestDay.others.length} số');
  }
}