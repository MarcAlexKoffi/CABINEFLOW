import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/partners/data/repositories/supabase_cabiniste_finance_supervision_repository.dart';
import 'package:cabine_flow/features/partners/domain/models/cabiniste_finance_supervision_models.dart';
import 'package:cabine_flow/features/team/presentation/pages/team_member_detail_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeCabinisteFinancePage extends StatefulWidget {
  const BackofficeCabinisteFinancePage({
    super.key,
    required this.user,
    this.repository,
  });

  final AppUser user;
  final SupabaseCabinisteFinanceSupervisionRepository? repository;

  @override
  State<BackofficeCabinisteFinancePage> createState() =>
      _BackofficeCabinisteFinancePageState();
}

class _BackofficeCabinisteFinancePageState
    extends State<BackofficeCabinisteFinancePage> {
  late final SupabaseCabinisteFinanceSupervisionRepository _repository;
  late Future<CabinisteFinanceSnapshot> _future;
  bool _busy = false;

  bool get _canRecordPayouts =>
      widget.user.role == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        SupabaseCabinisteFinanceSupervisionRepository();
    _future = _repository.fetchSnapshot();
  }

  Future<void> _reload() async {
    final Future<CabinisteFinanceSnapshot> next = _repository.fetchSnapshot();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CabinisteFinanceSnapshot>(
      future: _future,
      builder: (
        BuildContext context,
        AsyncSnapshot<CabinisteFinanceSnapshot> snapshot,
      ) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BackofficePageIntro(
                eyebrow: 'Équipe / Cabinistes',
                title: 'Cabinistes',
                description: _canRecordPayouts
                    ? 'Consulte les comptes Cabinistes, leur activité, ce qu’IzyTel gagne et les montants à reverser.'
                    : 'Consulte les comptes Cabinistes, leur activité, ce qu’IzyTel gagne et les montants à reverser en lecture seule.',
                icon: Symbols.storefront_rounded,
                trailing: OutlinedButton.icon(
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Symbols.refresh_rounded),
                  label: const Text('Actualiser'),
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const LinearProgressIndicator(minHeight: 3),
              if (snapshot.hasError && !snapshot.hasData)
                _ErrorPanel(error: snapshot.error, onRetry: _reload),
              if (snapshot.hasData) ...<Widget>[
                _summary(snapshot.data!.summary),
                const SizedBox(height: 18),
                _partners(snapshot.data!.partners),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _summary(CabinisteFinanceSummary summary) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double cardWidth = width >= 1100
            ? (width - 36) / 4
            : width >= 720
                ? (width - 12) / 2
                : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: BackofficeMetricCard(
                label: 'Gain brut IzyTel',
                value: formatCfa(summary.izytelGrossGainTotal),
                caption: '${summary.completedOrders} commande(s) Cabiniste',
                icon: Symbols.trending_up_rounded,
                emphasis: BackofficePalette.success,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: BackofficeMetricCard(
                label: 'À reverser',
                value: formatCfa(summary.balanceDue),
                caption: '${summary.toPayCount} Cabiniste(s) à régler',
                icon: Symbols.payments_rounded,
                emphasis: BackofficePalette.warning,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: BackofficeMetricCard(
                label: 'Volume traité',
                value: formatCfa(summary.processedAmount),
                caption: 'Montant des commandes finalisées',
                icon: Symbols.receipt_long_rounded,
                emphasis: BackofficePalette.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: BackofficeMetricCard(
                label: 'Déjà reversé',
                value: formatCfa(summary.paidTotal),
                caption: 'Règlements Cabinistes enregistrés',
                icon: Symbols.verified_rounded,
                emphasis: BackofficePalette.cyan,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _partners(List<CabinisteFinancePartner> partners) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BackofficePalette.line),
        boxShadow: BackofficeShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Situation par Cabiniste',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Le gain IzyTel et le règlement dû sont calculés commande par commande puis consolidés ici.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BackofficePalette.muted,
                ),
          ),
          const SizedBox(height: 14),
          if (partners.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(child: Text('Aucune activité Cabiniste.')),
            )
          else
            ...partners.map(_partnerRow),
        ],
      ),
    );
  }

  Widget _partnerRow(CabinisteFinancePartner partner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 760;
          final Widget identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                partner.displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${partner.partnerCode} · ${partner.completedOrders} commande(s)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BackofficePalette.muted,
                    ),
              ),
            ],
          );
          final Widget metrics = Wrap(
            spacing: 20,
            runSpacing: 8,
            children: <Widget>[
              _InlineMetric(label: 'Traité', value: formatCfa(partner.processedAmount)),
              _InlineMetric(label: 'Gain IzyTel', value: formatCfa(partner.izytelGrossGainTotal)),
              _InlineMetric(label: 'À reverser', value: formatCfa(partner.balanceDue)),
              _InlineMetric(label: 'Payé', value: formatCfa(partner.paidTotal)),
            ],
          );
          final Widget actions = Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _showDetails(partner),
                icon: const Icon(Symbols.visibility_rounded),
                label: const Text('Détail'),
              ),
              if (_canRecordPayouts && partner.balanceDue > 0)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _showPayout(partner),
                  icon: const Icon(Symbols.payments_rounded),
                  label: const Text('Régler'),
                ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identity,
                const SizedBox(height: 12),
                metrics,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 2, child: identity),
              Expanded(flex: 4, child: metrics),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDetails(CabinisteFinancePartner partner) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
            child: FutureBuilder<CabinisteFinanceHistory>(
              future: _repository.fetchHistory(partner.partnerId),
              builder: (
                BuildContext context,
                AsyncSnapshot<CabinisteFinanceHistory> snapshot,
              ) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur : ${snapshot.error}'),
                    );
                  }
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final CabinisteFinanceHistory data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 12, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  data.partner.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Gain IzyTel ${formatCfa(data.partner.izytelGrossGainTotal)} · À reverser ${formatCfa(data.balanceDue)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: BackofficePalette.muted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(dialogContext).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => TeamMemberDetailPage(
                                    viewer: widget.user,
                                    actorType: 'cabiniste',
                                    actorId: partner.partnerId,
                                    fallbackName: partner.displayName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Symbols.manage_accounts_rounded),
                            label: const Text('Identité & activité'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Symbols.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: <Widget>[
                          Text(
                            'Commandes financières',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          if (data.orders.isEmpty)
                            const Text('Aucune commande.')
                          else
                            ...data.orders.map(
                              (CabinisteFinanceOrder order) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(order.orderReference),
                                subtitle: Text(
                                  '${order.network.toUpperCase()} · Commande ${formatCfa(order.orderAmount)} · Marge télécom ${formatCfa(order.telecomMarginAmount)}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text(
                                      '+ ${formatCfa(order.izytelGrossGain)} IzyTel',
                                      style: const TextStyle(
                                        color: BackofficePalette.success,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${formatCfa(order.cabinisteSettlementAmount)} à reverser',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Text(
                            'Règlements enregistrés',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          if (data.payouts.isEmpty)
                            const Text('Aucun règlement enregistré.')
                          else
                            ...data.payouts.map(
                              (CabinisteFinancePayout payout) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Symbols.payments_rounded),
                                title: Text(formatCfa(payout.amount)),
                                subtitle: Text(
                                  '${payout.channel} · ${payout.reference}',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPayout(CabinisteFinancePartner partner) async {
    final TextEditingController amount =
        TextEditingController(text: partner.balanceDue.toString());
    final TextEditingController channel = TextEditingController(text: 'Wave');
    final TextEditingController reference = TextEditingController();
    final TextEditingController note = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Régler ${partner.displayName}'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Montant à reverser *',
                      suffixText: 'F CFA',
                    ),
                    validator: (String? value) {
                      final int parsed = int.tryParse(value?.trim() ?? '') ?? 0;
                      if (parsed <= 0) return 'Saisis un montant valide.';
                      if (parsed > partner.balanceDue) {
                        return 'Le montant dépasse le solde dû.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: channel,
                    decoration: const InputDecoration(labelText: 'Canal *'),
                    validator: (String? value) =>
                        (value?.trim().isEmpty ?? true) ? 'Canal obligatoire.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reference,
                    decoration: const InputDecoration(labelText: 'Référence *'),
                    validator: (String? value) =>
                        (value?.trim().isEmpty ?? true) ? 'Référence obligatoire.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Enregistrer le règlement'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      amount.dispose();
      channel.dispose();
      reference.dispose();
      note.dispose();
      return;
    }

    final int payoutAmount = int.parse(amount.text.trim());
    final String payoutChannel = channel.text.trim();
    final String payoutReference = reference.text.trim();
    final String payoutNote = note.text.trim();
    amount.dispose();
    channel.dispose();
    reference.dispose();
    note.dispose();

    setState(() => _busy = true);
    try {
      await _repository.recordPayout(
        partnerId: partner.partnerId,
        amount: payoutAmount,
        paymentChannel: payoutChannel,
        paymentReference: payoutReference,
        note: payoutNote,
      );
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Règlement Cabiniste enregistré.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BackofficePalette.muted,
              ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BackofficePalette.danger.withValues(alpha: .25)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Symbols.error_rounded, color: BackofficePalette.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Impossible de charger les finances Cabinistes. ${error ?? ''}',
            ),
          ),
          OutlinedButton(
            onPressed: () => onRetry(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
