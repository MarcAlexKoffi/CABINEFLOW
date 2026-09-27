String? normalizeCustomerAcquisitionSourceCode(String? raw) {
  final String value = raw?.trim().toUpperCase() ?? '';
  if (value.isEmpty || value.length > 64) return null;
  if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]*$').hasMatch(value)) return null;
  return value;
}
