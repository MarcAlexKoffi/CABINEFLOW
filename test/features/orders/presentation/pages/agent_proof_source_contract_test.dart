import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la preuve Agent peut venir de la caméra ou de la galerie', () {
    final String source = File(
      'lib/features/orders/presentation/pages/agent_order_detail_view.dart',
    ).readAsStringSync();

    expect(source, contains('class _ProofSourceSheet'));
    expect(source, contains('ImageSource.camera'));
    expect(source, contains('ImageSource.gallery'));
    expect(source, contains('preferredCameraDevice: CameraDevice.rear'));
    expect(source, contains('source: source'));
    expect(source, contains('_compressProofForFirestore'));
    expect(source, contains('Appareil photo'));
    expect(source, contains('Galerie'));
  });
}
