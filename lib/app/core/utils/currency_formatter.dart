String _formatNumber(int amount) {
  final String digits = amount.toString();
  final StringBuffer result = StringBuffer();

  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      result.write(' ');
    }
    result.write(digits[index]);
  }
  return result.toString();
}

String formatCfa(int amount) => '${_formatNumber(amount)} F';

String formatCfaFull(int amount) => '${_formatNumber(amount)} F CFA';
