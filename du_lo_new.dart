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

  print('📊 THỐNG KÊ DE THEO ĐUÔI SỐ');
  print('=' * 60);
  print('Tổng số ngày: ${sortedData.length}\n');

  // Vòng lặp để nhập số
  while (true) {
    stdout.write('Nhập số đuôi (0-9) để thống kê DE, hoặc "exit" để thoát: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    
    if (input.toLowerCase() == 'exit') {
      print('👋 Tạm biệt!');
      break;
    }
    
    final digit = int.tryParse(input);
    if (digit == null || digit < 0 || digit > 9) {
      print('⚠️  Vui lòng nhập số từ 0-9\n');
      continue;
    }
    
    // Thống kê các DE có đuôi là digit
    final matchingDe = <DataModel>[];
    for (final day in sortedData) {
      final deLastDigit = day.de % 10;
      if (deLastDigit == digit) {
        matchingDe.add(day);
      }
    }
    
    print('\n📈 THỐNG KÊ DE CÓ ĐUÔI LÀ $digit:');
    print('=' * 60);
    print('Tổng số lần xuất hiện: ${matchingDe.length}');
    print('Tỉ lệ: ${(matchingDe.length / sortedData.length * 100).toStringAsFixed(2)}%\n');
    
    if (matchingDe.isEmpty) {
      print('❌ Không có DE nào có đuôi là $digit\n');
      continue;
    }
    
    // Thống kê các DE cụ thể
    final deCount = <int, int>{};
    for (final day in matchingDe) {
      deCount[day.de] = (deCount[day.de] ?? 0) + 1;
    }
    
    // Sắp xếp theo số lần xuất hiện giảm dần
    final sortedDe = deCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    print('📋 DANH SÁCH DE CÓ ĐUÔI $digit (sắp xếp theo số lần xuất hiện):\n');
    print('${'DE'.padRight(8)} | ${'Số lần xuất hiện'.padRight(20)} | ${'Tỉ lệ %'.padRight(15)}');
    print('${'-' * 8} | ${'-' * 20} | ${'-' * 15}');
    
    for (final entry in sortedDe) {
      final de = entry.key;
      final count = entry.value;
      final percentage = (count / matchingDe.length * 100);
      print('${de.toString().padLeft(2, '0').padRight(8)} | ${count.toString().padLeft(20)} | ${percentage.toStringAsFixed(2).padLeft(13)}%');
    }
    
    // Thống kê theo thời gian
    print('\n📅 PHÂN TÍCH THEO THỜI GIAN:');
    print('=' * 60);
    
    final totalDays = sortedData.length;
    final daysPerPeriod = (totalDays / 4).round(); // Chia thành 4 giai đoạn
    
    for (int period = 0; period < 4; period++) {
      final startIdx = period * daysPerPeriod;
      final endIdx = period == 3 ? sortedData.length : (period + 1) * daysPerPeriod;
      
      if (startIdx >= sortedData.length) break;
      
      final periodData = sortedData.sublist(startIdx, endIdx);
      final periodMatching = periodData.where((d) => d.de % 10 == digit).toList();
      
      final startDate = periodData.first.date.split(' ').first;
      final endDate = periodData.last.date.split(' ').first;
      
      print('\n📅 Giai đoạn ${period + 1}: $startDate → $endDate');
      print('   Số lần xuất hiện: ${periodMatching.length}/${periodData.length}');
      print('   Tỉ lệ: ${periodData.isNotEmpty ? (periodMatching.length / periodData.length * 100).toStringAsFixed(2) : 0}%');
      
      // Top 3 DE xuất hiện nhiều nhất trong giai đoạn này
      final periodDeCount = <int, int>{};
      for (final day in periodMatching) {
        periodDeCount[day.de] = (periodDeCount[day.de] ?? 0) + 1;
      }
      
      if (periodDeCount.isNotEmpty) {
        final top3 = periodDeCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3List = top3.take(3).toList();
        print('   Top 3 DE: ${top3List.map((e) => '${e.key.toString().padLeft(2, '0')} (${e.value} lần)').join(', ')}');
      }
    }
    
    // Lần xuất hiện gần nhất
    if (matchingDe.isNotEmpty) {
      final lastOccurrence = matchingDe.last;
      final lastDate = lastOccurrence.date.split(' ').first;
      print('\n🕐 LẦN XUẤT HIỆN GẦN NHẤT:');
      print('   Ngày: $lastDate');
      print('   DE: ${lastOccurrence.de.toString().padLeft(2, '0')}');
      
      // Tính số ngày từ lần xuất hiện gần nhất đến ngày mới nhất
      final latestDate = DateTime.parse(sortedData.last.date);
      final lastOccurrenceDate = DateTime.parse(lastOccurrence.date);
      final daysSince = latestDate.difference(lastOccurrenceDate).inDays;
      print('   Cách đây: $daysSince ngày');
    }
    
    print('\n');
  }
}
