import 'dart:io';
import 'dart:math';
import 'data_model.dart';

/// =======================
/// CONFIG
/// =======================
const int TOP_N = 10; // Top N cặp số muốn lấy

/// =======================
/// PAIR STATISTICS
/// =======================
class PairStat {
  final int num1;
  final int num2;
  
  int hit = 0; // Số lần xuất hiện
  int total = 0; // Tổng số lần kiểm tra
  
  int currentLoseStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int maxWinStreak = 0;
  
  final List<bool> history = []; // Lịch sử win/lose
  
  // Track maxLose
  int maxLoseReachedCount = 0; // Số lần đạt đến maxLose
  String? lastMaxLoseDate; // Ngày gần nhất đạt maxLose
  final List<String> hitDates = []; // Danh sách các ngày đã hit
  final List<String> appearDates = []; // Danh sách các ngày đã xuất hiện (cả 2 số)
  
  PairStat(this.num1, this.num2);
  
  /// Winrate: Tỷ lệ xuất hiện (%)
  double get winrate => total == 0 ? 0 : (hit / total) * 100;
  
  /// Thêm kết quả
  void addResult(bool isWin) {
    total++;
    history.add(isWin);
    
    if (isWin) {
      hit++;
      currentWinStreak++;
      currentLoseStreak = 0;
      maxWinStreak = max(maxWinStreak, currentWinStreak);
    } else {
      currentLoseStreak++;
      currentWinStreak = 0;
      maxLoseStreak = max(maxLoseStreak, currentLoseStreak);
    }
  }
  
  /// Score tổng hợp để ranking
  /// Ưu tiên: MaxLose ngắn nhất (tốt nhất), Winrate cao
  double get compositeScore {
    if (total == 0) return 0;
    
    // MaxLose ngắn nhất = tốt nhất (ưu tiên cao)
    // Normalize: MaxLose càng nhỏ, score càng cao
    // Giả sử MaxLose có thể từ 0-100, normalize về 0-50 điểm
    final maxLoseScore = maxLoseStreak == 0 
        ? 50.0  // Nếu chưa từng lose, điểm cao nhất
        : 50.0 - (maxLoseStreak / 100.0) * 50.0; // MaxLose càng nhỏ, điểm càng cao
    
    // Winrate: càng cao càng tốt (0-50 điểm)
    final winrateScore = (winrate / 100.0) * 50.0;
    
    // Độ tin cậy: càng nhiều dữ liệu càng tốt (0-10 điểm)
    final stabilityScore = min(log(total + 1) * 2.0, 10.0);
    
    return maxLoseScore + winrateScore + stabilityScore;
  }
  
  @override
  String toString() {
    return 'Cặp ${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')} | '
        'Winrate: ${winrate.toStringAsFixed(2)}% | '
        'MaxLose: $maxLoseStreak | '
        'Hit: $hit/$total';
  }
}

/// =======================
/// TRIPLE STATISTICS
/// =======================
class TripleStat {
  final int num1;
  final int num2;
  final int num3;
  
  int hit = 0; // Số lần xuất hiện
  int total = 0; // Tổng số lần kiểm tra
  
  int currentLoseStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int maxWinStreak = 0;
  
  final List<bool> history = []; // Lịch sử win/lose
  
  // Track maxLose
  int maxLoseReachedCount = 0; // Số lần đạt đến maxLose
  String? lastMaxLoseDate; // Ngày gần nhất đạt maxLose
  final List<String> hitDates = []; // Danh sách các ngày đã hit
  final List<String> appearDates = []; // Danh sách các ngày đã xuất hiện (cả 3 số)
  
  TripleStat(this.num1, this.num2, this.num3);
  
  /// Winrate: Tỷ lệ xuất hiện (%)
  double get winrate => total == 0 ? 0 : (hit / total) * 100;
  
  /// Thêm kết quả
  void addResult(bool isWin) {
    total++;
    history.add(isWin);
    
    if (isWin) {
      hit++;
      currentWinStreak++;
      currentLoseStreak = 0;
      maxWinStreak = max(maxWinStreak, currentWinStreak);
    } else {
      currentLoseStreak++;
      currentWinStreak = 0;
      maxLoseStreak = max(maxLoseStreak, currentLoseStreak);
    }
  }
  
  /// Score tổng hợp để ranking
  /// Ưu tiên: MaxLose ngắn nhất (tốt nhất), Winrate cao
  double get compositeScore {
    if (total == 0) return 0;
    
    // MaxLose ngắn nhất = tốt nhất (ưu tiên cao)
    final maxLoseScore = maxLoseStreak == 0 
        ? 50.0
        : 50.0 - (maxLoseStreak / 100.0) * 50.0;
    
    // Winrate: càng cao càng tốt (0-50 điểm)
    final winrateScore = (winrate / 100.0) * 50.0;
    
    // Độ tin cậy: càng nhiều dữ liệu càng tốt (0-10 điểm)
    final stabilityScore = min(log(total + 1) * 2.0, 10.0);
    
    return maxLoseScore + winrateScore + stabilityScore;
  }
  
  @override
  String toString() {
    return 'Bộ ${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}-${num3.toString().padLeft(2, '0')} | '
        'Winrate: ${winrate.toStringAsFixed(2)}% | '
        'MaxLose: $maxLoseStreak | '
        'Hit: $hit/$total';
  }
}

/// =======================
/// LOAD DATA
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
/// MAIN
/// =======================
void main() async {
  bool shouldContinue = true;
  
  while (shouldContinue) {
    print('\n=====================THỐNG KÊ CẶP SỐ=====================');
    
    // Nhập lựa chọn logic
    print('Chọn loại thống kê:');
    print('  1 = Top 10 cặp 2 số (1 trong 2 số xuất hiện)');
    print('  2 = Top 10 cặp 2 số (Cả 2 số phải xuất hiện cùng 1 ngày)');
    print('  3 = Top 10 bộ 3 số (Cả 3 số phải xuất hiện cùng 1 ngày)');
    stdout.write('Nhập lựa chọn (1, 2 hoặc 3): ');
    final input = stdin.readLineSync()?.trim() ?? '2';
    
    if (input == '3') {
      await processTriples();
    } else {
      final useOrLogic = input == '1'; // true = 1 trong 2, false = cả 2
      final isOption1 = input == '1'; // true = Option 1, false = Option 2
      print('Đã chọn: ${useOrLogic ? "1 trong 2 số" : "Cả 2 số"}\n');
      await processPairs(useOrLogic, isOption1);
    }
    
    // Hỏi có muốn tiếp tục không
    print('\n========================END===========================');
    stdout.write('Nhập "y" để tiếp tục hoặc "n" để thoát: ');
    final continueInput = (stdin.readLineSync()?.trim() ?? '').toLowerCase();
    shouldContinue = continueInput == 'y' || continueInput == 'yes';
  }
  
  print('Đã thoát chương trình.');
}

Future<void> processPairs(bool useOrLogic, bool isOption1) async {
  // Load data
  final data = await loadDataModels('data.csv');
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
  
  print('Đã load ${data.length} ngày dữ liệu\n');
  
  // =======================
  // TẠO TẤT CẢ CẶP SỐ TỪ OTHERS (0-99)
  // =======================
  final Map<String, PairStat> pairStats = {};
  
  // Tạo tất cả cặp số có thể từ 0-99 (không trùng, sắp xếp)
  for (int num1 = 0; num1 < 100; num1++) {
    for (int num2 = num1 + 1; num2 < 100; num2++) {
      final key = '${num1}_$num2';
      pairStats[key] = PairStat(num1, num2);
    }
  }
  
  print('Đã tạo ${pairStats.length} cặp số duy nhất\n');
  
  // =======================
  // THỐNG KÊ: Track pattern "nếu xuất hiện hôm nay, có xuất hiện ngày mai không"
  // Lose streak: số ngày liên tiếp mà cặp số không xuất hiện (theo logic đã chọn)
  // =======================
  // Map để track ngày xuất hiện gần nhất của mỗi cặp
  final Map<String, int> lastAppearDayIndex = {};
  
  for (int i = 0; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];
    
    // Lấy tất cả số của ngày hôm nay và ngày mai
    final todayNumbers = today.others.toSet();
    final tomorrowNumbers = tomorrow.others.toSet();
    
    // Track các cặp số
    for (final pair in pairStats.values) {
      final key = '${pair.num1}_${pair.num2}';
      
      // Kiểm tra cặp số có xuất hiện trong ngày hôm nay không?
      final existsToday = useOrLogic
          ? (todayNumbers.contains(pair.num1) || todayNumbers.contains(pair.num2))
          : (todayNumbers.contains(pair.num1) && todayNumbers.contains(pair.num2));
      
      if (existsToday) {
        // Lưu ngày xuất hiện (cả 2 số)
        pair.appearDates.add(today.date);
        
        // Nếu xuất hiện hôm nay, kiểm tra có xuất hiện ngày mai không?
        final existsTomorrow = useOrLogic
            ? (tomorrowNumbers.contains(pair.num1) || tomorrowNumbers.contains(pair.num2))
            : (tomorrowNumbers.contains(pair.num1) && tomorrowNumbers.contains(pair.num2));
        
        // Tính lose streak dựa trên số ngày từ lần xuất hiện gần nhất
        if (lastAppearDayIndex.containsKey(key)) {
          final daysSinceLastAppear = i - lastAppearDayIndex[key]!;
          if (daysSinceLastAppear > 1) {
            // Có khoảng cách giữa các lần xuất hiện
            final newLoseStreak = daysSinceLastAppear - 1;
            // Cập nhật maxLose
            pair.maxLoseStreak = max(pair.maxLoseStreak, newLoseStreak);
            
            // Không đếm ở đây, sẽ tính lại sau từ history
          }
        }
        
        // Win nếu xuất hiện cả hôm nay và ngày mai
        pair.addResult(existsTomorrow);
        
        // Nếu hit (xuất hiện ngày mai), lưu ngày mai vào danh sách hit
        if (existsTomorrow) {
          pair.hitDates.add(tomorrow.date);
        }
        
        // Cập nhật ngày xuất hiện gần nhất
        lastAppearDayIndex[key] = i;
      } else {
        // Nếu không xuất hiện hôm nay, tính lose streak từ lần xuất hiện gần nhất
        if (lastAppearDayIndex.containsKey(key)) {
          final daysSinceLastAppear = i - lastAppearDayIndex[key]!;
          pair.currentLoseStreak = daysSinceLastAppear;
          pair.maxLoseStreak = max(pair.maxLoseStreak, daysSinceLastAppear);
          
          // Không đếm ở đây, sẽ tính lại sau từ history
        } else {
          // Chưa từng xuất hiện, lose streak = số ngày từ đầu
          pair.currentLoseStreak = i + 1;
          pair.maxLoseStreak = max(pair.maxLoseStreak, i + 1);
          
          // Không đếm ở đây, sẽ tính lại sau từ history
        }
      }
    }
  }
  
  // =======================
  // TÍNH LẠI CURRENT LOSE STREAK, MAXLOSE REACHED COUNT VÀ LAST MAXLOSE DATE
  // Tính lại từ đầu để đảm bảo chính xác
  // =======================
  for (final pair in pairStats.values) {
    // Reset counters
    pair.maxLoseReachedCount = 0;
    pair.lastMaxLoseDate = null;
    
    // Tìm tất cả các lần xuất hiện trong toàn bộ dữ liệu (bao gồm cả ngày cuối)
    final appearIndices = <int>[];
    for (int i = 0; i < data.length; i++) {
      final day = data[i];
      final dayNumbers = day.others.toSet();
      final exists = useOrLogic
          ? (dayNumbers.contains(pair.num1) || dayNumbers.contains(pair.num2))
          : (dayNumbers.contains(pair.num1) && dayNumbers.contains(pair.num2));
      if (exists) {
        appearIndices.add(i);
      }
    }
    
    // Tính currentLoseStreak dựa trên số ngày thực tế từ lần xuất hiện gần nhất
    // Nếu cặp số đã từng xuất hiện, tính số ngày từ lần xuất hiện gần nhất đến ngày cuối
    if (appearIndices.isNotEmpty) {
      final lastAppearIndex = appearIndices.last;
      // Current lose streak = số ngày từ lần xuất hiện gần nhất đến ngày cuối cùng
      if (lastAppearIndex == data.length - 1) {
        // Nếu cặp số xuất hiện ở ngày cuối cùng, currentLoseStreak = 0
        pair.currentLoseStreak = 0;
      } else {
        pair.currentLoseStreak = (data.length - 1 - lastAppearIndex) as int;
      }
    } else {
      // Chưa từng xuất hiện, lose streak = số ngày từ đầu đến cuối
      pair.currentLoseStreak = data.length;
    }
    
    // Tính lại maxLose: tìm kỳ lose dài nhất TRƯỚC ngày xuất hiện gần nhất
    // MaxLose = số ngày liên tiếp không xuất hiện dài nhất (chỉ tính trong quá khứ, trước lastAppearIndex)
    int calculatedMaxLose = 0;
    
    if (appearIndices.isEmpty) {
      // Trường hợp đặc biệt: Chưa từng xuất hiện
      // MaxLose = 0 (vì không có kỳ lose nào trong quá khứ, chỉ có kỳ lose hiện tại)
      calculatedMaxLose = 0;
    } else {
      final lastAppearIndex = appearIndices.last;
      
      // Chỉ tính các kỳ lose TRƯỚC lastAppearIndex
      // Trường hợp 1: Lose streak từ đầu đến lần xuất hiện đầu tiên (nếu firstAppearIndex < lastAppearIndex)
      final firstAppearIndex = appearIndices.first;
      if (firstAppearIndex > 0 && firstAppearIndex < lastAppearIndex) {
        calculatedMaxLose = firstAppearIndex;
      }
      
      // Trường hợp 2: Lose streak giữa các lần xuất hiện (chỉ tính đến trước lastAppearIndex)
      for (int i = 1; i < appearIndices.length; i++) {
        final currentAppearIndex = appearIndices[i];
        // Chỉ tính nếu currentAppearIndex < lastAppearIndex (trước ngày xuất hiện gần nhất)
        if (currentAppearIndex < lastAppearIndex) {
          final prevAppearIndex = appearIndices[i - 1];
          final loseStreak = currentAppearIndex - prevAppearIndex - 1;
          calculatedMaxLose = max(calculatedMaxLose, loseStreak);
        }
      }
    }
    
    pair.maxLoseStreak = calculatedMaxLose;
    
    // Tìm ngày về gần nhất trong quá khứ mà có kỳ lose dài nhất (maxLose)
    // Chỉ tìm trong các kỳ lose TRƯỚC ngày xuất hiện gần nhất (lastAppearIndex)
    pair.maxLoseReachedCount = 0;
    pair.lastMaxLoseDate = null;
    
    if (pair.maxLoseStreak > 0 && appearIndices.isNotEmpty) {
      final lastAppearIndex = appearIndices.last;
      int closestMaxLoseEndIndex = -1; // Index của ngày cuối cùng của kỳ lose gần nhất (trước lastAppearIndex)
      
      // Kiểm tra lose streak từ đầu đến lần xuất hiện đầu tiên
      final firstAppearIndex = appearIndices.first;
      if (firstAppearIndex > 0 && firstAppearIndex < lastAppearIndex && firstAppearIndex == pair.maxLoseStreak) {
        // Ngày cuối của kỳ lose này là ngày trước khi xuất hiện lần đầu
        final endIndex = firstAppearIndex - 1;
        if (endIndex >= 0 && (closestMaxLoseEndIndex == -1 || endIndex > closestMaxLoseEndIndex)) {
          closestMaxLoseEndIndex = endIndex;
        }
        pair.maxLoseReachedCount++;
      }
      
      // Kiểm tra lose streak giữa các lần xuất hiện (chỉ tính đến trước lastAppearIndex)
      for (int i = 1; i < appearIndices.length; i++) {
        final currentAppearIndex = appearIndices[i];
        // Chỉ tính nếu currentAppearIndex < lastAppearIndex
        if (currentAppearIndex < lastAppearIndex) {
          final prevAppearIndex = appearIndices[i - 1];
          final loseStreak = currentAppearIndex - prevAppearIndex - 1;
          
          if (loseStreak == pair.maxLoseStreak) {
            // Ngày cuối của kỳ lose này là ngày trước khi xuất hiện lại
            final endIndex = currentAppearIndex - 1;
            if (closestMaxLoseEndIndex == -1 || endIndex > closestMaxLoseEndIndex) {
              closestMaxLoseEndIndex = endIndex;
            }
            pair.maxLoseReachedCount++;
          }
        }
      }
      
      // Lưu ngày gần nhất (ngày cuối cùng của kỳ lose dài nhất gần nhất trong quá khứ)
      if (closestMaxLoseEndIndex >= 0 && closestMaxLoseEndIndex < data.length) {
        pair.lastMaxLoseDate = data[closestMaxLoseEndIndex].date;
      }
    }
    
    // Tính lại win streak từ appearIndices (toàn bộ data, giống lose streak)
    // Current win streak: đếm từ ngày cuối lên, số ngày liên tiếp xuất hiện
    pair.currentWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      // Đếm từ ngày cuối lên
      for (int i = data.length - 1; i >= 0; i--) {
        if (appearIndices.contains(i)) {
          pair.currentWinStreak++;
        } else {
          break; // Dừng khi gặp ngày không xuất hiện
        }
      }
    }
    
    // Tính maxWinStreak: tìm chuỗi dài nhất các ngày liên tiếp xuất hiện
    pair.maxWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      int tempWinStreak = 0;
      int prevIndex = -2; // Khởi tạo để đảm bảo không trùng với index đầu tiên
      
      for (final appearIndex in appearIndices) {
        if (appearIndex == prevIndex + 1) {
          // Liên tiếp với lần trước
          tempWinStreak++;
        } else {
          // Không liên tiếp, bắt đầu chuỗi mới
          pair.maxWinStreak = max(pair.maxWinStreak, tempWinStreak);
          tempWinStreak = 1;
        }
        prevIndex = appearIndex;
      }
      // Cập nhật chuỗi cuối cùng
      pair.maxWinStreak = max(pair.maxWinStreak, tempWinStreak);
    }
  }
  
  // =======================
  // LỌC VÀ SẮP XẾP: TopN cặp số tốt nhất
  // Ưu tiên: MaxLose ngắn nhất (tốt nhất), Winrate cao
  // Điều kiện theo 3 khuyến nghị (khác nhau cho Option 1 và Option 2)
  // =======================
  final allPairs = pairStats.values.toList();
  
  // Lọc các cặp có đủ dữ liệu (total >= 3)
  final filteredPairs = allPairs.where((p) => p.total >= 3).toList();
  
  // Lọc theo 3 khuyến nghị (phân biệt Option 1 và Option 2)
  // Loại bỏ các cặp có currentLoseStreak vượt quá maxLoseStreak
  final qualifiedPairs = filteredPairs.where((p) {
    // Loại bỏ nếu currentLoseStreak > maxLoseStreak
    if (p.currentLoseStreak > p.maxLoseStreak && p.maxLoseStreak > 0) {
      return false;
    }
    
    if (isOption1) {
      // ========== OPTION 1: 1 trong 2 số xuất hiện ==========
      // Xác suất cao (50-60%), Total lớn (400-500), Winrate thường 40-50%, MaxLose ngắn (5-15)
      
      // Khuyến nghị 1: Winrate cao (8%+) + MaxLose ngắn (40-) + Lose streak gần max (80%+ của MaxLose)
      if (p.winrate >= 8.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 40) {
        if (p.currentLoseStreak > 0) {
          final loseStreakRatio = p.currentLoseStreak / p.maxLoseStreak;
          if (loseStreakRatio >= 0.8) {
            return true; // Đạt khuyến nghị 1
          }
        }
      }
      
      // Khuyến nghị 2: Winrate trung bình (5%+) + MaxLose ngắn (30-) + Đang win streak
      if (p.winrate >= 5.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 30) {
        if (p.currentWinStreak > 0) {
          return true; // Đạt khuyến nghị 2
        }
      }
      
      // Khuyến nghị 3: Winrate cao + MaxLose ngắn + Vừa mới xuất hiện (currentWinStreak = 1)
      if (p.winrate >= 8.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 40) {
        if (p.currentWinStreak == 1) {
          return true; // Đạt khuyến nghị 3
        }
      }
    } else {
      // ========== OPTION 2: Cả 2 số cùng ngày ==========
      // Xác suất trung bình (5-15%), Total trung bình (50-150), Winrate thường 5-15%, MaxLose dài hơn (30-60)
      
      // Khuyến nghị 1: Winrate >= 6% + MaxLose <= 50 + Lose streak >= 75% của MaxLose
      if (p.winrate >= 6.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 50) {
        if (p.currentLoseStreak > 0) {
          final loseStreakRatio = p.currentLoseStreak / p.maxLoseStreak;
          if (loseStreakRatio >= 0.75) {
            return true; // Đạt khuyến nghị 1
          }
        }
      }
      
      // Khuyến nghị 2: Winrate >= 4% + MaxLose <= 40 + Đang win streak
      if (p.winrate >= 4.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 40) {
        if (p.currentWinStreak > 0) {
          return true; // Đạt khuyến nghị 2
        }
      }
      
      // Khuyến nghị 3: Winrate >= 6% + MaxLose <= 50 + Vừa mới xuất hiện (currentWinStreak = 1)
      if (p.winrate >= 6.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 50) {
        if (p.currentWinStreak == 1) {
          return true; // Đạt khuyến nghị 3
        }
      }
    }
    
    return false; // Không đạt điều kiện nào
  }).toList();
  
  // Nếu không có cặp nào đạt điều kiện, thông báo
  if (qualifiedPairs.isEmpty) {
    print('⚠️  Không có cặp số nào đạt các điều kiện khuyến nghị.');
    if (isOption1) {
      print('   Điều kiện (Option 1 - 1 trong 2 số):');
      print('   1. Winrate >= 8% + MaxLose <= 40 + Lose streak >= 80% của MaxLose');
      print('   2. Winrate >= 5% + MaxLose <= 30 + Đang win streak');
      print('   3. Winrate >= 8% + MaxLose <= 40 + Vừa mới xuất hiện (win streak = 1)');
    } else {
      print('   Điều kiện (Option 2 - Cả 2 số cùng ngày):');
      print('   1. Winrate >= 6% + MaxLose <= 50 + Lose streak >= 75% của MaxLose');
      print('   2. Winrate >= 4% + MaxLose <= 40 + Đang win streak');
      print('   3. Winrate >= 6% + MaxLose <= 50 + Vừa mới xuất hiện (win streak = 1)');
    }
    print('');
    return; // Thoát sớm nếu không có cặp nào
  }
  
  // Sắp xếp theo composite score (MaxLose ngắn nhất + Winrate cao)
  qualifiedPairs.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  
  // Lấy TopN
  final topNPairs = qualifiedPairs.take(TOP_N).toList();
  
  // =======================
  // IN KẾT QUẢ
  // =======================
  print('=====================TOP $TOP_N CẶP SỐ TỐT NHẤT=====================');
  if (isOption1) {
    print('(Option 1 - 1 trong 2 số: Theo 3 khuyến nghị phù hợp với xác suất cao)');
  } else {
    print('(Option 2 - Cả 2 số cùng ngày: Theo 3 khuyến nghị phù hợp với xác suất trung bình)');
  }
  print('Tổng số cặp đạt điều kiện: ${qualifiedPairs.length}\n');
  
  for (int i = 0; i < topNPairs.length; i++) {
    final pair = topNPairs[i];
    
    print('${(i + 1).toString().padLeft(2)}. $pair');
    
    // Hiển thị thông tin cầu lose/win
    if (pair.currentLoseStreak > 0) {
      print('    ⚠️  Đang lose streak: ${pair.currentLoseStreak} lần (Max từng có: ${pair.maxLoseStreak})');
    } else if (pair.currentWinStreak > 0) {
      print('    ✅ Đang win streak: ${pair.currentWinStreak} lần (Max từng có: ${pair.maxWinStreak})');
    } else {
      // Trường hợp này chỉ xảy ra khi chưa có dữ liệu (chưa từng xuất hiện)
      print('    ℹ️  Chưa có dữ liệu');
    }
    print('');
  }
  
  // =======================
  // THỐNG KÊ TỔNG QUAN
  // =======================
  print('=====================THỐNG KÊ TỔNG QUAN=====================');
  final totalPairs = allPairs.length;
  final validPairs = allPairs.where((p) => p.total > 0).length;
  final highWinratePairs = allPairs.where((p) => p.winrate > 50).length;
  
  print('Tổng số cặp số: $totalPairs');
  print('Cặp có dữ liệu: $validPairs');
  print('Cặp có Winrate > 50%: $highWinratePairs');
  
  if (topNPairs.isNotEmpty) {
    final avgWinrate = topNPairs.map((p) => p.winrate).reduce((a, b) => a + b) / topNPairs.length;
    final avgMaxLose = topNPairs.map((p) => p.maxLoseStreak).reduce((a, b) => a + b) / topNPairs.length;
    final avgCurrentLose = topNPairs.map((p) => p.currentLoseStreak).reduce((a, b) => a + b) / topNPairs.length;
    
    print('\nTrung bình Top $TOP_N:');
    print('  Winrate: ${avgWinrate.toStringAsFixed(2)}%');
    print('  MaxLoseStreak: ${avgMaxLose.toStringAsFixed(1)}');
    print('  CurrentLoseStreak: ${avgCurrentLose.toStringAsFixed(1)}');
  }
  
  // =======================
  // DEBUG LOG CHO CẶP SỐ CỤ THỂ
  // =======================
  print('\n=====================DEBUG CẶP SỐ=====================');
  stdout.write('Nhập cặp số để xem debug (ví dụ: 16-49 hoặc 16,49): ');
  final debugInput = stdin.readLineSync()?.trim() ?? '';
  
  if (debugInput.isNotEmpty) {
    // Parse input: có thể là "16-49" hoặc "16,49" hoặc "16 49"
    final parts = debugInput.replaceAll('-', ',').replaceAll(' ', ',').split(',');
    if (parts.length == 2) {
      try {
        final num1 = int.parse(parts[0].trim());
        final num2 = int.parse(parts[1].trim());
        
        // Đảm bảo num1 < num2
        final minNum = num1 < num2 ? num1 : num2;
        final maxNum = num1 < num2 ? num2 : num1;
        
        final key = '${minNum}_$maxNum';
        final debugPair = pairStats[key];
        
        if (debugPair != null) {
          print('\n=====================DEBUG CẶP ${minNum.toString().padLeft(2, '0')}-${maxNum.toString().padLeft(2, '0')}=====================');
          print('Winrate: ${debugPair.winrate.toStringAsFixed(2)}%');
          print('MaxLose: ${debugPair.maxLoseStreak}');
          print('Hit: ${debugPair.hit}/${debugPair.total}');
          
          if (debugPair.currentLoseStreak > 0) {
            print('⚠️  Đang lose streak: ${debugPair.currentLoseStreak} lần');
          } else if (debugPair.currentWinStreak > 0) {
            print('✅ Đang win streak: ${debugPair.currentWinStreak} lần');
          }
          
          print('Max từng có: ${debugPair.maxLoseReachedCount}/${debugPair.maxLoseStreak}');
          
          if (debugPair.lastMaxLoseDate != null) {
            print('Ngày maxLose gần nhất: ${debugPair.lastMaxLoseDate}');
          } else {
            print('Ngày maxLose gần nhất: Chưa có');
          }
          
          // Hiển thị thông tin về lần xuất hiện gần nhất
          if (debugPair.appearDates.isNotEmpty) {
            final sortedAppearDates = List<String>.from(debugPair.appearDates)
              ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a))); // Sort mới nhất trước
            print('Tổng số lần xuất hiện (cả 2 số): ${debugPair.appearDates.length}');
            print('Lần xuất hiện gần nhất: ${sortedAppearDates.first}');
            print('5 lần xuất hiện gần đây:');
            for (int i = 0; i < min(5, sortedAppearDates.length); i++) {
              print('  - ${sortedAppearDates[i]}');
            }
          }
          
          // Hiển thị tất cả các ngày đã hit (sort từ quá khứ đến hiện tại)
          print('Các ngày đã hit (${debugPair.hitDates.length} lần):');
          if (debugPair.hitDates.isEmpty) {
            print('  (Chưa có ngày nào)');
          } else {
            // Sort hitDates từ quá khứ đến hiện tại (2022 -> 2025)
            final sortedHitDates = List<String>.from(debugPair.hitDates)
              ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
            
            // Hiển thị tất cả các ngày hit, mỗi dòng 1 ngày (từ quá khứ đến hiện tại)
            for (final hitDate in sortedHitDates) {
              print('  - $hitDate');
            }
          }
          
          print('======================================================');
        } else {
          print('❌ Không tìm thấy cặp số ${minNum.toString().padLeft(2, '0')}-${maxNum.toString().padLeft(2, '0')}');
        }
      } catch (e) {
        print('❌ Lỗi: Không thể parse cặp số. Vui lòng nhập đúng format (ví dụ: 16-49)');
      }
    } else {
      print('❌ Lỗi: Format không đúng. Vui lòng nhập 2 số (ví dụ: 16-49)');
    }
  }
}

Future<void> processTriples() async {
  print('Đã chọn: Cả 3 số phải xuất hiện cùng 1 ngày\n');
  
  // Load data
  final data = await loadDataModels('data.csv');
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
  
  print('Đã load ${data.length} ngày dữ liệu\n');
  
  // =======================
  // TẠO TẤT CẢ BỘ 3 SỐ TỪ OTHERS (0-99)
  // =======================
  final Map<String, TripleStat> tripleStats = {};
  
  // Tạo tất cả bộ 3 số có thể từ 0-99 (không trùng, sắp xếp)
  for (int num1 = 0; num1 < 100; num1++) {
    for (int num2 = num1 + 1; num2 < 100; num2++) {
      for (int num3 = num2 + 1; num3 < 100; num3++) {
        final key = '${num1}_${num2}_$num3';
        tripleStats[key] = TripleStat(num1, num2, num3);
      }
    }
  }
  
  print('Đã tạo ${tripleStats.length} bộ 3 số duy nhất\n');
  
  // =======================
  // THỐNG KÊ: Track pattern "nếu xuất hiện hôm nay, có xuất hiện ngày mai không"
  // =======================
  final Map<String, int> lastAppearDayIndex = {};
  
  for (int i = 0; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];
    
    // Lấy tất cả số của ngày hôm nay và ngày mai
    final todayNumbers = today.others.toSet();
    final tomorrowNumbers = tomorrow.others.toSet();
    
    // Track các bộ 3 số
    for (final triple in tripleStats.values) {
      final key = '${triple.num1}_${triple.num2}_${triple.num3}';
      
      // Kiểm tra bộ 3 số có xuất hiện trong ngày hôm nay không? (cả 3 số)
      final existsToday = todayNumbers.contains(triple.num1) && 
                          todayNumbers.contains(triple.num2) && 
                          todayNumbers.contains(triple.num3);
      
      if (existsToday) {
        // Lưu ngày xuất hiện (cả 3 số)
        triple.appearDates.add(today.date);
        
        // Nếu xuất hiện hôm nay, kiểm tra có xuất hiện ngày mai không?
        final existsTomorrow = tomorrowNumbers.contains(triple.num1) && 
                               tomorrowNumbers.contains(triple.num2) && 
                               tomorrowNumbers.contains(triple.num3);
        
        // Tính lose streak dựa trên số ngày từ lần xuất hiện gần nhất
        if (lastAppearDayIndex.containsKey(key)) {
          final daysSinceLastAppear = i - lastAppearDayIndex[key]!;
          if (daysSinceLastAppear > 1) {
            final newLoseStreak = daysSinceLastAppear - 1;
            triple.maxLoseStreak = max(triple.maxLoseStreak, newLoseStreak);
          }
        }
        
        // Win nếu xuất hiện cả hôm nay và ngày mai
        triple.addResult(existsTomorrow);
        
        // Nếu hit (xuất hiện ngày mai), lưu ngày mai vào danh sách hit
        if (existsTomorrow) {
          triple.hitDates.add(tomorrow.date);
        }
        
        // Cập nhật ngày xuất hiện gần nhất
        lastAppearDayIndex[key] = i;
      } else {
        // Nếu không xuất hiện hôm nay, tính lose streak từ lần xuất hiện gần nhất
        if (lastAppearDayIndex.containsKey(key)) {
          final daysSinceLastAppear = i - lastAppearDayIndex[key]!;
          triple.currentLoseStreak = daysSinceLastAppear;
          triple.maxLoseStreak = max(triple.maxLoseStreak, daysSinceLastAppear);
        } else {
          triple.currentLoseStreak = i + 1;
          triple.maxLoseStreak = max(triple.maxLoseStreak, i + 1);
        }
      }
    }
  }
  
  // =======================
  // TÍNH LẠI CURRENT LOSE STREAK, MAXLOSE REACHED COUNT VÀ LAST MAXLOSE DATE
  // =======================
  for (final triple in tripleStats.values) {
    triple.maxLoseReachedCount = 0;
    triple.lastMaxLoseDate = null;
    
    // Tìm tất cả các lần xuất hiện trong toàn bộ dữ liệu
    final appearIndices = <int>[];
    for (int i = 0; i < data.length; i++) {
      final day = data[i];
      final dayNumbers = day.others.toSet();
      final exists = dayNumbers.contains(triple.num1) && 
                     dayNumbers.contains(triple.num2) && 
                     dayNumbers.contains(triple.num3);
      if (exists) {
        appearIndices.add(i);
      }
    }
    
    // Tính currentLoseStreak
    if (appearIndices.isNotEmpty) {
      final lastAppearIndex = appearIndices.last;
      if (lastAppearIndex == data.length - 1) {
        triple.currentLoseStreak = 0;
      } else {
        triple.currentLoseStreak = (data.length - 1 - lastAppearIndex) as int;
      }
    } else {
      triple.currentLoseStreak = data.length;
    }
    
    // Tính lại maxLose: tìm kỳ lose dài nhất TRƯỚC ngày xuất hiện gần nhất
    // MaxLose = số ngày liên tiếp không xuất hiện dài nhất (chỉ tính trong quá khứ, trước lastAppearIndex)
    int calculatedMaxLose = 0;
    
    if (appearIndices.isEmpty) {
      // Trường hợp đặc biệt: Chưa từng xuất hiện
      // MaxLose = 0 (vì không có kỳ lose nào trong quá khứ, chỉ có kỳ lose hiện tại)
      calculatedMaxLose = 0;
    } else {
      final lastAppearIndex = appearIndices.last;
      
      // Chỉ tính các kỳ lose TRƯỚC lastAppearIndex
      // Trường hợp 1: Lose streak từ đầu đến lần xuất hiện đầu tiên (nếu firstAppearIndex < lastAppearIndex)
      final firstAppearIndex = appearIndices.first;
      if (firstAppearIndex > 0 && firstAppearIndex < lastAppearIndex) {
        calculatedMaxLose = firstAppearIndex;
      }
      
      // Trường hợp 2: Lose streak giữa các lần xuất hiện (chỉ tính đến trước lastAppearIndex)
      for (int i = 1; i < appearIndices.length; i++) {
        final currentAppearIndex = appearIndices[i];
        // Chỉ tính nếu currentAppearIndex < lastAppearIndex (trước ngày xuất hiện gần nhất)
        if (currentAppearIndex < lastAppearIndex) {
          final prevAppearIndex = appearIndices[i - 1];
          final loseStreak = currentAppearIndex - prevAppearIndex - 1;
          calculatedMaxLose = max(calculatedMaxLose, loseStreak);
        }
      }
    }
    
    triple.maxLoseStreak = calculatedMaxLose;
    
    // Tìm ngày về gần nhất trong quá khứ mà có kỳ lose dài nhất (maxLose)
    // Chỉ tìm trong các kỳ lose TRƯỚC ngày xuất hiện gần nhất (lastAppearIndex)
    triple.maxLoseReachedCount = 0;
    triple.lastMaxLoseDate = null;
    
    if (triple.maxLoseStreak > 0 && appearIndices.isNotEmpty) {
      final lastAppearIndex = appearIndices.last;
      int closestMaxLoseEndIndex = -1; // Index của ngày cuối cùng của kỳ lose gần nhất (trước lastAppearIndex)
      
      // Kiểm tra lose streak từ đầu đến lần xuất hiện đầu tiên
      final firstAppearIndex = appearIndices.first;
      if (firstAppearIndex > 0 && firstAppearIndex < lastAppearIndex && firstAppearIndex == triple.maxLoseStreak) {
        // Ngày cuối của kỳ lose này là ngày trước khi xuất hiện lần đầu
        final endIndex = firstAppearIndex - 1;
        if (endIndex >= 0 && (closestMaxLoseEndIndex == -1 || endIndex > closestMaxLoseEndIndex)) {
          closestMaxLoseEndIndex = endIndex;
        }
        triple.maxLoseReachedCount++;
      }
      
      // Kiểm tra lose streak giữa các lần xuất hiện (chỉ tính đến trước lastAppearIndex)
      for (int i = 1; i < appearIndices.length; i++) {
        final currentAppearIndex = appearIndices[i];
        // Chỉ tính nếu currentAppearIndex < lastAppearIndex
        if (currentAppearIndex < lastAppearIndex) {
          final prevAppearIndex = appearIndices[i - 1];
          final loseStreak = currentAppearIndex - prevAppearIndex - 1;
          
          if (loseStreak == triple.maxLoseStreak) {
            // Ngày cuối của kỳ lose này là ngày trước khi xuất hiện lại
            final endIndex = currentAppearIndex - 1;
            if (closestMaxLoseEndIndex == -1 || endIndex > closestMaxLoseEndIndex) {
              closestMaxLoseEndIndex = endIndex;
            }
            triple.maxLoseReachedCount++;
          }
        }
      }
      
      // Lưu ngày gần nhất (ngày cuối cùng của kỳ lose dài nhất gần nhất trong quá khứ)
      if (closestMaxLoseEndIndex >= 0 && closestMaxLoseEndIndex < data.length) {
        triple.lastMaxLoseDate = data[closestMaxLoseEndIndex].date;
      }
    }
    
    // Tính lại win streak từ appearIndices (toàn bộ data, giống lose streak)
    // Current win streak: đếm từ ngày cuối lên, số ngày liên tiếp xuất hiện
    triple.currentWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      // Đếm từ ngày cuối lên
      for (int i = data.length - 1; i >= 0; i--) {
        if (appearIndices.contains(i)) {
          triple.currentWinStreak++;
        } else {
          break; // Dừng khi gặp ngày không xuất hiện
        }
      }
    }
    
    // Tính maxWinStreak: tìm chuỗi dài nhất các ngày liên tiếp xuất hiện
    triple.maxWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      int tempWinStreak = 0;
      int prevIndex = -2; // Khởi tạo để đảm bảo không trùng với index đầu tiên
      
      for (final appearIndex in appearIndices) {
        if (appearIndex == prevIndex + 1) {
          // Liên tiếp với lần trước
          tempWinStreak++;
        } else {
          // Không liên tiếp, bắt đầu chuỗi mới
          triple.maxWinStreak = max(triple.maxWinStreak, tempWinStreak);
          tempWinStreak = 1;
        }
        prevIndex = appearIndex;
      }
      // Cập nhật chuỗi cuối cùng
      triple.maxWinStreak = max(triple.maxWinStreak, tempWinStreak);
    }
  }
  
  // =======================
  // LỌC VÀ SẮP XẾP: TopN bộ 3 số tốt nhất
  // Điều kiện theo 3 khuyến nghị phù hợp với xác suất thấp (0.5-3%)
  // Xác suất thấp → Total nhỏ (5-30), Winrate thường 2-8%, MaxLose rất dài (60-200+)
  // =======================
  final allTriples = tripleStats.values.toList();
  
  // Lọc các bộ có đủ dữ liệu (total >= 2, giảm từ 3 để phù hợp với xác suất thấp)
  // Lưu ý: Với total < 5, kết quả có thể không ổn định, nhưng vẫn hiển thị để tham khảo
  final filteredTriples = allTriples.where((t) => t.total >= 2).toList();
  
  // Lọc theo 3 khuyến nghị (điều kiện thấp hơn cho xác suất thấp)
  // Loại bỏ các bộ có currentLoseStreak vượt quá maxLoseStreak
  final qualifiedTriples = filteredTriples.where((t) {
    // Loại bỏ nếu currentLoseStreak > maxLoseStreak
    if (t.currentLoseStreak > t.maxLoseStreak && t.maxLoseStreak > 0) {
      return false;
    }
    
    // Khuyến nghị 1: Winrate >= 3% + MaxLose <= 80 + Lose streak >= 70% của MaxLose
    if (t.winrate >= 3.0 && t.maxLoseStreak > 0 && t.maxLoseStreak <= 80) {
      if (t.currentLoseStreak > 0) {
        final loseStreakRatio = t.currentLoseStreak / t.maxLoseStreak;
        if (loseStreakRatio >= 0.7) {
          return true; // Đạt khuyến nghị 1
        }
      }
    }
    
    // Khuyến nghị 2: Winrate >= 2% + MaxLose <= 60 + Đang win streak
    if (t.winrate >= 2.0 && t.maxLoseStreak > 0 && t.maxLoseStreak <= 60) {
      if (t.currentWinStreak > 0) {
        return true; // Đạt khuyến nghị 2
      }
    }
    
    // Khuyến nghị 3: Winrate >= 3% + MaxLose <= 80 + Vừa mới xuất hiện (currentWinStreak = 1)
    if (t.winrate >= 3.0 && t.maxLoseStreak > 0 && t.maxLoseStreak <= 80) {
      if (t.currentWinStreak == 1) {
        return true; // Đạt khuyến nghị 3
      }
    }
    
    return false; // Không đạt điều kiện nào
  }).toList();
  
  // Nếu không có bộ nào đạt điều kiện, thông báo
  if (qualifiedTriples.isEmpty) {
    print('⚠️  Không có bộ 3 số nào đạt các điều kiện khuyến nghị.');
    print('   Điều kiện (Option 3 - Cả 3 số cùng ngày, xác suất thấp):');
    print('   1. Winrate >= 3% + MaxLose <= 80 + Lose streak >= 70% của MaxLose');
    print('   2. Winrate >= 2% + MaxLose <= 60 + Đang win streak');
    print('   3. Winrate >= 3% + MaxLose <= 80 + Vừa mới xuất hiện (win streak = 1)');
    print('');
    print('   📌 Lưu ý: Option 3 có xác suất thấp (0.5-3%), cần dữ liệu lịch sử dài.');
    print('   Với total < 5, kết quả có thể không ổn định.');
    print('');
    return; // Thoát sớm nếu không có bộ nào
  }
  
  // Sắp xếp theo composite score
  qualifiedTriples.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  
  // Lấy TopN
  final topNTriples = qualifiedTriples.take(TOP_N).toList();
  
  // =======================
  // IN KẾT QUẢ
  // =======================
  print('=====================TOP $TOP_N BỘ 3 SỐ TỐT NHẤT=====================');
  print('(Option 3 - Cả 3 số cùng ngày: Theo 3 khuyến nghị phù hợp với xác suất thấp)');
  print('Tổng số bộ đạt điều kiện: ${qualifiedTriples.length}');
  
  // Đếm số bộ có total < 5 (cảnh báo độ tin cậy thấp)
  final lowReliabilityCount = qualifiedTriples.where((t) => t.total < 5).length;
  if (lowReliabilityCount > 0) {
    print('⚠️  Lưu ý: $lowReliabilityCount bộ có total < 5 (độ tin cậy thấp, chỉ tham khảo)');
  }
  print('');
  
  for (int i = 0; i < topNTriples.length; i++) {
    final triple = topNTriples[i];
    
    print('${(i + 1).toString().padLeft(2)}. $triple');
    
    // Hiển thị thông tin cầu lose/win
    if (triple.currentLoseStreak > 0) {
      print('    ⚠️  Đang lose streak: ${triple.currentLoseStreak} lần (Max từng có: ${triple.maxLoseStreak})');
    } else if (triple.currentWinStreak > 0) {
      print('    ✅ Đang win streak: ${triple.currentWinStreak} lần (Max từng có: ${triple.maxWinStreak})');
    } else {
      // Trường hợp này chỉ xảy ra khi chưa có dữ liệu (chưa từng xuất hiện)
      print('    ℹ️  Chưa có dữ liệu');
    }
    print('');
  }
  
  // =======================
  // THỐNG KÊ TỔNG QUAN
  // =======================
  print('=====================THỐNG KÊ TỔNG QUAN=====================');
  final totalTriples = allTriples.length;
  final validTriples = allTriples.where((t) => t.total > 0).length;
  final highWinrateTriples = allTriples.where((t) => t.winrate > 50).length;
  
  print('Tổng số bộ 3 số: $totalTriples');
  print('Bộ có dữ liệu: $validTriples');
  print('Bộ có Winrate > 50%: $highWinrateTriples');
  
  if (topNTriples.isNotEmpty) {
    final avgWinrate = topNTriples.map((t) => t.winrate).reduce((a, b) => a + b) / topNTriples.length;
    final avgMaxLose = topNTriples.map((t) => t.maxLoseStreak).reduce((a, b) => a + b) / topNTriples.length;
    final avgCurrentLose = topNTriples.map((t) => t.currentLoseStreak).reduce((a, b) => a + b) / topNTriples.length;
    
    print('\nTrung bình Top $TOP_N:');
    print('  Winrate: ${avgWinrate.toStringAsFixed(2)}%');
    print('  MaxLoseStreak: ${avgMaxLose.toStringAsFixed(1)}');
    print('  CurrentLoseStreak: ${avgCurrentLose.toStringAsFixed(1)}');
  }
  
  // =======================
  // DEBUG LOG CHO BỘ 3 SỐ CỤ THỂ
  // =======================
  print('\n=====================DEBUG BỘ 3 SỐ=====================');
  stdout.write('Nhập bộ 3 số để xem debug (ví dụ: 16-49-77 hoặc 16,49,77): ');
  final debugInput = stdin.readLineSync()?.trim() ?? '';
  
  if (debugInput.isNotEmpty) {
    // Parse input: có thể là "16-49-77" hoặc "16,49,77" hoặc "16 49 77"
    final parts = debugInput.replaceAll('-', ',').replaceAll(' ', ',').split(',');
    if (parts.length == 3) {
      try {
        final num1 = int.parse(parts[0].trim());
        final num2 = int.parse(parts[1].trim());
        final num3 = int.parse(parts[2].trim());
        
        // Sắp xếp để tìm key
        final nums = [num1, num2, num3]..sort();
        final key = '${nums[0]}_${nums[1]}_${nums[2]}';
        final debugTriple = tripleStats[key];
        
        if (debugTriple != null) {
          print('\n=====================DEBUG BỘ ${nums[0].toString().padLeft(2, '0')}-${nums[1].toString().padLeft(2, '0')}-${nums[2].toString().padLeft(2, '0')}=====================');
          print('Winrate: ${debugTriple.winrate.toStringAsFixed(2)}%');
          print('MaxLose: ${debugTriple.maxLoseStreak}');
          print('Hit: ${debugTriple.hit}/${debugTriple.total}');
          
          if (debugTriple.currentLoseStreak > 0) {
            print('⚠️  Đang lose streak: ${debugTriple.currentLoseStreak} lần');
          } else if (debugTriple.currentWinStreak > 0) {
            print('✅ Đang win streak: ${debugTriple.currentWinStreak} lần');
          }
          
          print('Max từng có: ${debugTriple.maxLoseReachedCount}/${debugTriple.maxLoseStreak}');
          
          if (debugTriple.lastMaxLoseDate != null) {
            print('Ngày maxLose gần nhất: ${debugTriple.lastMaxLoseDate}');
          } else {
            print('Ngày maxLose gần nhất: Chưa có');
          }
          
          // Hiển thị thông tin về lần xuất hiện gần nhất
          if (debugTriple.appearDates.isNotEmpty) {
            final sortedAppearDates = List<String>.from(debugTriple.appearDates)
              ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
            print('Tổng số lần xuất hiện (cả 3 số): ${debugTriple.appearDates.length}');
            print('Lần xuất hiện gần nhất: ${sortedAppearDates.first}');
            print('5 lần xuất hiện gần đây:');
            for (int i = 0; i < min(5, sortedAppearDates.length); i++) {
              print('  - ${sortedAppearDates[i]}');
            }
          }
          
          // Hiển thị tất cả các ngày đã hit
          print('Các ngày đã hit (${debugTriple.hitDates.length} lần):');
          if (debugTriple.hitDates.isEmpty) {
            print('  (Chưa có ngày nào)');
          } else {
            final sortedHitDates = List<String>.from(debugTriple.hitDates)
              ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
            
            for (final hitDate in sortedHitDates) {
              print('  - $hitDate');
            }
          }
          
          print('======================================================');
        } else {
          print('❌ Không tìm thấy bộ 3 số ${nums[0].toString().padLeft(2, '0')}-${nums[1].toString().padLeft(2, '0')}-${nums[2].toString().padLeft(2, '0')}');
        }
      } catch (e) {
        print('❌ Lỗi: Không thể parse bộ 3 số. Vui lòng nhập đúng format (ví dụ: 16-49-77)');
      }
    } else {
      print('❌ Lỗi: Format không đúng. Vui lòng nhập 3 số (ví dụ: 16-49-77)');
    }
  }
}
