class FirestoreOfferData {
  const FirestoreOfferData({
    required this.id,
    required this.network,
    required this.service,
    required this.operationType,
    required this.title,
    required this.catalogLabel,
    required this.sellingPrice,
    required this.details,
    required this.isActive,
    required this.displayOrder,
    this.badgeLabel,
  });

  final String id;
  final String network;
  final String service;
  final String operationType;
  final String title;
  final String catalogLabel;
  final int sellingPrice;
  final List<String> details;
  final String? badgeLabel;
  final bool isActive;
  final int displayOrder;

  static FirestoreOfferData? tryParse({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final String? network = _readRequiredString(data['network']);
    final String? service = _readRequiredString(data['service']);
    final String? operationType = _readRequiredString(data['operationType']);
    final String? title = _readRequiredString(data['title']);
    final String? catalogLabel = _readRequiredString(data['catalogLabel']);
    final int? sellingPrice = _readPositiveInt(data['sellingPrice']);
    final bool? isActive = data['isActive'] is bool
        ? data['isActive'] as bool
        : null;

    if (network == null ||
        service == null ||
        operationType == null ||
        title == null ||
        catalogLabel == null ||
        sellingPrice == null ||
        isActive == null) {
      return null;
    }

    final List<String> details = _readStringList(data['details']);
    final String? badgeLabel = _readOptionalString(data['badgeLabel']);
    final int displayOrder = _readNonNegativeInt(data['displayOrder']) ?? 9999;

    return FirestoreOfferData(
      id: id,
      network: network,
      service: service,
      operationType: operationType,
      title: title,
      catalogLabel: catalogLabel,
      sellingPrice: sellingPrice,
      details: List<String>.unmodifiable(details),
      badgeLabel: badgeLabel,
      isActive: isActive,
      displayOrder: displayOrder,
    );
  }

  static String? _readRequiredString(Object? value) {
    if (value is! String) {
      return null;
    }

    final String cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _readOptionalString(Object? value) {
    if (value is! String) {
      return null;
    }

    final String cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static int? _readPositiveInt(Object? value) {
    if (value is int && value > 0) {
      return value;
    }

    if (value is num && value > 0) {
      return value.toInt();
    }

    return null;
  }

  static int? _readNonNegativeInt(Object? value) {
    if (value is int && value >= 0) {
      return value;
    }

    if (value is num && value >= 0) {
      return value.toInt();
    }

    return null;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .whereType<String>()
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}
