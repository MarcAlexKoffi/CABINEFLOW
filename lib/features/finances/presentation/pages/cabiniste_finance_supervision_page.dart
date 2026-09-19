import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/partners/data/repositories/supabase_cabiniste_finance_supervision_repository.dart';
import 'package:cabine_flow/features/partners/domain/models/cabiniste_finance_supervision_models.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CabinisteFinanceSupervisionPage extends StatefulWidget {
  const CabinisteFinanceSupervisionPage({
    super.key,
    this.repository,
  });

  final SupabaseCabinisteFinanceSupervisionRepository? repository;

  @override
  State<CabinisteFinanceSupervisionPage> createState() =>
      _CabinisteFinanceSupervisionPageState();
}

class _CabinisteFinanceSupervisionPageState
    extends State<CabinisteFinanceSupervisionPage> {
  late final SupabaseCabinisteFinanceSupervisionRepository _repository;
  late Future<CabinisteFinanceSnapshot> _future;

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
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Finances Cabinistes'),
      ),
      body: FutureBuilder<CabinisteFinanceSnapshot>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<CabinisteFinanceSnapshot> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return _ErrorState(onRetry: _reload, error: snapshot.error);
          }
          final CabinisteFinanceSnapshot data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                const IzyTelPageHeader(
                  title: 'Cabinistes',
                  subtitle:
                      'Comptes Cabinistes, activité, gain IzyTel, montant à reverser et historique détaillé.',
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                _summaryGrid(data.summary),
                const SizedBox(height: IzyTelSpacing.xl),
                const IzyTelSectionHeader(title: 'Situation par Cabiniste'),
                const SizedBox(height: 8),
                if (data.partners.isEmpty)
                  const IzyTelSurface(
                    child: Padding(
                      padding: EdgeInsets.all(IzyTelSpacing.lg),
                      child: Text('Aucune activité Cabiniste enregistrée.'),
                    ),
                  )
                else
                  ...data.partners.map(
                    (CabinisteFinancePartner partner) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PartnerCard(
                        partner: partner,
                        onTap: () => _openPartner(partner),
                      ),
                    ),
                  ),
                const SizedBox(height: IzyTelSpacing.md),
                IzyTelSurface(
                  padding: const EdgeInsets.all(IzyTelSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Symbols.visibility_rounded,
                        color: IzyTelColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Les montants sont calculés commande par commande. Les règlements Cabinistes restent réservés à l’Administrateur.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: IzyTelColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryGrid(CabinisteFinanceSummary summary) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FinancialMetricCard(
                label: 'Gain IzyTel',
                value: formatCfa(summary.izytelGrossGainTotal),
                icon: Symbols.trending_up_rounded,
                accent: IzyTelColors.success,
                caption: '${summary.completedOrders} commande(s)',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FinancialMetricCard(
                label: 'À reverser',
                value: formatCfa(summary.balanceDue),
                icon: Symbols.payments_rounded,
                accent: IzyTelColors.warning,
                caption: '${summary.toPayCount} Cabiniste(s)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: FinancialMetricCard(
                label: 'Volume traité',
                value: formatCfa(summary.processedAmount),
                icon: Symbols.receipt_long_rounded,
                accent: IzyTelColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FinancialMetricCard(
                label: 'Déjà reversé',
                value: formatCfa(summary.paidTotal),
                icon: Symbols.verified_rounded,
                accent: IzyTelColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPartner(CabinisteFinancePartner partner) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _CabinisteFinanceDetailPage(
          partner: partner,
          repository: _repository,
        ),
      ),
    );
    if (mounted) await _reload();
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.onTap});

  final CabinisteFinancePartner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(IzyTelRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        child: Container(
          padding: const EdgeInsets.all(IzyTelSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(IzyTelRadii.card),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
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
                          partner.partnerCode,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: IzyTelColors.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Symbols.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: <Widget>[
                  _MiniValue(label: 'Traité', value: formatCfa(partner.processedAmount)),
                  _MiniValue(label: 'Gain IzyTel', value: formatCfa(partner.izytelGrossGainTotal)),
                  _MiniValue(label: 'À reverser', value: formatCfa(partner.balanceDue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.label, required this.value});

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
                color: IzyTelColors.textMuted,
              ),
        ),
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

class _CabinisteFinanceDetailPage extends StatefulWidget {
  const _CabinisteFinanceDetailPage({
    required this.partner,
    required this.repository,
  });

  final CabinisteFinancePartner partner;
  final SupabaseCabinisteFinanceSupervisionRepository repository;

  @override
  State<_CabinisteFinanceDetailPage> createState() =>
      _CabinisteFinanceDetailPageState();
}

class _CabinisteFinanceDetailPageState
    extends State<_CabinisteFinanceDetailPage> {
  late Future<CabinisteFinanceHistory> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchHistory(widget.partner.partnerId);
  }

  Future<void> _reload() async {
    final Future<CabinisteFinanceHistory> next =
        widget.repository.fetchHistory(widget.partner.partnerId);
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Détail Cabiniste'),
      ),
      body: FutureBuilder<CabinisteFinanceHistory>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<CabinisteFinanceHistory> snapshot,
        ) {
          if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return _ErrorState(onRetry: _reload, error: snapshot.error);
          }
          final CabinisteFinanceHistory data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                IzyTelPageHeader(
                  title: data.partner.displayName,
                  subtitle: data.partner.partnerCode,
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FinancialMetricCard(
                        label: 'Gain IzyTel',
                        value: formatCfa(data.partner.izytelGrossGainTotal),
                        icon: Symbols.trending_up_rounded,
                        accent: IzyTelColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FinancialMetricCard(
                        label: 'À reverser',
                        value: formatCfa(data.balanceDue),
                        icon: Symbols.payments_rounded,
                        accent: IzyTelColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.xl),
                const IzyTelSectionHeader(title: 'Commandes financières'),
                const SizedBox(height: 8),
                if (data.orders.isEmpty)
                  const IzyTelSurface(
                    child: Padding(
                      padding: EdgeInsets.all(IzyTelSpacing.md),
                      child: Text('Aucune commande financière.'),
                    ),
                  )
                else
                  ...data.orders.map(
                    (CabinisteFinanceOrder order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: IzyTelSurface(
                        padding: const EdgeInsets.all(IzyTelSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    order.orderReference,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(formatCfa(order.orderAmount)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${order.network.toUpperCase()} · Marge télécom ${formatCfa(order.telecomMarginAmount)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: IzyTelColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'IzyTel : ${formatCfa(order.izytelGrossGain)} · À reverser : ${formatCfa(order.cabinisteSettlementAmount)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.error});

  final Future<void> Function() onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Symbols.error_rounded, color: IzyTelColors.error),
            const SizedBox(height: 10),
            Text(
              'Impossible de charger les finances Cabinistes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textMuted,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
