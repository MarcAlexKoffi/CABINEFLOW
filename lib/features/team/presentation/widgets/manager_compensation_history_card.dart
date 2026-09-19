import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/team/domain/models/team_supervision_models.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ManagerCompensationHistoryCard extends StatelessWidget {
  const ManagerCompensationHistoryCard({
    super.key,
    required this.history,
    this.adminMode = false,
    this.busy = false,
    this.onApprove,
    this.onAdjust,
    this.onPayout,
  });

  final Map<String, dynamic> history;
  final bool adminMode;
  final bool busy;
  final Future<void> Function(Map<String, dynamic> period)? onApprove;
  final Future<void> Function(Map<String, dynamic> period)? onAdjust;
  final Future<void> Function(Map<String, dynamic> period)? onPayout;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> account = teamMap(history['account']);
    final List<Map<String, dynamic>> periods = _maps(history['periods']);
    final List<Map<String, dynamic>> payouts = _maps(history['payouts']);

    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Symbols.account_balance_wallet_rounded,
                  color: IzyTelColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Historique de rémunération',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _Metric(
                label: 'Acquis',
                value: formatCfa(teamInt(account['earnedTotal'])),
              ),
              _Metric(
                label: 'Versé',
                value: formatCfa(teamInt(account['paidTotal'])),
              ),
              _Metric(
                label: 'Solde dû',
                value: formatCfa(teamInt(account['balanceDue'])),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (periods.isEmpty)
            const Text(
              'Aucune clôture mensuelle Manager enregistrée.',
              style: TextStyle(color: IzyTelColors.textSecondary),
            )
          else
            ...periods.take(12).map(
                  (Map<String, dynamic> period) => _periodCard(
                    context,
                    period,
                  ),
                ),
          if (payouts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Derniers versements',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            ...payouts.take(5).map(
                  (Map<String, dynamic> payout) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${teamString(payout['channel']).toUpperCase()} · ${teamString(payout['reference'])}',
                            style: const TextStyle(
                              color: IzyTelColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          formatCfa(teamInt(payout['amount'])),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _periodCard(
    BuildContext context,
    Map<String, dynamic> period,
  ) {
    final String status = teamString(period['status']);
    final int balanceDue = teamInt(period['balanceDue']);
    final bool canAdjust = adminMode &&
        !busy &&
        (status == 'calculated' || status == 'approved') &&
        onAdjust != null;
    final bool canApprove = adminMode &&
        !busy &&
        status == 'calculated' &&
        onApprove != null;
    final bool canPayout = adminMode &&
        !busy &&
        status == 'approved' &&
        balanceDue > 0 &&
        onPayout != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Période ${teamString(period['periodKey'])}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              Text(
                'Fixe ${formatCfa(teamInt(period['baseAmount']))}',
                style: const TextStyle(
                  color: IzyTelColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                'Variable ${formatCfa(teamInt(period['variableAmount']))}',
                style: const TextStyle(
                  color: IzyTelColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (teamInt(period['adjustmentAmount']) != 0)
                Text(
                  'Ajust. ${formatCfa(teamInt(period['adjustmentAmount']))}',
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Total ${formatCfa(teamInt(period['totalAmount']))}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                balanceDue <= 0
                    ? 'Soldé'
                    : 'Dû ${formatCfa(balanceDue)}',
                style: TextStyle(
                  color: balanceDue <= 0
                      ? IzyTelColors.success
                      : IzyTelColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (canAdjust || canApprove || canPayout) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (canAdjust)
                  OutlinedButton.icon(
                    onPressed: () => onAdjust!(period),
                    icon: const Icon(Symbols.tune_rounded),
                    label: const Text('Ajuster'),
                  ),
                if (canApprove)
                  FilledButton.tonalIcon(
                    onPressed: () => onApprove!(period),
                    icon: const Icon(Symbols.verified_rounded),
                    label: const Text('Approuver'),
                  ),
                if (canPayout)
                  FilledButton.icon(
                    onPressed: () => onPayout!(period),
                    icon: const Icon(Symbols.payments_rounded),
                    label: const Text('Régler'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: IzyTelColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: IzyTelColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bool positive = status == 'approved' || status == 'paid';
    final bool neutral = status == 'calculated';
    final Color foreground = positive
        ? IzyTelColors.success
        : neutral
            ? IzyTelColors.primary
            : IzyTelColors.warning;
    final Color background = positive
        ? IzyTelColors.successSoft
        : neutral
            ? IzyTelColors.primarySoft
            : IzyTelColors.warningSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _label(String value) => switch (value) {
        'calculated' => 'Calculée',
        'approved' => 'Approuvée',
        'paid' => 'Payée',
        'closed' => 'Clôturée',
        'open' => 'Ouverte',
        _ => value.isEmpty ? 'Inconnue' : value,
      };
}
