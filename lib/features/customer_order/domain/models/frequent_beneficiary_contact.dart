import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';

class FrequentBeneficiaryContact {
  const FrequentBeneficiaryContact({
    required this.name,
    required this.phoneNumber,
    required this.usageCount,
    required this.lastUsedAt,
  });

  final String name;
  final BeneficiaryPhoneNumber phoneNumber;
  final int usageCount;
  final DateTime lastUsedAt;

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'IZ';
    if (parts.length == 1) {
      final String token = parts.first;
      return token.substring(0, token.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
