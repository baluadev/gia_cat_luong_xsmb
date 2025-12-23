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
  // Lưu thông tin số con trúng để tính tiền thắng chính xác
  final List<int> hitCounts = []; // Số con trúng mỗi ngày (1, 2, hoặc 3)
  
  for (final day in sortedData) {
    final othersSet = day.others.toSet();
    
    // Kiểm tra có ít nhất 1 trong 3 số (WIN nếu có 1 hoặc nhiều số, LOSE nếu không có số nào)
    final has91 = othersSet.contains(91);
    final has92 = othersSet.contains(92);
    final has93 = othersSet.contains(93);
    final atLeastOne = has91 || has92 || has93;
    cauBoth.add(atLeastOne);
    
    // Đếm số con trúng
    int hitCount = 0;
    if (has91) hitCount++;
    if (has92) hitCount++;
    if (has93) hitCount++;
    hitCounts.add(hitCount);
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
  // TÍNH PROFIT VỚI CHIẾN LƯỢC GẤP THẾP
  // =======================
  const int initialPoints = 15; // Điểm ban đầu
  const int numberOfNumbers = 3; // Số con đánh (91, 92, 93)
  const double multiplier = 2.0; // Hệ số gấp thếp (x2)
  const int costPerPoint = 22500; // Giá 1 điểm lô (VNĐ)
  const int payoutPerPoint = 80000; // Tiền thắng 1 điểm lô (VNĐ)

  print('\n💰 TÍNH PROFIT VỚI CHIẾN LƯỢC GẤP THẾP:');
  print('============================================================');
  print('  Điểm ban đầu: $initialPoints điểm/con');
  print('  Số con đánh: $numberOfNumbers con (91, 92, 93)');
  print('  Hệ số gấp thếp: x$multiplier');
  print('  Giá 1 điểm: ${costPerPoint.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tiền thắng 1 điểm: ${payoutPerPoint.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');

  // Mô phỏng chiến lược gấp thếp
  int currentPoints = initialPoints;
  int totalCapital = 0; // Tổng vốn đã bỏ ra
  int totalProfit = 0; // Tổng lợi nhuận
  int totalLoseSequences = 0; // Số chuỗi LOSE
  int maxLoseSequenceLength = 0; // Độ dài chuỗi LOSE dài nhất
  int maxCapitalInSequence = 0; // Vốn lớn nhất trong 1 chuỗi LOSE
  final List<Map<String, dynamic>> loseSequences = []; // Lưu thông tin các chuỗi LOSE

  int sequenceStartIndex = -1;
  int sequenceLength = 0;
  int sequenceCapital = 0;

  for (int i = 0; i < cauBoth.history.length; i++) {
    final isWin = cauBoth.history[i];

    if (!isWin) {
      // LOSE: Tính vốn cho ngày này
      if (sequenceStartIndex == -1) {
        sequenceStartIndex = i;
        sequenceLength = 0;
        sequenceCapital = 0;
        currentPoints = initialPoints; // Reset về điểm ban đầu khi bắt đầu chuỗi LOSE mới
      }

      // Tính vốn cho ngày này: số điểm x số con x giá 1 điểm
      final dayCapital = (currentPoints * numberOfNumbers * costPerPoint).round();
      sequenceCapital += dayCapital;
      totalCapital += dayCapital;
      sequenceLength++;

      // Ngày sau gấp đôi điểm
      currentPoints = (currentPoints * multiplier).round();
    } else {
      // WIN: Kết thúc chuỗi LOSE (nếu có)
      if (sequenceStartIndex != -1) {
        // Tính profit khi WIN
        final winPoints = currentPoints;
        final winAmount = (winPoints * numberOfNumbers * payoutPerPoint).round();
        final profit = winAmount - sequenceCapital;

        loseSequences.add({
          'start': sequenceStartIndex,
          'length': sequenceLength,
          'capital': sequenceCapital,
          'winPoints': winPoints,
          'winAmount': winAmount,
          'profit': profit,
        });

        totalProfit += profit;
        totalLoseSequences++;

        if (sequenceLength > maxLoseSequenceLength) {
          maxLoseSequenceLength = sequenceLength;
        }
        if (sequenceCapital > maxCapitalInSequence) {
          maxCapitalInSequence = sequenceCapital;
        }

        // Reset để bắt đầu chuỗi mới
        sequenceStartIndex = -1;
        currentPoints = initialPoints;
      }
    }
  }

  // Xử lý chuỗi LOSE cuối cùng (nếu cầu đang LOSE)
  if (sequenceStartIndex != -1) {
    loseSequences.add({
      'start': sequenceStartIndex,
      'length': sequenceLength,
      'capital': sequenceCapital,
      'winPoints': currentPoints, // Điểm sẽ đánh ngày tiếp theo
      'winAmount': 0, // Chưa thắng
      'profit': -sequenceCapital, // Đang lỗ
    });
    totalLoseSequences++;
    if (sequenceLength > maxLoseSequenceLength) {
      maxLoseSequenceLength = sequenceLength;
    }
    if (sequenceCapital > maxCapitalInSequence) {
      maxCapitalInSequence = sequenceCapital;
    }
  }

  // In kết quả
  print('\n📊 KẾT QUẢ MÔ PHỎNG:');
  print('  Tổng số chuỗi LOSE: $totalLoseSequences');
  print('  Chuỗi LOSE dài nhất: $maxLoseSequenceLength ngày');
  print('  Vốn lớn nhất trong 1 chuỗi: ${maxCapitalInSequence.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng vốn đã bỏ ra: ${totalCapital.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng profit: ${totalProfit.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');

  // In chi tiết các chuỗi LOSE
  if (loseSequences.isNotEmpty) {
    print('\n📋 CHI TIẾT CÁC CHUỖI LOSE:');
    for (int i = 0; i < loseSequences.length && i < 10; i++) {
      final seq = loseSequences[i];
      print('  Chuỗi ${i + 1}: ${seq['length']} ngày LOSE');
      print('    Vốn bỏ ra: ${seq['capital'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
      if (seq['winAmount'] > 0) {
        print('    Điểm đánh khi WIN: ${seq['winPoints']} điểm/con');
        print('    Tiền thắng: ${seq['winAmount'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
        print('    Profit: ${seq['profit'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
      } else {
        print('    ⚠️ Chuỗi chưa kết thúc (đang LOSE)');
        print('    Điểm sẽ đánh ngày tiếp theo: ${seq['winPoints']} điểm/con');
      }
      print('');
    }
    if (loseSequences.length > 10) {
      print('  ... và ${loseSequences.length - 10} chuỗi khác');
    }
  }

  // =======================
  // CHIẾN LƯỢC TĂNG DẦN ĐỀU: Mỗi ngày tăng thêm 5 điểm cho cả 3 con
  // =======================
  const int incrementPoints = 5; // Mỗi ngày tăng thêm 5 điểm tổng
  const int maxDays = 5; // Tính toán cho 5 ngày

  print('\n💰 CHIẾN LƯỢC TĂNG DẦN ĐỀU (Mỗi ngày +$incrementPoints điểm cho cả 3 con):');
  print('============================================================');
  print('  Điểm ban đầu: $initialPoints điểm tổng cho cả 3 con');
  print('  Mỗi ngày tăng: +$incrementPoints điểm tổng');
  print('  Số con đánh: $numberOfNumbers con (91, 92, 93)');
  print('  Tính toán cho: $maxDays ngày');

  // Tính vốn và lợi nhuận cho từng ngày
  int totalCapitalIncremental = 0;
  int totalWinAmountIncremental = 0;
  final List<Map<String, dynamic>> dayDetails = [];

  for (int day = 1; day <= maxDays; day++) {
    // Tổng điểm cho cả 3 con
    final totalPoints = initialPoints + (day - 1) * incrementPoints;
    // Chia đều cho 3 con
    final pointsPerNumber = totalPoints / numberOfNumbers;
    
    // Vốn = tổng điểm * giá 1 điểm
    final dayCapital = (totalPoints * costPerPoint).round();
    // Tiền thắng = số điểm của con trúng * tiền thắng 1 điểm
    // Giả định trúng 1 con (trường hợp tối thiểu)
    final dayWinAmount = (pointsPerNumber * payoutPerPoint).round();
    final dayProfit = dayWinAmount - dayCapital;

    totalCapitalIncremental += dayCapital;
    totalWinAmountIncremental += dayWinAmount;

    dayDetails.add({
      'day': day,
      'totalPoints': totalPoints,
      'pointsPerNumber': pointsPerNumber,
      'capital': dayCapital,
      'winAmount': dayWinAmount,
      'profit': dayProfit,
    });
  }

  final totalProfitIncremental = totalWinAmountIncremental - totalCapitalIncremental;

  print('\n📊 CHI TIẾT TỪNG NGÀY:');
  for (final dayInfo in dayDetails) {
    print('  Ngày ${dayInfo['day']}:');
    print('    Tổng điểm cho 3 con: ${dayInfo['totalPoints']} điểm');
    print('    Điểm/con: ${(dayInfo['pointsPerNumber'] as double).toStringAsFixed(2)} điểm');
    print('    Vốn: ${dayInfo['capital'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
    print('    Tiền thắng (nếu trúng 1 con): ${dayInfo['winAmount'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
    print('    Profit (nếu trúng 1 con): ${dayInfo['profit'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
    print('');
  }

  print('\n📈 TRƯỜNG HỢP TỐT NHẤT: Trúng tối thiểu 1 con mỗi ngày trong $maxDays ngày');
  print('  Tổng vốn: ${totalCapitalIncremental.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng tiền thắng (trúng 1 con mỗi ngày): ${totalWinAmountIncremental.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng profit: ${totalProfitIncremental.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  ROI: ${totalCapitalIncremental > 0 ? ((totalProfitIncremental / totalCapitalIncremental) * 100).toStringAsFixed(2) : 0}%');

  print('\n📉 TRƯỜNG HỢP XẤU NHẤT: Lose tất cả trong $maxDays ngày');
  print('  Tổng vốn (tổng tiền thua): ${totalCapitalIncremental.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng tiền thắng: 0 VNĐ');
  print('  Tổng lỗ: -${totalCapitalIncremental.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');

  // Mô phỏng với dữ liệu thực tế: Tính profit nếu áp dụng chiến lược này
  int actualCapital = 0;
  int actualWinAmount = 0;
  int currentDayInSequence = 0;

  for (int i = 0; i < cauBoth.history.length; i++) {
    final isWin = cauBoth.history[i];
    final hitCount = hitCounts[i]; // Số con trúng thực tế

    if (!isWin) {
      // LOSE: Tăng ngày trong chuỗi
      currentDayInSequence++;
      if (currentDayInSequence <= maxDays) {
        // Tổng điểm cho cả 3 con
        final totalPoints = initialPoints + (currentDayInSequence - 1) * incrementPoints;
        // Vốn = tổng điểm * giá 1 điểm
        final dayCapital = (totalPoints * costPerPoint).round();
        actualCapital += dayCapital;
      }
    } else {
      // WIN: Tính tiền thắng và reset
      if (currentDayInSequence > 0 && currentDayInSequence <= maxDays) {
        // Tổng điểm cho cả 3 con
        final totalPoints = initialPoints + (currentDayInSequence - 1) * incrementPoints;
        // Điểm mỗi con
        final pointsPerNumber = totalPoints / numberOfNumbers;
        // Tiền thắng = số điểm của con trúng × số con trúng × tiền thắng 1 điểm
        final dayWinAmount = (pointsPerNumber * hitCount * payoutPerPoint).round();
        actualWinAmount += dayWinAmount;
      }
      currentDayInSequence = 0;
    }
  }

  // Xử lý chuỗi LOSE cuối cùng (nếu đang LOSE)
  if (currentDayInSequence > 0 && currentDayInSequence <= maxDays) {
    // Chưa thắng, chỉ tính vốn
  }

  final actualProfit = actualWinAmount - actualCapital;

  print('\n🎯 MÔ PHỎNG VỚI DỮ LIỆU THỰC TẾ:');
  print('  Tổng vốn đã bỏ ra: ${actualCapital.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng tiền thắng: ${actualWinAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  Tổng profit: ${actualProfit.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ');
  print('  ROI: ${actualCapital > 0 ? ((actualProfit / actualCapital) * 100).toStringAsFixed(2) : 0}%');

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
  // BÀI TEST SO SÁNH: TÌM CẶP SỐ ĐẦU 9 CÓ CẦU LOSE NGẮN NHẤT
  // =======================
  print('\n\n🔬 BÀI TEST SO SÁNH: TÌM CẶP SỐ ĐẦU 9 CÓ CẦU LOSE NGẮN NHẤT');
  print('============================================================');
  
  final List<int> firstNineNumbers = List.generate(10, (i) => 90 + i); // 90-99
  final List<Map<String, dynamic>> pairStats = [];
  
  // Tạo tất cả các cặp số từ 90-99
  for (int i = 0; i < firstNineNumbers.length; i++) {
    for (int j = i + 1; j < firstNineNumbers.length; j++) {
      final num1 = firstNineNumbers[i];
      final num2 = firstNineNumbers[j];
      
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
  print('  (Tất cả các cặp từ 90-99)');
  print('');
  
  // Hiển thị top 10 cặp có max lose streak ngắn nhất
  print('🏆 TOP 10 CẶP SỐ CÓ CẦU LOSE NGẮN NHẤT:');
  print('============================================================');
  print('  ${'Cặp số'.padRight(10)} | ${'Max LOSE'.padRight(10)} | ${'Max WIN'.padRight(10)} | ${'Winrate'.padRight(10)} | ${'Hiện tại'.padRight(15)}');
  print('  ${'-' * 10} | ${'-' * 10} | ${'-' * 10} | ${'-' * 10} | ${'-' * 15}');
  
  final topN = pairStats.length < 10 ? pairStats.length : 10;
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
