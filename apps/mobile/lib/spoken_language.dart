final _malayalamScript = RegExp(r'[\u0D00-\u0D7F]');
final _manglishWord = RegExp(
  r'\b(ethra|ethrayanu|ethre|evide|evideya|enthu|entha|undu|unda|chilavu|chilavayi|chilavayathu|kitti|kittiyathu|baakki|bakki|kodukkanam|koduthu|innale|innu|shambalam|aaranu|aarokke|maasam|aazhcha|vangi|adachu)\b',
  caseSensitive: false,
);

/// Malayalam written in English letters, and not Malayalam script.
bool isManglish(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || _malayalamScript.hasMatch(trimmed)) return false;
  return _manglishWord.hasMatch(trimmed);
}

/// English, then Malayalam, then Manglish.
String nextSpokenLanguage(String current) {
  if (current == 'en') return 'ml';
  if (current == 'ml') return 'mg';
  return 'en';
}

/// The chip wins for Malayalam and Manglish.
/// An English chip still follows a Manglish question.
String replyLanguage(String chip, String text) {
  if (chip == 'ml' || chip == 'mg') return chip;
  if (chip == 'en' && isManglish(text)) return 'mg';
  return 'en';
}
