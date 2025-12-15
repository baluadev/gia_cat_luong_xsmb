import 'dart:convert';
import 'dart:io';

const URL_MAIN =
    'https://xoso188.net/api/front/open/lottery/history/low/all/game?page=1&pageSize=1200&gameCode=miba';
const URL_EXTRA =
    'https://xoso188.net/api/front/open/lottery/history/list/game?limitNum=5&gameCode=miba';

/// ======================
/// Fetch JSON
/// ======================
Future<Map<String, dynamic>> fetchJson(String url) async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  request.headers.set('User-Agent', 'Mozilla/5.0');

  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  client.close();

  return jsonDecode(body);
}

/// ======================
/// Utils
/// ======================
String? getLast2(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 2) return null;
  return digits.substring(digits.length - 2);
}

List<String> parseDetail(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final result = <String>[];

    for (final item in decoded) {
      final subs = item.toString().split(',');
      for (final sub in subs) {
        final last2 = getLast2(sub);
        if (last2 != null) result.add(last2);
      }
    }
    return result;
  } catch (_) {
    return [];
  }
}

/// ======================
/// Parse 1 issue
/// ======================
Map<String, String> parseIssue(Map<String, dynamic> issue) {
  final date =
      issue['openTime']?.toString() ?? issue['turnNum']?.toString() ?? '';

  final openNum = issue['openNum']?.toString() ?? '';
  final joined = openNum.split(',').map((e) => e.trim()).join('');
  final de = getLast2(joined) ?? '';

  final detailRaw = issue['detail']?.toString() ?? '[]';
  final others = parseDetail(detailRaw).join(',');

  return {
    'date': date,
    'de': de,
    'other': others,
  };
}

/// ======================
/// Save CSV
/// ======================
Future<void> saveMergedCsv() async {
  final dataMain = await fetchJson(URL_MAIN);
  final dataExtra = await fetchJson(URL_EXTRA);

  final rowsMain = (dataMain['rows'] as List?) ?? [];
  final rowsExtra = (dataExtra['t']?['issueList'] as List?) ?? [];

  print('MAIN: ${rowsMain.length} | EXTRA: ${rowsExtra.length}');

  // EXTRA trước (mới hơn)
  final allRows = [...rowsExtra, ...rowsMain];

  // Parse
  final parsed = <Map<String, String>>[];
  for (final issue in allRows) {
    parsed.add(parseIssue(issue));
  }

  /// ======================
  /// Remove duplicate by date
  /// ======================
  final seenDates = <String>{};
  final unique = <Map<String, String>>[];

  for (final row in parsed) {
    if (seenDates.add(row['date']!)) {
      unique.add(row);
    }
  }

  /// ======================
  /// Sort desc by date
  /// ======================
  unique.sort((a, b) {
    final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
    final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
    return db.compareTo(da);
  });

  /// ======================
  /// Write CSV
  /// ======================
  final buffer = StringBuffer();
  buffer.writeln('date,de,other');

  for (final row in unique) {
    buffer.writeln('${row['date']},${row['de']},${row['other']}');
  }

  final file = File('data.csv');
  await file.writeAsString(buffer.toString(), encoding: utf8);

  print('✅ Đã lưu data.csv (dòng mới nhất đầu tiên)');
}

void main() async {
  await saveMergedCsv();
}
