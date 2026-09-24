/// Balances live in tight HUD pills — the home bar, the quest and shop app
/// bars — where a seven-digit number used to either elide to `1,25…` or push
/// the row past the screen edge. Games shorten the readout instead, and so do
/// we: 12500 -> `12.5K`, 1250865 -> `1.3M`.
String compactAmount(int value) {
  final magnitude = value.abs();
  if (magnitude < 10000) return '$value';
  // A readout of one decimal still has to stay under four digits, which cuts
  // over at 999,950 rather than at a round million.
  final scaled = magnitude < 999950 ? value / 1000 : value / 1000000;
  final suffix = magnitude < 999950 ? 'K' : 'M';
  final text = scaled.toStringAsFixed(1);
  // `10.0K` is as wide as `10K` plus two pixels nobody spends.
  return text.endsWith('.0')
      ? '${text.substring(0, text.length - 2)}$suffix'
      : '$text$suffix';
}
