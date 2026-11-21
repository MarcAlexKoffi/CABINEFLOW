import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_offer.dart';

/// Rebuilds at expiry even if the catalogue stream retains cached data offline.
class LiveOfferBonus extends StatefulWidget {
  const LiveOfferBonus({super.key, required this.offer, required this.builder});
  final CustomerOffer offer;
  final WidgetBuilder builder;
  @override
  State<LiveOfferBonus> createState() => _LiveOfferBonusState();
}

class _LiveOfferBonusState extends State<LiveOfferBonus>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant LiveOfferBonus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final remaining = widget.offer.bonus?.remaining;
    if (remaining != null && remaining > Duration.zero) {
      _timer = Timer(remaining, () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // A sleeping device may suspend its monotonic clock. Reuse no lease
      // across a resume; the repository will obtain a fresh server projection.
      widget.offer.bonus?.invalidate();
      setState(() {});
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
