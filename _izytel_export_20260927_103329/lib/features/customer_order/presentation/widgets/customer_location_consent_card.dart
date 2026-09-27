import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/data/geolocation/customer_geolocation.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:flutter/material.dart';

class CustomerLocationConsentCard extends StatefulWidget {
  const CustomerLocationConsentCard({
    super.key,
    required this.viewModel,
    this.geolocationService,
  });

  final CustomerOrderViewModel viewModel;
  final CustomerGeolocationService? geolocationService;

  @override
  State<CustomerLocationConsentCard> createState() =>
      _CustomerLocationConsentCardState();
}

class _CustomerLocationConsentCardState
    extends State<CustomerLocationConsentCard> {
  late final CustomerGeolocationService _geolocationService;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _geolocationService =
        widget.geolocationService ?? createCustomerGeolocationService();
  }

  Future<void> _requestLocation() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    final CustomerLocationCapture capture =
        await _geolocationService.requestCurrentLocation();
    await widget.viewModel.applyOrderContext(
      capture.applyTo(widget.viewModel.orderContext),
    );

    if (!mounted) return;
    setState(() {
      _isRequesting = false;
    });
  }

  Future<void> _continueWithoutLocation() async {
    if (_isRequesting) return;

    await widget.viewModel.applyOrderContext(
      widget.viewModel.orderContext.copyWith(
        locationStatus: CustomerLocationStatus.denied,
        clearLocation: true,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrderContextDraft orderContext = widget.viewModel.orderContext;
    final CustomerLocationStatus status = orderContext.locationStatus;

    return IzyTelCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CustomerAppColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.location_on_outlined,
                  color: CustomerAppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Localisation de la demande',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: CustomerAppColors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: CustomerAppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Optionnel',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Avec votre accord, IzyTel utilise votre position au moment de cette commande pour rattacher la demande à la zone opérationnelle la plus proche. Vous pouvez continuer sans la partager.',
                      style: TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LocationStatusMessage(status: status),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _isRequesting ? null : _requestLocation,
                icon: _isRequesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  status == CustomerLocationStatus.granted
                      ? 'Actualiser ma position'
                      : 'Partager ma position',
                ),
              ),
              if (status != CustomerLocationStatus.denied)
                OutlinedButton(
                  onPressed: _isRequesting ? null : _continueWithoutLocation,
                  child: const Text('Continuer sans localisation'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'La position n’est jamais déduite du QR code : le QR identifie uniquement la provenance commerciale.',
            style: TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStatusMessage extends StatelessWidget {
  const _LocationStatusMessage({required this.status});

  final CustomerLocationStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (status) {
      CustomerLocationStatus.granted => (
          Icons.check_circle_outline_rounded,
          'Position partagée. La zone sera déterminée automatiquement.',
          CustomerAppColors.success,
        ),
      CustomerLocationStatus.denied => (
          Icons.lock_outline_rounded,
          'Localisation non partagée. Votre commande peut continuer normalement.',
          CustomerAppColors.onSurfaceVariant,
        ),
      CustomerLocationStatus.unavailable => (
          Icons.location_off_outlined,
          'Position indisponible. Vous pouvez continuer sans localisation ou réessayer.',
          CustomerAppColors.warning,
        ),
      CustomerLocationStatus.notRequested => (
          Icons.info_outline_rounded,
          'Aucune position n’est utilisée tant que vous ne choisissez pas de la partager.',
          CustomerAppColors.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
