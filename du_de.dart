import 'dart:io';

import 'data_model.dart';

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

// Lấy 4 số cuối và tách thành các chữ số (giữ tất cả, không loại bỏ trùng)
List<int> getAllDigitsFromLast4(List<int> others) {
  if (others.length < 4) return [];
  
  final last4 = [
    others[others.length - 1],
    others[others.length - 2],
    others[others.length - 3],
    others[others.length - 4],
  ];
  
  // Tách thành các chữ số (giữ tất cả)
  final digits = <int>[];
  for (final num in last4) {
    final numStr = num.toString().padLeft(2, '0');
    digits.add(int.parse(numStr[0])); // Hàng chục
    digits.add(int.parse(numStr[1])); // Hàng đơn vị
  }
  
  return digits;
}

// Triệt tiêu các số giống nhau (nếu có 2 số giống nhau thì loại bỏ cả 2)
List<int> eliminatePairs(List<int> digits) {
  final frequency = <int, int>{};
  
  // Đếm tần suất
  for (final digit in digits) {
    frequency[digit] = (frequency[digit] ?? 0) + 1;
  }
  
  // Chỉ giữ các số có tần suất lẻ (không bị triệt tiêu)
  final result = <int>[];
  for (final digit in digits) {
    if (frequency[digit]! % 2 == 1) {
      result.add(digit);
      frequency[digit] = frequency[digit]! - 1; // Đánh dấu đã lấy
    }
  }
  
  return result;
}

// Lấy 4 số cuối và loại bỏ số trùng, chỉ giữ các chữ số duy nhất
List<int> getUniqueDigitsFromLast4(List<int> others) {
  if (others.length < 4) return [];
  
  final last4 = [
    others[others.length - 1],
    others[others.length - 2],
    others[others.length - 3],
    others[others.length - 4],
  ];
  
  // Tách thành các chữ số và loại bỏ trùng
  final digits = <int>{};
  for (final num in last4) {
    final numStr = num.toString().padLeft(2, '0');
    digits.add(int.parse(numStr[0])); // Hàng chục
    digits.add(int.parse(numStr[1])); // Hàng đơn vị
  }
  
  return digits.toList()..sort();
}

// Quy tắc 0: Triệt tiêu các số giống nhau, sau đó tạo các cặp số từ số còn lại
Set<int> rule0_EliminatePairs(List<int> allDigits) {
  // Triệt tiêu các số giống nhau
  final remainingDigits = eliminatePairs(allDigits);
  
  if (remainingDigits.isEmpty) return {};
  
  // Tạo tất cả các cặp số từ các số còn lại
  final pairs = <int>{};
  for (int i = 0; i < remainingDigits.length; i++) {
    for (int j = 0; j < remainingDigits.length; j++) {
      if (i != j) {
        pairs.add(remainingDigits[i] * 10 + remainingDigits[j]);
      }
    }
  }
  return pairs;
}

// Quy tắc 1: Tạo tất cả các cặp số có thể từ các chữ số (hoán vị 2 chữ số)
Set<int> rule1_AllPairs(List<int> digits) {
  final pairs = <int>{};
  for (int i = 0; i < digits.length; i++) {
    for (int j = 0; j < digits.length; j++) {
      if (i != j) {
        pairs.add(digits[i] * 10 + digits[j]);
      }
    }
  }
  return pairs;
}

// Quy tắc 2: Tạo các cặp số từ chữ số đầu với các chữ số còn lại
Set<int> rule2_FirstWithOthers(List<int> digits) {
  if (digits.isEmpty) return {};
  final pairs = <int>{};
  final first = digits[0];
  for (int i = 1; i < digits.length; i++) {
    pairs.add(first * 10 + digits[i]);
    pairs.add(digits[i] * 10 + first);
  }
  return pairs;
}

// Quy tắc 3: Tạo các cặp số từ 2 chữ số đầu và 2 chữ số cuối
Set<int> rule3_First2Last2(List<int> digits) {
  if (digits.length < 2) return {};
  final pairs = <int>{};
  final first = digits[0];
  final second = digits[1];
  final last = digits[digits.length - 1];
  final secondLast = digits.length > 2 ? digits[digits.length - 2] : digits[1];
  
  pairs.add(first * 10 + last);
  pairs.add(last * 10 + first);
  pairs.add(second * 10 + secondLast);
  pairs.add(secondLast * 10 + second);
  
  return pairs;
}

// Quy tắc 4: Tạo các cặp số liên tiếp (chữ số i với i+1)
Set<int> rule4_Consecutive(List<int> digits) {
  final pairs = <int>{};
  for (int i = 0; i < digits.length - 1; i++) {
    pairs.add(digits[i] * 10 + digits[i + 1]);
    pairs.add(digits[i + 1] * 10 + digits[i]);
  }
  return pairs;
}

// Quy tắc 5: Tạo các cặp số từ chữ số xuất hiện nhiều nhất với các chữ số khác
Set<int> rule5_MostFrequentWithOthers(List<int> digits) {
  if (digits.isEmpty) return {};
  // Đếm tần suất
  final frequency = <int, int>{};
  for (final d in digits) {
    frequency[d] = (frequency[d] ?? 0) + 1;
  }
  
  // Tìm chữ số xuất hiện nhiều nhất
  int maxFreq = 0;
  int mostFrequent = digits[0];
  for (final entry in frequency.entries) {
    if (entry.value > maxFreq) {
      maxFreq = entry.value;
      mostFrequent = entry.key;
    }
  }
  
  final pairs = <int>{};
  for (final d in digits) {
    if (d != mostFrequent) {
      pairs.add(mostFrequent * 10 + d);
      pairs.add(d * 10 + mostFrequent);
    }
  }
  return pairs;
}

// Quy tắc 6: Tạo các cặp số từ chữ số đầu, giữa, cuối
Set<int> rule6_FirstMiddleLast(List<int> digits) {
  if (digits.isEmpty) return {};
  final pairs = <int>{};
  final first = digits[0];
  final last = digits[digits.length - 1];
  final middle = digits[digits.length ~/ 2];
  
  pairs.add(first * 10 + middle);
  pairs.add(middle * 10 + first);
  pairs.add(first * 10 + last);
  pairs.add(last * 10 + first);
  pairs.add(middle * 10 + last);
  pairs.add(last * 10 + middle);
  
  return pairs;
}

// Quy tắc 7: Tạo các cặp số từ 2 chữ số đầu tiên và 2 chữ số cuối cùng (theo thứ tự)
Set<int> rule7_First2AndLast2(List<int> digits) {
  if (digits.length < 2) return {};
  final pairs = <int>{};
  final first = digits[0];
  final second = digits.length > 1 ? digits[1] : digits[0];
  final last = digits[digits.length - 1];
  final secondLast = digits.length > 1 ? digits[digits.length - 2] : digits[0];
  
  pairs.add(first * 10 + second);
  pairs.add(second * 10 + first);
  pairs.add(last * 10 + secondLast);
  pairs.add(secondLast * 10 + last);
  pairs.add(first * 10 + last);
  pairs.add(last * 10 + first);
  pairs.add(second * 10 + secondLast);
  pairs.add(secondLast * 10 + second);
  
  return pairs;
}

// Kiểm tra xem có cặp số nào trong danh sách dự đoán xuất hiện trong others của ngày A+1 không
bool checkHit(Set<int> predictions, List<int> nextDayOthers) {
  for (final pred in predictions) {
    if (nextDayOthers.contains(pred)) {
      return true;
    }
  }
  return false;
}

// Backtest rule0 (triệt tiêu các số giống nhau)
Map<String, dynamic> backtestRule0(
  List<DataModel> sortedData,
) {
  int totalDays = 0;
  int hitCount = 0;
  
  for (int i = 0; i < sortedData.length - 1; i++) {
    final currentDay = sortedData[i];
    final nextDay = sortedData[i + 1];
    
    // Lấy tất cả các chữ số từ 4 số cuối (không loại bỏ trùng)
    final allDigits = getAllDigitsFromLast4(currentDay.others);
    
    if (allDigits.isEmpty) continue;
    
    // Tạo danh sách dự đoán theo rule0 (triệt tiêu và tạo cặp)
    final predictions = rule0_EliminatePairs(allDigits);
    
    if (predictions.isEmpty) continue;
    
    // Kiểm tra hit
    if (checkHit(predictions, nextDay.others)) {
      hitCount++;
    }
    
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'rule': 'Rule 0: Triệt tiêu số giống nhau, tạo cặp từ số còn lại',
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
  };
}

// Backtest một quy tắc
Map<String, dynamic> backtestRule(
  List<DataModel> sortedData,
  String ruleName,
  Set<int> Function(List<int>) ruleFunction,
) {
  int totalDays = 0;
  int hitCount = 0;
  
  for (int i = 0; i < sortedData.length - 1; i++) {
    final currentDay = sortedData[i];
    final nextDay = sortedData[i + 1];
    
    // Lấy các chữ số duy nhất từ 4 số cuối
    final digits = getUniqueDigitsFromLast4(currentDay.others);
    
    if (digits.isEmpty) continue;
    
    // Tạo danh sách dự đoán theo quy tắc
    final predictions = ruleFunction(digits);
    
    if (predictions.isEmpty) continue;
    
    // Kiểm tra hit
    if (checkHit(predictions, nextDay.others)) {
      hitCount++;
    }
    
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'rule': ruleName,
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
  };
}

Future<void> main() async {
  final data = await loadDataModels('data.csv');

  final dataWithDate = data
      .map((d) => (
            model: d,
            dateTime: DateTime.parse(d.date),
          ))
      .toList();
  dataWithDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final sortedData = dataWithDate.map((e) => e.model).toList();

  // Định nghĩa các quy tắc
  final results = <Map<String, dynamic>>[];
  final rules = [
    ('Rule 1: Tất cả các cặp số (hoán vị)', rule1_AllPairs),
    ('Rule 2: Chữ số đầu với các chữ số khác', rule2_FirstWithOthers),
    ('Rule 3: 2 chữ số đầu và 2 chữ số cuối', rule3_First2Last2),
    ('Rule 4: Các cặp số liên tiếp', rule4_Consecutive),
    ('Rule 5: Chữ số xuất hiện nhiều nhất với các chữ số khác', rule5_MostFrequentWithOthers),
    ('Rule 6: Chữ số đầu, giữa, cuối', rule6_FirstMiddleLast),
    ('Rule 7: 2 chữ số đầu và 2 chữ số cuối (theo thứ tự)', rule7_First2AndLast2),
  ];
  
  // Backtest các quy tắc đơn lẻ
  print('\n${'=' * 100}');
  print('BACKTEST CÁC QUY TẮC ĐƠN LẺ (KHÔNG KẾT HỢP)');
  print('${'=' * 100}');
  print('${'Quy tắc'.padRight(60)} | ${'Tổng ngày'.padRight(12)} | ${'Hit'.padRight(8)} | ${'Winrate'.padRight(10)}');
  print('${'-' * 100}');
  
  for (final rule in rules) {
    final result = backtestRule(sortedData, rule.$1, rule.$2);
    results.add(result);
    
    final ruleName = result['rule'] as String;
    final totalDays = result['totalDays'] as int;
    final hitCount = result['hitCount'] as int;
    final winrate = result['winrate'] as double;
    
    print('${ruleName.padRight(60)} | ${totalDays.toString().padRight(12)} | ${hitCount.toString().padRight(8)} | ${winrate.toStringAsFixed(2)}%');
  }
  
  // Sắp xếp tất cả kết quả theo winrate giảm dần
  results.sort((a, b) => (b['winrate'] as double).compareTo(a['winrate'] as double));
  
  print('${'=' * 100}');
  
  // Hiển thị quy tắc tốt nhất tổng thể
  final bestRule = results[0];
  print('\n🏆 QUY TẮC TỐT NHẤT TỔNG THỂ:');
  print('   ${bestRule['rule']}');
  print('   Winrate: ${(bestRule['winrate'] as double).toStringAsFixed(2)}%');
  print('   Hit: ${bestRule['hitCount']}/${bestRule['totalDays']}');
  print('${'=' * 100}\n');
  
  // ============================================
  // PHƯƠNG ÁN 5: Sử dụng số xuất hiện gần đây nhất (CẢI THIỆN) + TÍCH HỢP LOSE METRICS
  // ============================================
  print('\n${'=' * 100}');
  print('PHƯƠNG ÁN 5: SỬ DỤNG SỐ XUẤT HIỆN GẦN ĐÂY NHẤT + TÍCH HỢP LOSE METRICS');
  print('${'=' * 100}');
  
  final result5 = testApproach5_WithLoseMetrics(sortedData);
  print('\n📊 KẾT QUẢ PHƯƠNG ÁN 5 (3 NGÀY LOOKBACK, TOP 2 CẶP SỐ):');
  print('   Winrate: ${(result5['winrate'] as double).toStringAsFixed(2)}%');
  print('   Hit: ${result5['hitCount']}/${result5['totalDays']}');
  print('   MaxLose: ${result5['maxLose']} ngày');
  print('   CurrentLose: ${result5['currentLose']} ngày');
  
  // Chuyển đổi chuỗi hit/lose thành W/L
  final hits = result5['hits'] as List<bool>;
  final wlString = hits.map((h) => h ? 'W' : 'L').join('');
  print('   Chuỗi W/L (${hits.length} ngày): $wlString');
  
  print('${'=' * 100}');
  
  // ============================================
  // PHƯƠNG ÁN: CẢ GỐC VÀ ĐẢO NGƯỢC (4 CẶP SỐ)
  // ============================================
  print('\n${'=' * 100}');
  print('PHƯƠNG ÁN: CẢ GỐC VÀ ĐẢO NGƯỢC (4 CẶP SỐ)');
  print('${'=' * 100}');
  
  final resultB = testApproachB_BothOriginalAndReversed(sortedData);
  
  // Lấy dự đoán cho ngày mới nhất
  final latestPrediction = getLatestPrediction(sortedData);
  final allPairs = <int>[];
  
  if (!latestPrediction.containsKey('error')) {
    final predictions = latestPrediction['predictions'] as List<dynamic>;
    for (final pred in predictions) {
      final pair = pred['pair'] as int;
      allPairs.add(pair);
      allPairs.add(reversePair(pair));
    }
  }
  
  // Tính lose metrics cho từng cặp số
  final currentIndex = sortedData.length - 1;
  final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, currentIndex);
  
  print('\n📊 KẾT QUẢ:');
  print('   Winrate tổng: ${(resultB['winrate'] as double).toStringAsFixed(2)}%');
  print('   Hit: ${resultB['hitCount']}/${resultB['totalDays']}');
  print('   4 cặp số: ${allPairs.map((p) => p.toString().padLeft(2, '0')).join(', ')}');
  
  print('\n📊 CHI TIẾT TỪNG CẶP SỐ:');
  print('   ${'Cặp số'.padRight(10)} | ${'Winrate'.padRight(10)} | ${'Lose'.padRight(8)} | ${'MaxLose'.padRight(10)} | ${'CurrentLose'.padRight(13)}');
  print('   ${'-' * 60}');
  
  // Tính winrate cho từng cặp số dựa trên lịch sử xuất hiện
  for (final pair in allPairs) {
    final info = pairLoseInfo[pair]!;
    
    // Tính winrate: số lần xuất hiện / tổng số ngày
    int hitCount = 0;
    for (int i = 0; i <= currentIndex; i++) {
      if (sortedData[i].others.contains(pair)) {
        hitCount++;
      }
    }
    final winrate = (currentIndex + 1) > 0 ? (hitCount / (currentIndex + 1) * 100) : 0.0;
    
    // Chỉ hiển thị 10 lose ranges gần đây nhất
    final loseRangesStr = info.loseRanges.isEmpty 
        ? '-' 
        : info.loseRanges.length > 10
            ? '${info.loseRanges.sublist(info.loseRanges.length - 10).join(', ')}...'
            : info.loseRanges.join(', ');
    
    print('   ${pair.toString().padLeft(2, '0').padRight(10)} | ${winrate.toStringAsFixed(2).padRight(10)}% | ${loseRangesStr.padRight(8)} | ${info.maxLose.toString().padRight(10)} | ${info.currentLose.toString().padRight(13)}');
  }
  
  print('${'=' * 100}\n');
  
}

// Backtest với top N cặp số
Map<String, dynamic> backtestTopPairs(
  List<DataModel> sortedData,
  List<int> topPairs,
) {
  int totalDays = 0;
  int hitCount = 0;
  
  for (int i = 0; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    // Kiểm tra xem có cặp số nào trong topPairs xuất hiện trong others của ngày A+1 không
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    if (hit) {
      hitCount++;
    }
    
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
  };
}

// ============================================
// TÍNH LOSE METRICS CHO TỪNG CẶP SỐ (00-99) TRONG OTHERS
// ============================================

// Cấu trúc lưu thông tin lose cho một cặp số
class PairLoseInfo {
  int maxLose = 0;
  int currentLose = 0;
  List<int> loseRanges = [];
  bool hasAppeared = false; // Đã từng xuất hiện chưa
}

// Tính lose metrics cho tất cả các cặp số (00-99) trong others
// Chỉ tính dựa trên dữ liệu từ đầu đến currentIndex (không nhìn tương lai)
Map<int, PairLoseInfo> calculateLoseMetricsForAllPairs(
  List<DataModel> sortedData,
  int currentIndex,
) {
  final pairInfo = <int, PairLoseInfo>{};
  
  // Khởi tạo cho tất cả cặp số 00-99
  for (int i = 0; i <= 99; i++) {
    pairInfo[i] = PairLoseInfo();
  }
  
  // Chỉ tính dựa trên dữ liệu từ đầu đến currentIndex
  final dataToUse = sortedData.sublist(0, currentIndex + 1);
  
  // Tính lose cho từng cặp số
  for (int pair = 0; pair <= 99; pair++) {
    final hits = <bool>[];
    
    // Xác định hit/lose cho từng ngày
    for (int i = 0; i < dataToUse.length; i++) {
      final day = dataToUse[i];
      final isHit = day.others.contains(pair);
      hits.add(isHit);
      
      if (isHit) {
        pairInfo[pair]!.hasAppeared = true;
      }
    }
    
    // Tính lose ranges (chỉ giữa các hit, không tính currentlose)
    final loseRanges = <int>[];
    int currentLoseCount = 0;
    bool inLoseStreak = false;
    
    for (int i = 0; i < hits.length; i++) {
      if (hits[i]) {
        // Hit: nếu đang trong lose streak, lưu lose range
        if (inLoseStreak && currentLoseCount > 0) {
          loseRanges.add(currentLoseCount);
        }
        currentLoseCount = 0;
        inLoseStreak = false;
      } else {
        // Lose: tăng đếm
        currentLoseCount++;
        inLoseStreak = true;
      }
    }
    
    // Tính maxLose từ loseRanges
    int maxLose = 0;
    if (loseRanges.isNotEmpty) {
      maxLose = loseRanges.reduce((a, b) => a > b ? a : b);
    }
    
    // Tính currentLose (từ hit cuối cùng đến ngày mới nhất)
    int currentLose = 0;
    for (int i = hits.length - 1; i >= 0; i--) {
      if (hits[i]) {
        break; // Gặp hit, dừng lại
      }
      currentLose++;
    }
    
    pairInfo[pair]!.maxLose = maxLose;
    pairInfo[pair]!.currentLose = currentLose;
    pairInfo[pair]!.loseRanges = loseRanges;
  }
  
  return pairInfo;
}

// Tính điểm lose cho một cặp số theo phương án đề xuất
double calculateLoseScore(PairLoseInfo info) {
  // Trường hợp chưa từng xuất hiện
  if (!info.hasAppeared) {
    return 0.0; // Chỉ dựa vào tần suất gần đây
  }
  
  // Trường hợp maxlose = 0 (chưa có lose trong lịch sử)
  if (info.maxLose == 0) {
    return 0.0; // Chỉ dựa vào tần suất gần đây
  }
  
  // Trường hợp currentlose = 0 (vừa xuất hiện)
  if (info.currentLose == 0) {
    return -0.3; // Tránh, nhưng không loại bỏ hoàn toàn
  }
  
  // Trường hợp currentlose > maxlose (vượt quá mức bình thường)
  if (info.currentLose > info.maxLose) {
    return 1.5; // Ưu tiên cao
  }
  
  // Trường hợp currentlose < maxlose * 0.8 (chưa đến lượt)
  if (info.currentLose < info.maxLose * 0.8) {
    return 0.0; // Chưa đến lượt
  }
  
  // Trường hợp maxlose * 0.8 <= currentlose <= maxlose (sắp đến lượt)
  return info.currentLose / info.maxLose; // Normalize về 0-1
}

// ============================================
// PHƯƠNG ÁN 5: SỬ DỤNG SỐ XUẤT HIỆN GẦN ĐÂY NHẤT + TÍCH HỢP LOSE METRICS
// ============================================

// Tính tần suất có trọng số cho các số gần đây
Map<int, double> calculateWeightedFrequency(
  List<DataModel> sortedData,
  int currentIndex,
  int lookbackDays,
) {
  final frequency = <int, double>{};
  
  // Trọng số: số gần đây có trọng số cao hơn
  final startIndex = (currentIndex - lookbackDays + 1).clamp(0, currentIndex);
  
  for (int i = startIndex; i <= currentIndex; i++) {
    final weight = (i - startIndex + 1).toDouble(); // Trọng số tăng dần
    final day = sortedData[i];
    
    for (final num in day.others) {
      frequency[num] = (frequency[num] ?? 0.0) + weight;
    }
  }
  
  return frequency;
}

// Normalize điểm về 0-1
double normalizeScore(double score, double minScore, double maxScore) {
  if (maxScore == minScore) return 0.5;
  return (score - minScore) / (maxScore - minScore);
}

// Phương án 5 với tích hợp lose metrics (3 ngày lookback, top 2 cặp số)
Map<String, dynamic> testApproach5_WithLoseMetrics(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[]; // Lưu chuỗi hit/lose để tính lose metrics
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    // Tính lose metrics cho tất cả cặp số dựa trên dữ liệu từ đầu đến ngày hiện tại
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    
    // Tính tần suất có trọng số từ 3 ngày gần nhất (A, A-1, A-2)
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    // Tính điểm tổng hợp cho mỗi cặp số
    final scores = <int, double>{};
    
    for (int pair = 0; pair <= 99; pair++) {
      // Điểm tần suất gần đây (normalize về 0-1)
      final recentFreq = weightedFreq[pair] ?? 0.0;
      
      // Tìm min/max để normalize
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      // Điểm lose
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      
      // Điểm tổng hợp
      // Lose score có thể âm (-0.3) hoặc > 1 (1.5), nên normalize về 0-1
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    // Lấy top N cặp số có điểm cao nhất
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairs = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    
    // Kiểm tra hit
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    hits.add(hit);
    if (hit) {
      hitCount++;
    }
    
    totalDays++;
  }
  
  // Tính lose metrics từ chuỗi hit/lose
  final loseRanges = <int>[];
  int currentLoseCount = 0;
  bool inLoseStreak = false;
  
  for (int i = 0; i < hits.length; i++) {
    if (hits[i]) {
      // Hit: nếu đang trong lose streak, lưu lose range
      if (inLoseStreak && currentLoseCount > 0) {
        loseRanges.add(currentLoseCount);
      }
      currentLoseCount = 0;
      inLoseStreak = false;
    } else {
      // Lose: tăng đếm
      currentLoseCount++;
      inLoseStreak = true;
    }
  }
  
  // Tính maxLose từ loseRanges
  int maxLose = 0;
  if (loseRanges.isNotEmpty) {
    maxLose = loseRanges.reduce((a, b) => a > b ? a : b);
  }
  
  // Tính currentLose (từ hit cuối cùng đến ngày mới nhất)
  int currentLose = 0;
  for (int i = hits.length - 1; i >= 0; i--) {
    if (hits[i]) {
      break; // Gặp hit, dừng lại
    }
    currentLose++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'loseRanges': loseRanges,
    'maxLose': maxLose,
    'currentLose': currentLose,
    'hits': hits,
  };
}

// Lấy dự đoán top 2 cặp số cho ngày mới nhất
Map<String, dynamic> getLatestPrediction(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  if (sortedData.length < lookbackDays) {
    return {'error': 'Không đủ dữ liệu'};
  }
  
  final currentIndex = sortedData.length - 1;
  final latestDay = sortedData[currentIndex];
  
  // Tính lose metrics cho tất cả cặp số dựa trên dữ liệu từ đầu đến ngày hiện tại
  final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, currentIndex);
  
  // Tính tần suất có trọng số từ 3 ngày gần nhất (A, A-1, A-2)
  final weightedFreq = calculateWeightedFrequency(sortedData, currentIndex, lookbackDays);
  
  // Tính điểm tổng hợp cho mỗi cặp số
  final scores = <int, Map<String, double>>{};
  
  for (int pair = 0; pair <= 99; pair++) {
    // Điểm tần suất gần đây (normalize về 0-1)
    final recentFreq = weightedFreq[pair] ?? 0.0;
    
    // Tìm min/max để normalize
    final allFreqs = weightedFreq.values.toList();
    if (allFreqs.isEmpty) continue;
    
    final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
    final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
    final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
    
    // Điểm lose
    final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
    
    // Điểm tổng hợp
    final normalizedLoseScore = loseScore < 0 
        ? 0.0 
        : (loseScore > 1.0 ? 1.0 : loseScore);
    
    final totalScore = normalizedFreq * w1 + normalizedLoseScore * w2;
    
    scores[pair] = {
      'totalScore': totalScore,
      'freqScore': normalizedFreq,
      'loseScore': normalizedLoseScore,
      'weightedFreq': recentFreq,
    };
  }
  
  // Lấy top N cặp số có điểm cao nhất
  final sortedPairs = scores.entries.toList()
    ..sort((a, b) => b.value['totalScore']!.compareTo(a.value['totalScore']!));
  
  final topPairs = sortedPairs.take(topNPairs).map((e) {
    final pair = e.key;
    final scoreInfo = e.value;
    
    return {
      'pair': pair,
      'totalScore': scoreInfo['totalScore']!,
      'freqScore': scoreInfo['freqScore']!,
      'loseScore': scoreInfo['loseScore']!,
      'weightedFreq': scoreInfo['weightedFreq']!,
    };
  }).toList();
  
  // Tính ngày dự đoán (ngày sau ngày mới nhất)
  final latestDate = DateTime.parse(latestDay.date);
  final predictionDate = latestDate.add(const Duration(days: 1));
  
  return {
    'latestDate': latestDay.date,
    'predictionDate': predictionDate.toString().substring(0, 10),
    'predictions': topPairs,
  };
}

// Đảo ngược cặp số: 25 → 52, 48 → 84
int reversePair(int pair) {
  final tens = pair ~/ 10;
  final units = pair % 10;
  return units * 10 + tens;
}

// Phương án A: So sánh winrate giữa gốc và đảo ngược
Map<String, dynamic> testApproachA_CompareOriginalVsReversed(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCountOriginal = 0;
  int hitCountReversed = 0;
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    // Tính lose metrics cho tất cả cặp số dựa trên dữ liệu từ đầu đến ngày hiện tại
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    
    // Tính tần suất có trọng số từ 3 ngày gần nhất
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    // Tính điểm tổng hợp cho mỗi cặp số
    final scores = <int, double>{};
    
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    // Lấy top N cặp số có điểm cao nhất (gốc)
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    
    // Đảo ngược các cặp số
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Kiểm tra hit cho gốc
    bool hitOriginal = false;
    for (final pair in topPairsOriginal) {
      if (nextDay.others.contains(pair)) {
        hitOriginal = true;
        break;
      }
    }
    
    // Kiểm tra hit cho đảo ngược
    bool hitReversed = false;
    for (final pair in topPairsReversed) {
      if (nextDay.others.contains(pair)) {
        hitReversed = true;
        break;
      }
    }
    
    if (hitOriginal) hitCountOriginal++;
    if (hitReversed) hitCountReversed++;
    
    totalDays++;
  }
  
  final winrateOriginal = totalDays > 0 ? (hitCountOriginal / totalDays * 100) : 0.0;
  final winrateReversed = totalDays > 0 ? (hitCountReversed / totalDays * 100) : 0.0;
  
  return {
    'totalDays': totalDays,
    'hitCountOriginal': hitCountOriginal,
    'hitCountReversed': hitCountReversed,
    'winrateOriginal': winrateOriginal,
    'winrateReversed': winrateReversed,
  };
}

// Phương án B: Thử cả gốc và đảo ngược (4 cặp số)
Map<String, dynamic> testApproachB_BothOriginalAndReversed(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCount = 0;
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    // Tính lose metrics cho tất cả cặp số dựa trên dữ liệu từ đầu đến ngày hiện tại
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    
    // Tính tần suất có trọng số từ 3 ngày gần nhất
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    // Tính điểm tổng hợp cho mỗi cặp số
    final scores = <int, double>{};
    
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    // Lấy top N cặp số có điểm cao nhất (gốc)
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    
    // Đảo ngược các cặp số
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Kết hợp cả gốc và đảo ngược (4 cặp số)
    final allPairs = <int>{...topPairsOriginal, ...topPairsReversed};
    
    // Kiểm tra hit
    bool hit = false;
    for (final pair in allPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
  };
}

// Phương án C: Chọn top 2 từ cả gốc và đảo ngược
Map<String, dynamic> testApproachC_Top2FromBothOriginalAndReversed(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCount = 0;
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    // Tính lose metrics cho tất cả cặp số dựa trên dữ liệu từ đầu đến ngày hiện tại
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    
    // Tính tần suất có trọng số từ 3 ngày gần nhất
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    // Tính điểm tổng hợp cho mỗi cặp số (gốc)
    final scoresOriginal = <int, double>{};
    
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scoresOriginal[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    // Tính điểm cho cặp số đảo ngược
    final scoresReversed = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final reversedPair = reversePair(pair);
      // Lấy điểm từ cặp số gốc (vì đảo ngược có cùng điểm)
      scoresReversed[reversedPair] = scoresOriginal[pair] ?? 0.0;
    }
    
    // Kết hợp cả gốc và đảo ngược, lấy top 2
    final allScores = <int, double>{...scoresOriginal, ...scoresReversed};
    
    final sortedPairs = allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairs = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    
    // Kiểm tra hit
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
  };
}

// Phương án D: Chiến lược động - L thì chuyển sang đảo ngược, W thì giữ nguyên
Map<String, dynamic> testApproachD_DynamicStrategy(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  bool useOriginal = true; // Bắt đầu bằng phương án gốc
  int maxLStreak = 0; // Chu kỳ L liên tiếp dài nhất
  int currentLStreak = 0; // Chu kỳ L liên tiếp hiện tại
  int switchCount = 0; // Số lần chuyển đổi phương án
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    // Tính lose metrics cho tất cả cặp số dựa trên dữ liệu từ đầu đến ngày hiện tại
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    
    // Tính tần suất có trọng số từ 3 ngày gần nhất
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    // Tính điểm tổng hợp cho mỗi cặp số
    final scores = <int, double>{};
    
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    // Lấy top N cặp số có điểm cao nhất
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Chọn phương án dựa trên chiến lược động
    final topPairs = useOriginal ? topPairsOriginal : topPairsReversed;
    
    // Kiểm tra hit
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    hits.add(hit);
    
    // Cập nhật chu kỳ L liên tiếp
    if (hit) {
      currentLStreak = 0;
    } else {
      currentLStreak++;
      if (currentLStreak > maxLStreak) {
        maxLStreak = currentLStreak;
      }
    }
    
    // Chiến lược động: L thì chuyển sang đảo ngược, W thì giữ nguyên
    if (hit) {
      // W: giữ nguyên phương án hiện tại
      // Không cần làm gì
    } else {
      // L: chuyển sang phương án đảo ngược
      if (useOriginal) {
        useOriginal = false;
        switchCount++;
      } else {
        useOriginal = true;
        switchCount++;
      }
    }
    
    if (hit) hitCount++;
    totalDays++;
  }
  
  // Tính lose metrics từ chuỗi hit/lose
  final loseRanges = <int>[];
  int currentLoseCount = 0;
  bool inLoseStreak = false;
  
  for (int i = 0; i < hits.length; i++) {
    if (hits[i]) {
      if (inLoseStreak && currentLoseCount > 0) {
        loseRanges.add(currentLoseCount);
      }
      currentLoseCount = 0;
      inLoseStreak = false;
    } else {
      currentLoseCount++;
      inLoseStreak = true;
    }
  }
  
  int maxLose = 0;
  if (loseRanges.isNotEmpty) {
    maxLose = loseRanges.reduce((a, b) => a > b ? a : b);
  }
  
  int currentLose = 0;
  for (int i = hits.length - 1; i >= 0; i--) {
    if (hits[i]) {
      break;
    }
    currentLose++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'loseRanges': loseRanges,
    'maxLose': maxLose,
    'currentLose': currentLose,
    'hits': hits,
    'maxLStreak': maxLStreak,
    'switchCount': switchCount,
  };
}

// Phương án E1: Dựa trên điểm số - So sánh điểm tổng hợp giữa gốc và đảo ngược
Map<String, dynamic> testApproachE1_ScoreBased(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4, double threshold = 0.05}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    final scores = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Tính điểm trung bình của gốc và đảo ngược
    final avgScoreOriginal = topPairsOriginal.map((p) => scores[p]!).reduce((a, b) => a + b) / topNPairs;
    final avgScoreReversed = topPairsReversed.map((p) => scores[reversePair(p)]!).reduce((a, b) => a + b) / topNPairs;
    
    // Quyết định: nếu điểm đảo ngược > điểm gốc + threshold → dùng đảo ngược
    final useReversed = avgScoreReversed > avgScoreOriginal + threshold;
    final topPairs = useReversed ? topPairsReversed : topPairsOriginal;
    
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    hits.add(hit);
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'hits': hits,
  };
}

// Phương án E2: Dựa trên lịch sử gần đây - Winrate của gốc vs đảo ngược trong N ngày gần đây
Map<String, dynamic> testApproachE2_RecentHistory(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4, int historyWindow = 10}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  final historyOriginal = <bool>[];
  final historyReversed = <bool>[];
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    final scores = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Tính winrate gần đây
    double winrateOriginal = 0.5;
    double winrateReversed = 0.5;
    
    if (historyOriginal.length >= historyWindow) {
      final recentOriginal = historyOriginal.sublist(historyOriginal.length - historyWindow);
      winrateOriginal = recentOriginal.where((h) => h).length / historyWindow;
    }
    
    if (historyReversed.length >= historyWindow) {
      final recentReversed = historyReversed.sublist(historyReversed.length - historyWindow);
      winrateReversed = recentReversed.where((h) => h).length / historyWindow;
    }
    
    // Quyết định: chọn phương án có winrate cao hơn
    final useReversed = winrateReversed > winrateOriginal;
    
    // Kiểm tra hit cho cả 2 phương án
    bool hitOriginal = false;
    for (final pair in topPairsOriginal) {
      if (nextDay.others.contains(pair)) {
        hitOriginal = true;
        break;
      }
    }
    
    bool hitReversed = false;
    for (final pair in topPairsReversed) {
      if (nextDay.others.contains(pair)) {
        hitReversed = true;
        break;
      }
    }
    
    historyOriginal.add(hitOriginal);
    historyReversed.add(hitReversed);
    
    final hit = useReversed ? hitReversed : hitOriginal;
    hits.add(hit);
    
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'hits': hits,
  };
}

// Phương án E3: Dựa trên lose metrics
Map<String, dynamic> testApproachE3_LoseMetrics(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  int currentLoseOriginal = 0;
  int maxLoseOriginal = 0;
  final loseRangesOriginal = <int>[];
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    final scores = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Quyết định dựa trên lose metrics
    bool useReversed = false;
    if (maxLoseOriginal > 0) {
      final ratio = currentLoseOriginal / maxLoseOriginal;
      if (ratio >= 0.8) {
        // Gốc đang không hiệu quả → thử đảo ngược
        useReversed = true;
      } else if (ratio < 0.5) {
        // Gốc đang ổn → giữ gốc
        useReversed = false;
      } else {
        // So sánh điểm số
        final avgScoreOriginal = topPairsOriginal.map((p) => scores[p]!).reduce((a, b) => a + b) / topNPairs;
        final avgScoreReversed = topPairsReversed.map((p) => scores[reversePair(p)]!).reduce((a, b) => a + b) / topNPairs;
        useReversed = avgScoreReversed > avgScoreOriginal;
      }
    }
    
    final topPairs = useReversed ? topPairsReversed : topPairsOriginal;
    
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    // Cập nhật lose metrics cho gốc
    if (hit && !useReversed) {
      if (currentLoseOriginal > 0) {
        loseRangesOriginal.add(currentLoseOriginal);
        if (currentLoseOriginal > maxLoseOriginal) {
          maxLoseOriginal = currentLoseOriginal;
        }
      }
      currentLoseOriginal = 0;
    } else if (!hit && !useReversed) {
      currentLoseOriginal++;
    }
    
    hits.add(hit);
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'hits': hits,
  };
}

// Phương án E4: Dựa trên pattern W/L gần đây
Map<String, dynamic> testApproachE4_PatternBased(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4, int patternWindow = 5}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  final patternOriginal = <bool>[];
  final patternReversed = <bool>[];
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    final scores = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Phân tích pattern gần đây
    bool useReversed = false;
    
    if (patternOriginal.length >= patternWindow) {
      final recentOriginal = patternOriginal.sublist(patternOriginal.length - patternWindow);
      final lStreak = recentOriginal.reversed.takeWhile((h) => !h).length;
      
      if (lStreak >= 3) {
        // Gốc đang có chuỗi L dài → thử đảo ngược
        useReversed = true;
      } else if (recentOriginal.last) {
        // Gốc vừa W → giữ gốc
        useReversed = false;
      } else {
        // So sánh với đảo ngược
        if (patternReversed.length >= patternWindow) {
          final recentReversed = patternReversed.sublist(patternReversed.length - patternWindow);
          final wCountOriginal = recentOriginal.where((h) => h).length;
          final wCountReversed = recentReversed.where((h) => h).length;
          useReversed = wCountReversed > wCountOriginal;
        }
      }
    }
    
    // Kiểm tra hit cho cả 2 phương án
    bool hitOriginal = false;
    for (final pair in topPairsOriginal) {
      if (nextDay.others.contains(pair)) {
        hitOriginal = true;
        break;
      }
    }
    
    bool hitReversed = false;
    for (final pair in topPairsReversed) {
      if (nextDay.others.contains(pair)) {
        hitReversed = true;
        break;
      }
    }
    
    patternOriginal.add(hitOriginal);
    patternReversed.add(hitReversed);
    
    final hit = useReversed ? hitReversed : hitOriginal;
    hits.add(hit);
    
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'hits': hits,
  };
}

// Phương án E5: Kết hợp nhiều yếu tố (Scoring System)
Map<String, dynamic> testApproachE5_CombinedScoring(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4, int historyWindow = 10}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  final historyOriginal = <bool>[];
  final historyReversed = <bool>[];
  int currentLoseOriginal = 0;
  int maxLoseOriginal = 0;
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    final scores = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Tính điểm tổng hợp cho mỗi phương án
    final avgScoreOriginal = topPairsOriginal.map((p) => scores[p]!).reduce((a, b) => a + b) / topNPairs;
    final avgScoreReversed = topPairsReversed.map((p) => scores[reversePair(p)]!).reduce((a, b) => a + b) / topNPairs;
    
    double winrateOriginal = 0.5;
    double winrateReversed = 0.5;
    if (historyOriginal.length >= historyWindow) {
      final recentOriginal = historyOriginal.sublist(historyOriginal.length - historyWindow);
      winrateOriginal = recentOriginal.where((h) => h).length / historyWindow;
    }
    if (historyReversed.length >= historyWindow) {
      final recentReversed = historyReversed.sublist(historyReversed.length - historyWindow);
      winrateReversed = recentReversed.where((h) => h).length / historyWindow;
    }
    
    double loseScoreOriginal = 1.0;
    if (maxLoseOriginal > 0) {
      loseScoreOriginal = 1.0 - (currentLoseOriginal / maxLoseOriginal).clamp(0.0, 1.0);
    }
    
    // Tính điểm tổng hợp: Điểm số * 0.4 + Winrate * 0.3 + Lose score * 0.3
    final finalScoreOriginal = avgScoreOriginal * 0.4 + winrateOriginal * 0.3 + loseScoreOriginal * 0.3;
    final finalScoreReversed = avgScoreReversed * 0.4 + winrateReversed * 0.3 + loseScoreOriginal * 0.3;
    
    final useReversed = finalScoreReversed > finalScoreOriginal;
    
    // Kiểm tra hit cho cả 2 phương án
    bool hitOriginal = false;
    for (final pair in topPairsOriginal) {
      if (nextDay.others.contains(pair)) {
        hitOriginal = true;
        break;
      }
    }
    
    bool hitReversed = false;
    for (final pair in topPairsReversed) {
      if (nextDay.others.contains(pair)) {
        hitReversed = true;
        break;
      }
    }
    
    historyOriginal.add(hitOriginal);
    historyReversed.add(hitReversed);
    
    if (hitOriginal && !useReversed) {
      if (currentLoseOriginal > 0) {
        if (currentLoseOriginal > maxLoseOriginal) {
          maxLoseOriginal = currentLoseOriginal;
        }
      }
      currentLoseOriginal = 0;
    } else if (!hitOriginal && !useReversed) {
      currentLoseOriginal++;
    }
    
    final hit = useReversed ? hitReversed : hitOriginal;
    hits.add(hit);
    
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'hits': hits,
  };
}

// Phương án E6: Đơn giản hóa - Luôn chọn phương án có điểm cao hơn
Map<String, dynamic> testApproachE6_SimpleBest(
  List<DataModel> sortedData,
  {int lookbackDays = 3, int topNPairs = 2, double w1 = 0.6, double w2 = 0.4}
) {
  int totalDays = 0;
  int hitCount = 0;
  final hits = <bool>[];
  
  for (int i = lookbackDays - 1; i < sortedData.length - 1; i++) {
    final nextDay = sortedData[i + 1];
    
    final pairLoseInfo = calculateLoseMetricsForAllPairs(sortedData, i);
    final weightedFreq = calculateWeightedFrequency(sortedData, i, lookbackDays);
    
    final scores = <int, double>{};
    for (int pair = 0; pair <= 99; pair++) {
      final recentFreq = weightedFreq[pair] ?? 0.0;
      final allFreqs = weightedFreq.values.toList();
      if (allFreqs.isEmpty) continue;
      
      final minFreq = allFreqs.reduce((a, b) => a < b ? a : b);
      final maxFreq = allFreqs.reduce((a, b) => a > b ? a : b);
      final normalizedFreq = normalizeScore(recentFreq, minFreq, maxFreq);
      
      final loseScore = calculateLoseScore(pairLoseInfo[pair]!);
      final normalizedLoseScore = loseScore < 0 
          ? 0.0 
          : (loseScore > 1.0 ? 1.0 : loseScore);
      
      scores[pair] = normalizedFreq * w1 + normalizedLoseScore * w2;
    }
    
    final sortedPairs = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topPairsOriginal = sortedPairs.take(topNPairs).map((e) => e.key).toList();
    final topPairsReversed = topPairsOriginal.map((p) => reversePair(p)).toList();
    
    // Tính điểm trung bình
    final avgScoreOriginal = topPairsOriginal.map((p) => scores[p]!).reduce((a, b) => a + b) / topNPairs;
    final avgScoreReversed = topPairsReversed.map((p) => scores[reversePair(p)]!).reduce((a, b) => a + b) / topNPairs;
    
    // Luôn chọn phương án có điểm cao hơn
    final useReversed = avgScoreReversed > avgScoreOriginal;
    final topPairs = useReversed ? topPairsReversed : topPairsOriginal;
    
    bool hit = false;
    for (final pair in topPairs) {
      if (nextDay.others.contains(pair)) {
        hit = true;
        break;
      }
    }
    
    hits.add(hit);
    if (hit) hitCount++;
    totalDays++;
  }
  
  final winrate = totalDays > 0 ? (hitCount / totalDays * 100) : 0.0;
  return {
    'totalDays': totalDays,
    'hitCount': hitCount,
    'winrate': winrate,
    'hits': hits,
  };
}
