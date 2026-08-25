import 'dart:typed_data';

class OrderProof {
  const OrderProof({
    required this.orderId,
    required this.orderReference,
    required this.agentId,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String orderId;
  final String orderReference;
  final String agentId;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get sizeBytes => bytes.lengthInBytes;
}
