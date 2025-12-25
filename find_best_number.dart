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
      print('Đã chọn: ${useOrLogic ? "1 trong 2 số" : "Cả 2 số"}\n');
      await processPairs(useOrLogic);
    }
    
    // Hỏi có muốn tiếp tục không
    print('\n========================END===========================');
    stdout.write('Nhập "y" để tiếp tục hoặc "n" để thoát: ');
    final continueInput = (stdin.readLineSync()?.trim() ?? '').toLowerCase();
    shouldContinue = continueInput == 'y' || continueInput == 'yes';
  }
  
  print('Đã thoát chương trình.');
}

Future<void> processPairs(bool useOrLogic) async {
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
    
    // Tính lại maxLose dựa trên các chuỗi lose streak giữa các lần xuất hiện
    if (appearIndices.length > 1) {
      int calculatedMaxLose = 0;
      for (int i = 1; i < appearIndices.length; i++) {
        final currentAppearIndex = appearIndices[i];
        final prevAppearIndex = appearIndices[i - 1];
        final loseStreak = currentAppearIndex - prevAppearIndex - 1;
        calculatedMaxLose = max(calculatedMaxLose, loseStreak);
      }
      
      // Cập nhật maxLose
      pair.maxLoseStreak = calculatedMaxLose;
      
      // Tính lại currentLoseStreak từ lần xuất hiện gần nhất đến cuối (nếu có)
      final lastAppearIndex = appearIndices.last;
      if (lastAppearIndex < data.length - 1) {
        final currentLoseFromLast = data.length - 1 - lastAppearIndex;
        pair.maxLoseStreak = max(pair.maxLoseStreak, currentLoseFromLast);
      }
    }
    
    // Tính các chuỗi lose streak giữa các lần xuất hiện
    for (int i = 1; i < appearIndices.length; i++) {
      final currentAppearIndex = appearIndices[i];
      final prevAppearIndex = appearIndices[i - 1];
      final loseStreak = currentAppearIndex - prevAppearIndex - 1;
      
      // Nếu chuỗi lose streak này đạt đúng maxLose
      if (loseStreak == pair.maxLoseStreak && pair.maxLoseStreak > 0) {
        pair.maxLoseReachedCount++;
        // Ngày cuối cùng của chuỗi lose streak là ngày trước khi xuất hiện lại
        final maxLoseDate = data[currentAppearIndex - 1].date;
        // Cập nhật ngày gần nhất
        if (pair.lastMaxLoseDate == null || 
            DateTime.parse(maxLoseDate).isAfter(DateTime.parse(pair.lastMaxLoseDate!))) {
          pair.lastMaxLoseDate = maxLoseDate;
        }
      }
    }
    
    // Kiểm tra chuỗi lose streak hiện tại (từ lần xuất hiện gần nhất đến cuối)
    if (appearIndices.isNotEmpty && pair.maxLoseStreak > 0) {
      final lastAppearIndex = appearIndices.last;
      final currentLoseStreak = lastAppearIndex < data.length - 1 
          ? data.length - 1 - lastAppearIndex 
          : 0;
      
      if (currentLoseStreak == pair.maxLoseStreak && currentLoseStreak > 0 && data.length > 1) {
        // Đang đạt maxLose, ngày gần nhất là ngày cuối cùng (hôm qua)
        final currentLoseDate = data[data.length - 2].date;
        if (pair.lastMaxLoseDate == null || 
            DateTime.parse(currentLoseDate).isAfter(DateTime.parse(pair.lastMaxLoseDate!))) {
          pair.lastMaxLoseDate = currentLoseDate;
        }
      }
    }
    
    // Tính lại win streak từ history
    if (pair.history.isNotEmpty) {
      pair.currentWinStreak = 0;
      pair.maxWinStreak = 0;
      
      int tempWinStreak = 0;
      for (int i = 0; i < pair.history.length; i++) {
        if (pair.history[i]) {
          tempWinStreak++;
          pair.maxWinStreak = max(pair.maxWinStreak, tempWinStreak);
        } else {
          tempWinStreak = 0;
        }
      }
      
      // Tính current win streak từ cuối
      for (int i = pair.history.length - 1; i >= 0; i--) {
        if (pair.history[i]) {
          pair.currentWinStreak++;
        } else {
          break;
        }
      }
    }
  }
  
  // =======================
  // LỌC VÀ SẮP XẾP: TopN cặp số tốt nhất
  // Ưu tiên: MaxLose ngắn nhất (tốt nhất), Winrate cao
  // =======================
  final allPairs = pairStats.values.toList();
  
  // Lọc các cặp có đủ dữ liệu (total >= 3)
  final filteredPairs = allPairs.where((p) => p.total >= 3).toList();
  
  // Sắp xếp theo composite score (MaxLose ngắn nhất + Winrate cao)
  filteredPairs.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  
  // Lấy TopN
  final topNPairs = filteredPairs.take(TOP_N).toList();
  
  // =======================
  // IN KẾT QUẢ
  // =======================
  print('=====================TOP $TOP_N CẶP SỐ TỐT NHẤT=====================');
  print('(Sắp xếp theo: MaxLose ngắn nhất, Winrate cao)\n');
  
  for (int i = 0; i < topNPairs.length; i++) {
    final pair = topNPairs[i];
    
    print('${(i + 1).toString().padLeft(2)}. $pair');
    
    // Hiển thị thông tin cầu lose
    if (pair.currentLoseStreak > 0) {
      print('    ⚠️  Đang lose streak: ${pair.currentLoseStreak} lần (Max từng có: ${pair.maxLoseStreak})');
    } else if (pair.currentWinStreak > 0) {
      print('    ✅ Đang win streak: ${pair.currentWinStreak} lần');
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
    
    // Tính lại maxLose
    if (appearIndices.length > 1) {
      int calculatedMaxLose = 0;
      for (int i = 1; i < appearIndices.length; i++) {
        final currentAppearIndex = appearIndices[i];
        final prevAppearIndex = appearIndices[i - 1];
        final loseStreak = currentAppearIndex - prevAppearIndex - 1;
        calculatedMaxLose = max(calculatedMaxLose, loseStreak);
      }
      
      triple.maxLoseStreak = calculatedMaxLose;
      
      final lastAppearIndex = appearIndices.last;
      if (lastAppearIndex < data.length - 1) {
        final currentLoseFromLast = data.length - 1 - lastAppearIndex;
        triple.maxLoseStreak = max(triple.maxLoseStreak, currentLoseFromLast);
      }
    }
    
    // Tính maxLoseReachedCount và lastMaxLoseDate
    for (int i = 1; i < appearIndices.length; i++) {
      final currentAppearIndex = appearIndices[i];
      final prevAppearIndex = appearIndices[i - 1];
      final loseStreak = currentAppearIndex - prevAppearIndex - 1;
      
      if (loseStreak == triple.maxLoseStreak && triple.maxLoseStreak > 0) {
        triple.maxLoseReachedCount++;
        final maxLoseDate = data[currentAppearIndex - 1].date;
        if (triple.lastMaxLoseDate == null || 
            DateTime.parse(maxLoseDate).isAfter(DateTime.parse(triple.lastMaxLoseDate!))) {
          triple.lastMaxLoseDate = maxLoseDate;
        }
      }
    }
    
    // Kiểm tra chuỗi lose streak hiện tại
    if (appearIndices.isNotEmpty && triple.maxLoseStreak > 0) {
      final lastAppearIndex = appearIndices.last;
      final currentLoseStreak = lastAppearIndex < data.length - 1 
          ? data.length - 1 - lastAppearIndex 
          : 0;
      
      if (currentLoseStreak == triple.maxLoseStreak && currentLoseStreak > 0 && data.length > 1) {
        final currentLoseDate = data[data.length - 2].date;
        if (triple.lastMaxLoseDate == null || 
            DateTime.parse(currentLoseDate).isAfter(DateTime.parse(triple.lastMaxLoseDate!))) {
          triple.lastMaxLoseDate = currentLoseDate;
        }
      }
    }
    
    // Tính lại win streak từ history
    if (triple.history.isNotEmpty) {
      triple.currentWinStreak = 0;
      triple.maxWinStreak = 0;
      
      int tempWinStreak = 0;
      for (int i = 0; i < triple.history.length; i++) {
        if (triple.history[i]) {
          tempWinStreak++;
          triple.maxWinStreak = max(triple.maxWinStreak, tempWinStreak);
        } else {
          tempWinStreak = 0;
        }
      }
      
      for (int i = triple.history.length - 1; i >= 0; i--) {
        if (triple.history[i]) {
          triple.currentWinStreak++;
        } else {
          break;
        }
      }
    }
  }
  
  // =======================
  // LỌC VÀ SẮP XẾP: TopN bộ 3 số tốt nhất
  // =======================
  final allTriples = tripleStats.values.toList();
  
  // Lọc các bộ có đủ dữ liệu (total >= 3)
  final filteredTriples = allTriples.where((t) => t.total >= 3).toList();
  
  // Sắp xếp theo composite score
  filteredTriples.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  
  // Lấy TopN
  final topNTriples = filteredTriples.take(TOP_N).toList();
  
  // =======================
  // IN KẾT QUẢ
  // =======================
  print('=====================TOP $TOP_N BỘ 3 SỐ TỐT NHẤT=====================');
  print('(Sắp xếp theo: MaxLose ngắn nhất, Winrate cao)\n');
  
  for (int i = 0; i < topNTriples.length; i++) {
    final triple = topNTriples[i];
    
    print('${(i + 1).toString().padLeft(2)}. $triple');
    
    // Hiển thị thông tin cầu lose
    if (triple.currentLoseStreak > 0) {
      print('    ⚠️  Đang lose streak: ${triple.currentLoseStreak} lần (Max từng có: ${triple.maxLoseStreak})');
    } else if (triple.currentWinStreak > 0) {
      print('    ✅ Đang win streak: ${triple.currentWinStreak} lần');
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
