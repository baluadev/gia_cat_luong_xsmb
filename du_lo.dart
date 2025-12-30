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

class PairResult {
  final int num1;
  final int num2;
  final int maxlose;
  final int currentlose;
  final int count;
  final String lastAppearanceDate;
  final int lastLose;
  final String top3LoseFrequent;

  PairResult({
    required this.num1,
    required this.num2,
    required this.maxlose,
    required this.currentlose,
    required this.count,
    required this.lastAppearanceDate,
    required this.lastLose,
    required this.top3LoseFrequent,
  });

  String get pairString => '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}';
}

// Tạo tất cả các cặp số từ 00-99 (không trùng nhau)
List<(int, int)> generateAllPairs() {
  final pairs = <(int, int)>[];
  for (int i = 0; i < 100; i++) {
    for (int j = i + 1; j < 100; j++) {
      pairs.add((i, j));
    }
  }
  return pairs;
}

// Kiểm tra cặp số xuất hiện trong 1 ngày
// mode = 1: 1 trong 2 số xuất hiện
// mode = 2: cả 2 số cùng xuất hiện
bool isPairAppearedInDay(DataModel data, int num1, int num2, int mode) {
  final hasNum1 = data.others.contains(num1);
  final hasNum2 = data.others.contains(num2);
  
  if (mode == 1) {
    return hasNum1 || hasNum2;
  } else {
    return hasNum1 && hasNum2;
  }
}

// Tính số ngày giữa 2 ngày
int daysBetween(DateTime date1, DateTime date2) {
  return date2.difference(date1).inDays;
}

// Tính maxlose và currentlose cho một cặp số
PairResult? calculatePairResult(
  List<DataModel> sortedData,
  int num1,
  int num2,
  int mode,
) {
  // Tìm tất cả các ngày xuất hiện
  final appearanceDates = <DateTime>[];
  final appearanceData = <DataModel>[];
  
  for (final data in sortedData) {
    if (isPairAppearedInDay(data, num1, num2, mode)) {
      final date = DateTime.parse(data.date);
      appearanceDates.add(date);
      appearanceData.add(data);
    }
  }

  // Nếu chưa từng xuất hiện hoặc chỉ xuất hiện 1 lần → bỏ qua
  if (appearanceDates.length < 2) {
    return null;
  }

  // Tính maxlose và thống kê tất cả các lose
  int maxlose = 0;
  final loseFrequency = <int, int>{}; // Map: lose -> số lần xuất hiện
  
  for (int i = 0; i < appearanceDates.length - 1; i++) {
    final days = daysBetween(appearanceDates[i], appearanceDates[i + 1]);
    if (days > 1) {
      // Khoảng lose = số ngày giữa 2 ngày - 1 (không tính 2 ngày xuất hiện)
      final lose = days - 1;
      if (lose > maxlose) {
        maxlose = lose;
      }
      // Thống kê tần suất lose
      loseFrequency[lose] = (loseFrequency[lose] ?? 0) + 1;
    }
  }

  // Tính currentlose (từ lần xuất hiện gần nhất đến ngày mới nhất)
  final lastAppearanceDate = appearanceDates.last;
  final newestDate = DateTime.parse(sortedData.last.date);
  final daysToNewest = daysBetween(lastAppearanceDate, newestDate);
  final currentlose = daysToNewest > 0 ? daysToNewest : 0;

  // Kiểm tra xem ngày mới nhất có xuất hiện không (so sánh ngày, không so sánh giờ)
  final lastAppearanceDateOnly = DateTime(lastAppearanceDate.year, lastAppearanceDate.month, lastAppearanceDate.day);
  final newestDateOnly = DateTime(newestDate.year, newestDate.month, newestDate.day);
  final isNewestAppeared = lastAppearanceDateOnly.isAtSameMomentAs(newestDateOnly);

  // Tính lastLose
  int lastLose;
  if (isNewestAppeared) {
    // Nếu ngày mới nhất đã xuất hiện: lose từ lần xuất hiện gần nhất (trước đó) đến ngày mới nhất
    if (appearanceDates.length >= 2) {
      final secondLastDate = appearanceDates[appearanceDates.length - 2];
      final daysBetweenLastTwo = daysBetween(secondLastDate, lastAppearanceDate);
      lastLose = daysBetweenLastTwo > 1 ? daysBetweenLastTwo - 1 : 0;
    } else {
      lastLose = 0;
    }
  } else {
    // Nếu ngày mới nhất chưa xuất hiện: lose cuối cùng đã kết thúc (trước lần xuất hiện gần nhất)
    if (appearanceDates.length >= 2) {
      final secondLastDate = appearanceDates[appearanceDates.length - 2];
      final daysBetweenLastTwo = daysBetween(secondLastDate, lastAppearanceDate);
      lastLose = daysBetweenLastTwo > 1 ? daysBetweenLastTwo - 1 : 0;
    } else {
      lastLose = 0;
    }
  }

  // Tính top 3 lose xuất hiện thường xuyên nhất
  final loseEntries = loseFrequency.entries.toList();
  // Sắp xếp theo số lần xuất hiện (nhiều nhất trước), giữ nguyên thứ tự tìm thấy khi bằng nhau
  loseEntries.sort((a, b) {
    if (a.value != b.value) {
      return b.value.compareTo(a.value); // Nhiều nhất trước
    }
    return 0; // Giữ nguyên thứ tự
  });
  
  final top3Lose = loseEntries.take(3).toList();
  final top3LoseString = top3Lose.map((e) => 'lose${e.key}(${e.value})').join(', ');
  final top3LoseFrequent = top3LoseString.isEmpty ? '-' : top3LoseString;

  // Format ngày xuất hiện gần nhất
  final lastDateString = '${lastAppearanceDate.year}-${lastAppearanceDate.month.toString().padLeft(2, '0')}-${lastAppearanceDate.day.toString().padLeft(2, '0')}';

  return PairResult(
    num1: num1,
    num2: num2,
    maxlose: maxlose,
    currentlose: currentlose,
    count: appearanceDates.length,
    lastAppearanceDate: lastDateString,
    lastLose: lastLose,
    top3LoseFrequent: top3LoseFrequent,
  );
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

  // Nhập mode
  print('Nhập 1: Tìm top 10 cặp số (1 trong 2 số xuất hiện)');
  print('Nhập 2: Tìm top 10 cặp số (cả 2 số cùng xuất hiện)');
  stdout.write('Chọn mode (1 hoặc 2): ');
  final modeInput = stdin.readLineSync();
  final mode = int.tryParse(modeInput ?? '') ?? 1;
  
  if (mode != 1 && mode != 2) {
    print('Mode không hợp lệ!');
    return;
  }

  print('\nĐang xử lý...');
  
  // Tạo tất cả các cặp số
  final pairs = generateAllPairs();
  
  // Tính toán cho tất cả các cặp số
  final results = <PairResult>[];
  for (final (num1, num2) in pairs) {
    final result = calculatePairResult(sortedData, num1, num2, mode);
    if (result != null) {
      results.add(result);
    }
  }

  // Sắp xếp theo:
  // 1. Số lần xuất hiện (nhiều nhất trước)
  // 2. Maxlose (ngắn nhất trước)
  // 3. |currentlose - maxlose| (nhỏ nhất trước)
  results.sort((a, b) {
    // Ưu tiên 1: Số lần xuất hiện
    if (a.count != b.count) {
      return b.count.compareTo(a.count); // Nhiều nhất trước
    }
    
    // Ưu tiên 2: Maxlose
    if (a.maxlose != b.maxlose) {
      return a.maxlose.compareTo(b.maxlose); // Ngắn nhất trước
    }
    
    // Ưu tiên 3: |currentlose - maxlose|
    final diffA = (a.currentlose - a.maxlose).abs();
    final diffB = (b.currentlose - b.maxlose).abs();
    return diffA.compareTo(diffB); // Nhỏ nhất trước
  });

  // Lấy top 10
  final top10 = results.take(10).toList();

  // Hiển thị kết quả
  print('\n=== TOP 10 CẶP SỐ ===');
  print('Mode: ${mode == 1 ? "1 trong 2 số xuất hiện" : "Cả 2 số cùng xuất hiện"}');
  print('\n${'STT'.padLeft(4)} | ${'Cặp số'.padRight(6)} | ${'Maxlose'.padLeft(8)} | ${'Currentlose'.padLeft(12)} | ${'Số lần'.padLeft(8)} | ${'Lose gần nhất'.padLeft(14)} | Top 3 lose thường xuyên | Ngày xuất hiện gần nhất');
  print('${'-' * 4} | ${'-' * 6} | ${'-' * 8} | ${'-' * 12} | ${'-' * 8} | ${'-' * 14} | ${'-' * 25} | ${'-' * 25}');
  
  for (int i = 0; i < top10.length; i++) {
    final result = top10[i];
    print('${(i + 1).toString().padLeft(4)} | ${result.pairString.padRight(6)} | ${result.maxlose.toString().padLeft(8)} | ${result.currentlose.toString().padLeft(12)} | ${result.count.toString().padLeft(8)} | ${result.lastLose.toString().padLeft(14)} | ${result.top3LoseFrequent.padRight(25)} | ${result.lastAppearanceDate}');
  }
}
