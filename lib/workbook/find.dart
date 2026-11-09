/// What Find and Replace look for. `*` stands for any text and `?` for one
/// character, `~*` and `~?` for the characters themselves, as in Excel.
class FindQuery {
  FindQuery(
    this.text, {
    this.matchCase = false,
    this.wholeCell = false,
    this.inFormulas = false,
  }) : _pattern = _compile(text, matchCase: matchCase, wholeCell: wholeCell);

  final String text;
  final bool matchCase;

  /// The whole content must match, not just a part of it.
  final bool wholeCell;

  /// Looks at what was typed (formulas included) instead of what shows.
  final bool inFormulas;

  final RegExp? _pattern;

  bool get isEmpty => text.isEmpty;

  bool matches(String content) =>
      _pattern != null && content.isNotEmpty && _pattern.hasMatch(content);

  /// [content] with every match replaced by [replacement], taken literally.
  String replace(String content, String replacement) {
    final pattern = _pattern;
    if (pattern == null) return content;
    if (wholeCell) return pattern.hasMatch(content) ? replacement : content;
    return content.replaceAllMapped(pattern, (_) => replacement);
  }

  static RegExp? _compile(
    String text, {
    required bool matchCase,
    required bool wholeCell,
  }) {
    if (text.isEmpty) return null;
    final buffer = StringBuffer(wholeCell ? '^' : '');
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '~' && i + 1 < text.length && '*?~'.contains(text[i + 1])) {
        buffer.write(RegExp.escape(text[++i]));
      } else if (char == '*') {
        buffer.write(wholeCell ? '.*' : '.*?');
      } else if (char == '?') {
        buffer.write('.');
      } else {
        buffer.write(RegExp.escape(char));
      }
    }
    if (wholeCell) buffer.write(r'$');
    return RegExp(
      buffer.toString(),
      caseSensitive: matchCase,
      dotAll: true,
      unicode: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FindQuery &&
      other.text == text &&
      other.matchCase == matchCase &&
      other.wholeCell == wholeCell &&
      other.inFormulas == inFormulas;

  @override
  int get hashCode => Object.hash(text, matchCase, wholeCell, inFormulas);
}
