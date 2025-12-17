import 'dart:io';

import 'data_model.dart';

Future<List<DataModel>> loadDataModels(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0); // remove header

  return lines.map((line) {
    final parts = line.split(',');
    return DataModel(
      date: parts[0],
      de: int.parse(parts[1]),
      others: parts.sublist(2).map(int.parse).toList(),
    );
  }).toList();
}

/// Chọn 50 con hợp lý dựa trên cầu dưới/trên và lẻ/chẵn + lịch sử
List<int> select50Numbers(int deToday, List<DataModel> history) {
  List<int> candidates = [];

  // Xác định cầu dưới / cầu trên
  bool isLower = deToday <= 50;
  int start = isLower ? 0 : 51;
  int end = isLower ? 50 : 99;

  for (int i = start; i <= end; i++) candidates.add(i);

  // Thống kê lẻ/chẵn lịch sử
  int oddCount = history.where((h) => h.de % 2 != 0).length;
  int evenCount = history.length - oddCount;
  bool todayOdd = deToday % 2 != 0;

  // Lọc ưu tiên lẻ/chẵn
  if (todayOdd && oddCount >= evenCount) {
    candidates = candidates.where((n) => n % 2 != 0).toList();
  } else if (!todayOdd && evenCount >= oddCount) {
    candidates = candidates.where((n) => n % 2 == 0).toList();
  }

  // Nếu còn >50 con, lấy ngẫu nhiên 50 con
  if (candidates.length > 50) {
    candidates.shuffle();
    candidates = candidates.take(50).toList();
  }

  return candidates;
}

void main() async {
  // Ví dụ dữ liệu lịch sử
  final history = await loadDataModels('data.csv');
  int deToday = history.first.de;
  print("De hôm nay: $deToday");

  // Chọn 50 con hợp lý
  List<int> numbers50 = select50Numbers(deToday, history);
  print("\n50 con hợp lý để đánh:");
  print(numbers50);
}
