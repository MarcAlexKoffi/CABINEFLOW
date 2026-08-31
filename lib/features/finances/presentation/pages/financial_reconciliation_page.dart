import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/data/repositories/fake_financial_reconciliation_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/firestore_financial_reconciliation_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/financial_reconciliation_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/financial_reconciliation_repository.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart'
    hide formatIvorianPhone;
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/refunds/presentation/pages/refund_management_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _ReconciliationFilter { all, attention, coherent, refunded }

class FinancialReconciliationPage extends StatefulWidget {
  const FinancialReconciliationPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.refundRepository,
    this.reconciliationRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final RefundRepository refundRepository;
  final FinancialReconciliationRepository? reconciliationRepository;

  @override
  State<FinancialReconciliationPage> createState() =>
      _FinancialReconciliationPageState();
}

class _FinancialReconciliationPageState
    extends State<FinancialReconciliationPage> {
  _ReconciliationFilter _filter = _ReconciliationFilter.all;
  late final FinancialReconciliationRepository _repository;
  late Future<List<FinancialReconciliationResult>> _future;

  OrderHistoryRepository? get _historyRepository {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is OrderHistoryRepository) {
      return repository as OrderHistoryRepository;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _repository =
        widget.reconciliationRepository ??
        (Firebase.apps.isNotEmpty
            ? FirestoreFinancialReconciliationRepository()
            : FakeFinancialReconciliationRepository());
    _future = _repository.load();
  }

  void _reload() {
    setState(() {
      _future = _repository.load();
    });
  }

  Future<void> _openRefund(FinancialReconciliationResult result) async {
    final OrderHistoryRepository? history = _historyRepository;
    if (history == null || result.refundId == null) return;

    final List<RefundCase> refunds = await widget.refundRepository.watchAll().first;
    RefundCase? refund;
    for (final RefundCase item in refunds) {
      if (item.id == result.refundId || item.orderId == result.order.id) {
        refund = item;
        break;
      }
    }
    if (!mounted || refund == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RefundDetailPage(
          user: widget.user,
          initialRefund: refund!,
          repository: widget.refundRepository,
          orderHistoryRepository: history,
        ),
      ),
    );
    if (mounted) _reload();
  }

  void _showDetails(FinancialReconciliationResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: IzyTelColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (BuildContext context, ScrollController controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: IzyTelColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Contrôle ${result.order.reference}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.coherentChecks}/${result.requiredChecks} liens requis cohérents',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: IzyTelColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...result.checks.map(
                    (FinancialReconciliationCheck check) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _ReconciliationCheckTile(check: check),
                    ),
                  ),
                  if (result.refundId != null && _historyRepository != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _openRefund(result);
                        },
                        icon: const Icon(Symbols.currency_exchange_rounded),
                        label: const Text('Ouvrir le remboursement'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Rapprochements',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _reload,
            icon: const Icon(Symbols.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<FinancialReconciliationResult>>(
          future: _future,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<FinancialReconciliationResult>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ReconciliationError(
                message: 'Impossible de préparer les rapprochements : ${snapshot.error}',
                onRetry: _reload,
              );
            }

            final List<FinancialReconciliationResult> all =
                snapshot.data ?? const <FinancialReconciliationResult>[];
            final int attention = all
                .where(
                  (FinancialReconciliationResult item) =>
                      item.state == FinancialReconciliationOverallState.attention,
                )
                .length;
            final int coherent = all
                .where(
                  (FinancialReconciliationResult item) =>
                      item.state == FinancialReconciliationOverallState.coherent ||
                      item.state == FinancialReconciliationOverallState.inProgress,
                )
                .length;
            final int refunded = all
                .where(
                  (FinancialReconciliationResult item) =>
                      item.state == FinancialReconciliationOverallState.refunded,
                )
                .length;
            final List<FinancialReconciliationResult> visible = all
                .where(_matchesFilter)
                .toList(growable: false);

            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: IzyTelColors.primarySoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Symbols.rule_rounded,
                              color: IzyTelColors.primary,
                              size: IzyTelIconSize.info,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Contrôle réel de la chaîne paiement → affectation → Agent → traitement → preuve → réseau → commission → remboursement. Le rapprochement bancaire Wave restera manuel tant que l’API officielle n’est pas branchée.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: IzyTelColors.textSecondary,
                                  fontSize: IzyTelTypeScale.micro,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: <Widget>[
                            FinanceFilterPill(
                              label: 'Tous',
                              count: all.length,
                              selected: _filter == _ReconciliationFilter.all,
                              onTap: () => setState(
                                () => _filter = _ReconciliationFilter.all,
                              ),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'À vérifier',
                              count: attention,
                              accent: IzyTelColors.warning,
                              selected:
                                  _filter == _ReconciliationFilter.attention,
                              onTap: () => setState(
                                () => _filter = _ReconciliationFilter.attention,
                              ),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'Cohérents',
                              count: coherent,
                              accent: IzyTelColors.success,
                              selected: _filter == _ReconciliationFilter.coherent,
                              onTap: () => setState(
                                () => _filter = _ReconciliationFilter.coherent,
                              ),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'Remboursés',
                              count: refunded,
                              selected: _filter == _ReconciliationFilter.refunded,
                              onTap: () => setState(
                                () => _filter = _ReconciliationFilter.refunded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const SingleChildScrollView(
                          child: FinanceEmptyState(
                            icon: Symbols.rule_rounded,
                            title: 'Aucun élément dans ce filtre',
                            message:
                                'Les contrôles de cohérence apparaîtront ici au fur et à mesure des transactions.',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            final Future<List<FinancialReconciliationResult>> next =
                                _repository.load();
                            setState(() {
                              _future = next;
                            });
                            await next;
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final FinancialReconciliationResult item = visible[index];
                              return _ReconciliationCard(
                                item: item,
                                onTap: () => _showDetails(item),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _matchesFilter(FinancialReconciliationResult item) {
    switch (_filter) {
      case _ReconciliationFilter.all:
        return true;
      case _ReconciliationFilter.attention:
        return item.state == FinancialReconciliationOverallState.attention;
      case _ReconciliationFilter.coherent:
        return item.state == FinancialReconciliationOverallState.coherent ||
            item.state == FinancialReconciliationOverallState.inProgress;
      case _ReconciliationFilter.refunded:
        return item.state == FinancialReconciliationOverallState.refunded;
    }
  }
}

class _ReconciliationCard extends StatelessWidget {
  const _ReconciliationCard({required this.item, required this.onTap});

  final FinancialReconciliationResult item;
  final VoidCallback onTap;

  Color get _accent {
    switch (item.state) {
      case FinancialReconciliationOverallState.attention:
        return IzyTelColors.warning;
      case FinancialReconciliationOverallState.coherent:
        return IzyTelColors.success;
      case FinancialReconciliationOverallState.inProgress:
        return IzyTelColors.primary;
      case FinancialReconciliationOverallState.refunded:
        return IzyTelColors.moov;
    }
  }

  IconData get _icon {
    switch (item.state) {
      case FinancialReconciliationOverallState.attention:
        return Symbols.warning_rounded;
      case FinancialReconciliationOverallState.coherent:
        return Symbols.check_circle_rounded;
      case FinancialReconciliationOverallState.inProgress:
        return Symbols.schedule_rounded;
      case FinancialReconciliationOverallState.refunded:
        return Symbols.currency_exchange_rounded;
    }
  }

  String get _label {
    switch (item.state) {
      case FinancialReconciliationOverallState.attention:
        return '${item.issues.length} anomalie${item.issues.length > 1 ? 's' : ''} de rapprochement';
      case FinancialReconciliationOverallState.coherent:
        return 'Transaction cohérente';
      case FinancialReconciliationOverallState.inProgress:
        return 'Chaîne cohérente en cours';
      case FinancialReconciliationOverallState.refunded:
        return 'Remboursement rapproché';
    }
  }

  String get _description {
    if (item.issues.isNotEmpty) return item.issues.first.detail;
    return '${item.coherentChecks}/${item.requiredChecks} liens requis validés.';
  }

  @override
  Widget build(BuildContext context) {
    final QueueOrder order = item.order;
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _NetworkLogo(network: order.network),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  networkLabel(order.network),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                financeRelativeTime(item.date),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: IzyTelColors.textMuted,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            order.offerLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.cardTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  formatIvorianPhone(order.beneficiaryPhone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCfa(order.amount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: IzyTelColors.primaryStrong,
                  fontSize: IzyTelTypeScale.cardTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withAlpha(18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(_icon, size: IzyTelIconSize.info, color: _accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _accent,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IzyTelColors.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '${item.coherentChecks}/${item.requiredChecks}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textMuted,
                size: IzyTelIconSize.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReconciliationCheckTile extends StatelessWidget {
  const _ReconciliationCheckTile({required this.check});

  final FinancialReconciliationCheck check;

  Color get _accent {
    switch (check.state) {
      case FinancialReconciliationCheckState.coherent:
        return IzyTelColors.success;
      case FinancialReconciliationCheckState.attention:
        return IzyTelColors.warning;
      case FinancialReconciliationCheckState.notApplicable:
        return IzyTelColors.textMuted;
    }
  }

  IconData get _icon {
    switch (check.state) {
      case FinancialReconciliationCheckState.coherent:
        return Symbols.check_circle_rounded;
      case FinancialReconciliationCheckState.attention:
        return Symbols.warning_rounded;
      case FinancialReconciliationCheckState.notApplicable:
        return Symbols.remove_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_icon, color: _accent, size: IzyTelIconSize.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  check.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  check.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationError extends StatelessWidget {
  const _ReconciliationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Symbols.error_rounded,
              color: IzyTelColors.warning,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: IzyTelColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network});

  final MobileNetwork network;

  String get _asset => switch (network) {
    MobileNetwork.orange => 'assets/brands/operators/orange_ci.png',
    MobileNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
    MobileNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: IzyTelColors.border),
      ),
      child: Image.asset(_asset, fit: BoxFit.contain),
    );
  }
}
