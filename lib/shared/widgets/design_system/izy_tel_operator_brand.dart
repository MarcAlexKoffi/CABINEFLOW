import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

extension MobileNetworkBranding on MobileNetwork {
  String get brandLabel => switch (this) {
    MobileNetwork.orange => 'Orange',
    MobileNetwork.mtn => 'MTN',
    MobileNetwork.moov => 'Moov Africa',
  };

  String get brandDescription => switch (this) {
    MobileNetwork.orange => 'Recharge et forfaits',
    MobileNetwork.mtn => 'Recharge et forfaits',
    MobileNetwork.moov => 'Recharge et forfaits',
  };

  String get brandLogoAsset => switch (this) {
    MobileNetwork.orange => 'assets/brands/operators/orange_ci.png',
    MobileNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
    MobileNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
  };

  Color get brandColor => switch (this) {
    MobileNetwork.orange => CustomerAppColors.orangeCI,
    MobileNetwork.mtn => CustomerAppColors.mtnCI,
    MobileNetwork.moov => CustomerAppColors.moovCI,
  };

  Color get softBrandColor => brandColor.withValues(alpha: 0.10);
}

class IzyTelOperatorLogo extends StatelessWidget {
  const IzyTelOperatorLogo({
    super.key,
    required this.network,
    this.size = 48,
    this.borderRadius = 14,
  });

  final MobileNetwork network;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: network.brandColor.withValues(alpha: 0.20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        network.brandLogoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Logo ${network.brandLabel}',
      ),
    );
  }
}
