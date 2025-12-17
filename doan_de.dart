import 'dart:io';

class DataModel {
  final String date;
  final int de; // 2 số cuối đề
  final List<int> others;

  DataModel({
    required this.date,
    required this.de,
    required this.others,
  });
}

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
/// CONFIG
/// =======================
const int historyDays = 12;
const int tailDays = 1;
const int headDays = 1;
const int otherStreakDays = 2;

const int PAYOUT = 770000; // tỉ lệ 1:77
const int STAKE_PER_NUMBER = 10000;

/// =======================
/// FILTER FUNCTION
/// =======================
List<int> filterDeNumbers(List<DataModel> data) {
  Set<int> result = Set.from(List.generate(100, (i) => i));

  // 1️⃣ Loại kép
  result.removeWhere((n) => n ~/ 10 == n % 10);

  // 2️⃣ Loại đề lịch sử
  final recentDe = data.take(historyDays).map((e) => e.de).toSet();
  result.removeWhere((n) => recentDe.contains(n));

  // 3️⃣ Loại đuôi
  final tails = data.take(tailDays).map((e) => e.de % 10).toSet();
  result.removeWhere((n) => tails.contains(n % 10));

  // 4️⃣ Loại đầu
  final heads = data.take(headDays).map((e) => e.de ~/ 10).toSet();
  result.removeWhere((n) => heads.contains(n ~/ 10));

  // 5️⃣ Loại streak trong others
  final hotOthers = _findOtherStreakNumbers(data, otherStreakDays);
  result.removeWhere((n) => hotOthers.contains(n));

  return result.toList()..sort();
}

/// =======================
/// FIND STREAK IN OTHERS
/// =======================
Set<int> _findOtherStreakNumbers(
  List<DataModel> data,
  int streakDays,
) {
  final Set<int> result = {};
  if (data.length < streakDays) return result;

  for (int number = 0; number < 100; number++) {
    bool isStreak = true;
    for (int i = 0; i < streakDays; i++) {
      if (!data[i].others.contains(number)) {
        isStreak = false;
        break;
      }
    }
    if (isStreak) result.add(number);
  }
  return result;
}

/// =======================
/// BACKTEST + PROFIT
/// =======================
void main() async {
  final data = await loadDataModels('data.csv');

  // đảm bảo data mới nhất ở đầu
  data.sort((a, b) => b.date.compareTo(a.date));

  int totalDays = 0;
  int hitDays = 0;
  int totalProfit = 0;

  for (int i = 0; i < data.length - historyDays - 1; i++) {
    final slice = data.sublist(i);
    final today = data[i];
    final tomorrow = data[i + 1];

    final suggestions = filterDeNumbers(slice);
    if (suggestions.isEmpty) continue;

    final k = suggestions.length;
    final cost = k * STAKE_PER_NUMBER;

    totalDays++;

    if (suggestions.contains(tomorrow.de)) {
      hitDays++;
      final profit = PAYOUT - cost;
      totalProfit += profit;
    } else {
      totalProfit -= cost;
    }
  }

  print('================ BACKTEST RESULT ================');
  print('Tổng ngày đánh: $totalDays');
  print('Ngày trúng: $hitDays');
  print(
      'Winrate: ${(hitDays / totalDays * 100).toStringAsFixed(2)}%');
  print('Tổng profit: $totalProfit');
  print(
      'Profit/ngày: ${(totalProfit / totalDays).toStringAsFixed(2)}');
}
