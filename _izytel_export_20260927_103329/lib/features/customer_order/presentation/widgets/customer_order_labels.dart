import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

extension CustomerMobileNetworkLabel on MobileNetwork {
  String get customerLabel {
    switch (this) {
      case MobileNetwork.orange:
        return 'Orange';
      case MobileNetwork.mtn:
        return 'MTN';
      case MobileNetwork.moov:
        return 'Moov Africa';
    }
  }
}
