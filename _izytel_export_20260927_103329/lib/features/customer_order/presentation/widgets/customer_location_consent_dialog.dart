import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/data/geolocation/customer_geolocation.dart';
import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';
import 'package:flutter/material.dart';

enum CustomerLocationPromptMoment { firstVisit, beforePayment }

Future<CustomerLocationCapture?> showCustomerLocationConsentDialog({
  required BuildContext context,
  required CustomerLocationPromptMoment moment,
  CustomerGeolocationService? geolocationService,
}) {
  return showDialog<CustomerLocationCapture>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _CustomerLocationConsentDialog(
        moment: moment,
        geolocationService:
            geolocationService ?? createCustomerGeolocationService(),
      );
    },
  );
}

class _CustomerLocationConsentDialog extends StatefulWidget {
  const _CustomerLocationConsentDialog({
    required this.moment,
    required this.geolocationService,
  });

  final CustomerLocationPromptMoment moment;
  final CustomerGeolocationService geolocationService;

  @override
  State<_CustomerLocationConsentDialog> createState() =>
      _CustomerLocationConsentDialogState();
}

class _CustomerLocationConsentDialogState
    extends State<_CustomerLocationConsentDialog> {
  bool _isRequesting = false;

  Future<void> _requestLocation() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    final CustomerLocationCapture capture =
        await widget.geolocationService.requestCurrentLocation();

    if (!mounted) return;
    Navigator.of(context).pop(capture);
  }

  void _continueWithoutLocation() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirstVisit =
        widget.moment == CustomerLocationPromptMoment.firstVisit;
    final String title = isFirstVisit
        ? 'Autoriser la localisation ?'
        : 'Localiser cette demande ?';
    final String description = isFirstVisit
        ? 'Avec votre accord, IzyTel utilise votre position pour rattacher automatiquement vos demandes à la zone opérationnelle la plus proche. Si vous l’autorisez maintenant, nous ne vous le redemanderons pas au paiement pendant ce parcours.'
        : 'Vous n’avez pas encore partagé votre position. Vous pouvez l’autoriser maintenant pour rattacher cette demande à la zone opérationnelle la plus proche, ou continuer sans localisation.';
    final String secondaryLabel =
        isFirstVisit ? 'Plus tard' : 'Continuer sans localisation';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: CustomerAppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: CustomerAppColors.primaryDeep.withValues(alpha: 0.16),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      CustomerAppColors.primary,
                      CustomerAppColors.primaryDark,
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: CustomerAppColors.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: CustomerAppColors.onPrimary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: CustomerAppColors.onPrimary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: CustomerAppColors.onPrimary.withValues(
                                alpha: 0.13,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'IzyTel • Localisation',
                              style: TextStyle(
                                color: CustomerAppColors.onPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              color: CustomerAppColors.onPrimary,
                              fontSize: 21,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      description,
                      style: const TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: CustomerAppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: CustomerAppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.shield_outlined,
                            color: CustomerAppColors.primary,
                            size: 19,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Votre position est facultative. Le QR code reste uniquement une source d’acquisition et ne détermine jamais votre zone réelle.',
                              style: TextStyle(
                                color: CustomerAppColors.onSurfaceVariant,
                                fontSize: 11.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _isRequesting ? null : _requestLocation,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isRequesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CustomerAppColors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.location_on_rounded, size: 20),
                      label: Text(
                        _isRequesting
                            ? 'Localisation en cours…'
                            : 'Autoriser ma position',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed:
                          _isRequesting ? null : _continueWithoutLocation,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(
                          color: CustomerAppColors.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        secondaryLabel,
                        style: const TextStyle(
                          color: CustomerAppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
