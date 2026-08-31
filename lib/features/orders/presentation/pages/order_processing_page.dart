import 'dart:async';

import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/orders_widgets.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderProcessingPage extends StatefulWidget {
  const OrderProcessingPage({
    super.key,
    required this.user,
    required this.order,
    required this.isSubmitting,
    required this.onTransactionSucceeded,
    required this.onTransactionFailed,
    required this.onPutOnHold,
    required this.onNotificationsPressed,
  });

  final AppUser user;
  final QueueOrder order;
  final bool isSubmitting;

  final Future<void> Function() onTransactionSucceeded;

  final Future<void> Function(OrderFailureReason reason, String? observation)
  onTransactionFailed;

  final Future<void> Function() onPutOnHold;

  final VoidCallback onNotificationsPressed;

  @override
  State<OrderProcessingPage> createState() {
    return _OrderProcessingPageState();
  }
}

class _OrderProcessingPageState extends State<OrderProcessingPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _elapsedTime {
    final DateTime startingTime = widget.order.takenAt ?? DateTime.now();

    final Duration duration = DateTime.now().difference(startingTime);

    if (duration.isNegative) {
      return Duration.zero;
    }

    return duration;
  }

  String get _formattedElapsedTime {
    final int totalSeconds = _elapsedTime.inSeconds;

    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String minuteText = minutes.toString().padLeft(2, '0');

    final String secondText = seconds.toString().padLeft(2, '0');

    if (hours == 0) {
      return '$minuteText:$secondText';
    }

    final String hourText = hours.toString().padLeft(2, '0');

    return '$hourText:$minuteText:$secondText';
  }

  String get _takenAtLabel {
    final DateTime? takenAt = widget.order.takenAt;

    if (takenAt == null) {
      return '--:--:--';
    }

    final String hours = takenAt.hour.toString().padLeft(2, '0');

    final String minutes = takenAt.minute.toString().padLeft(2, '0');

    final String seconds = takenAt.second.toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String get _networkLogoAsset {
    switch (widget.order.network) {
      case MobileNetwork.orange:
        return 'assets/images/orange_logo.png';
      case MobileNetwork.mtn:
        return 'assets/images/mtn_logo.png';
      case MobileNetwork.moov:
        return 'assets/images/moov_logo.png';
    }
  }

  Future<void> _copyBeneficiaryPhone() async {
    await Clipboard.setData(ClipboardData(text: widget.order.beneficiaryPhone));

    if (!mounted) {
      return;
    }

    IzyTelFeedback.success(context, 'Numéro bénéficiaire copié.');
  }

  Future<void> _confirmSuccess() async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Transaction réussie'),
          content: Text(
            'Confirmer que la commande '
            '${widget.order.reference} a été réalisée avec succès ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (isConfirmed == true) {
      await widget.onTransactionSucceeded();
    }
  }

  Future<void> _confirmPutOnHold() async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Mettre en attente'),
          content: const Text(
            'La commande retournera dans la file d’attente '
            'et pourra être reprise ultérieurement.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (isConfirmed == true) {
      await widget.onPutOnHold();
    }
  }

  Future<void> _openFailureSheet() async {
    final TextEditingController observationController = TextEditingController();

    OrderFailureReason? selectedReason;

    final _FailureResult? result = await showModalBottomSheet<_FailureResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setModalState,
              ) {
                return Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Raison de l’échec',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: OrderFailureReason.values.map((
                              OrderFailureReason reason,
                            ) {
                              final bool isSelected = selectedReason == reason;

                              return _FailureReasonButton(
                                label: _failureReasonLabel(reason),
                                isSelected: isSelected,
                                onPressed: () {
                                  setModalState(() {
                                    selectedReason = reason;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Observations — optionnel',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          TextField(
                            controller: observationController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Détails supplémentaires...',
                              fillColor: AppColors.surfaceContainerLowest,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: selectedReason == null
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop(
                                      _FailureResult(
                                        reason: selectedReason!,
                                        observation:
                                            observationController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : observationController.text.trim(),
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: AppColors.onError,
                            ),
                            child: const Text('Confirmer l’échec'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );

    observationController.dispose();

    if (result == null) {
      return;
    }

    await widget.onTransactionFailed(result.reason, result.observation);
  }

  String _failureReasonLabel(OrderFailureReason reason) {
    switch (reason) {
      case OrderFailureReason.incorrectNumber:
        return 'Numéro incorrect';

      case OrderFailureReason.networkUnavailable:
        return 'Réseau indisponible';

      case OrderFailureReason.offerUnavailable:
        return 'Offre indisponible';

      case OrderFailureReason.insufficientBalance:
        return 'Solde insuffisant';

      case OrderFailureReason.technicalError:
        return 'Erreur technique';

      case OrderFailureReason.incorrectPayment:
        return 'Paiement incorrect';

      case OrderFailureReason.other:
        return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 13),
            child: OrdersTopBar(
              user: widget.user,
              onNotificationsPressed: widget.onNotificationsPressed,
            ),
          ),
          Divider(height: 1, color: AppColors.outlineVariant.withAlpha(80)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'EN COURS DE TRAITEMENT',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '#${widget.order.reference}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppColors.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CHRONOMÈTRE',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formattedElapsedTime,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 46,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.asset(
                                _networkLogoAsset,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bénéficiaire',
                                    style: TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    widget.order.beneficiaryPhone,
                                    style: const TextStyle(
                                      color: AppColors.onBackground,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copier le numéro',
                              onPressed: _copyBeneficiaryPhone,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppColors.surfaceContainerHighest,
                              ),
                              icon: const Icon(
                                Icons.content_copy_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Divider(
                          height: 1,
                          color: AppColors.outlineVariant.withAlpha(65),
                        ),
                        const SizedBox(height: 13),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _ProcessingInformation(
                                label: 'Détails de l’offre',
                                value: widget.order.offerLabel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _ProcessingInformation(
                              label: 'Montant à débiter',
                              value: formatCfa(widget.order.amount),
                              alignRight: true,
                              valueColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ContextCard(
                          label: 'Client',
                          value: widget.order.clientName,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ContextCard(
                          label: 'Prise en charge',
                          value: _takenAtLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: widget.isSubmitting ? null : _confirmSuccess,
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Transaction réussie'),
                  ),
                  const SizedBox(height: 9),
                  FilledButton.icon(
                    onPressed: widget.isSubmitting ? null : _openFailureSheet,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Transaction échouée'),
                  ),
                  const SizedBox(height: 9),
                  FilledButton.icon(
                    onPressed: widget.isSubmitting ? null : _confirmPutOnHold,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHighest,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Mettre en attente'),
                  ),
                  if (widget.isSubmitting) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingInformation extends StatelessWidget {
  const _ProcessingInformation({
    required this.label,
    required this.value,
    this.alignRight = false,
    this.valueColor = AppColors.onBackground,
  });

  final String label;
  final String value;
  final bool alignRight;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureReasonButton extends StatelessWidget {
  const _FailureReasonButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.error.withAlpha(22)
          : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: (MediaQuery.sizeOf(context).width - 48) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.error : AppColors.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.error : AppColors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureResult {
  const _FailureResult({required this.reason, this.observation});

  final OrderFailureReason reason;
  final String? observation;
}
