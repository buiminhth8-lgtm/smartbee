import 'package:flutter_test/flutter_test.dart';
import 'package:smartbee/features/novel_writing/application/novel_text_statistics.dart';

void main() {
  test('counts unicode runes and ignores whitespace', () {
    const content =
        '\u4f60\u597d\uff0cworld 123\n\n\u7b2c\u4e8c\u6bb5\u{1F600}\t';
    final statistics = NovelTextStatistics.calculate(content);

    expect(statistics.characterCount, 15);
    expect(statistics.paragraphCount, 2);
  });

  test('ignores consecutive blank lines for paragraphs', () {
    final statistics = NovelTextStatistics.calculate(
      '\u7b2c\u4e00\u6bb5\n\n \n\u7b2c\u4e8c\u6bb5\n',
    );

    expect(statistics.paragraphCount, 2);
  });
}
