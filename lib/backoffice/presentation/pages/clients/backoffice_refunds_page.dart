import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _RefundScope { all, pending, approved, refunded, reconciled, rejected }

class BackofficeRefundsPage extends StatefulWidget {
  const BackofficeRefundsPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final RefundRepository repository;

  @override
  State<BackofficeRefundsPage> createState() => _BackofficeRefundsPageState();
}

class _BackofficeRefundsPageState extends State<BackofficeRefundsPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<RefundCase>> _stream;
  _RefundScope _scope = _RefundScope.pending;
  String _query = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RefundCase>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<RefundCase>> snapshot) {
        if (snapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.cloud_off_rounded,
            title: 'Remboursements indisponibles',
            message: 'Les dossiers de remboursement ne peuvent pas être chargés pour le moment.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<RefundCase> all = snapshot.data!;
        final int pending = all.where((RefundCase item) => item.status == RefundStatus.pendingApproval).length;
        final int approved = all.where((RefundCase item) => item.status == RefundStatus.approved).length;
        final int completed = all.where((RefundCase item) => item.isRefundCompleted).length;
        final int exposure = all.where((RefundCase item) => item.status.isActive).fold<int>(0, (int total, RefundCase item) => total + item.amount);
        final List<RefundCase> visible = _filtered(all);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const BackofficePageIntro(
              eyebrow: 'Clients / Remboursements',
              title: 'Centre des remboursements',
              description: 'Valide, exécute et rapproche les remboursements en gardant le statut et le montant exposé visibles immédiatement.',
              icon: Symbols.currency_exchange_rounded,
            ),
            const SizedBox(height: 18),
            _metrics(pending: pending, approved: approved, completed: completed, exposure: exposure),
            const SizedBox(height: 14),
            _filters(all: all),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const BackofficeEmptyState(
                icon: Symbols.currency_exchange_rounded,
                title: 'Aucun remboursement',
                message: 'Les dossiers correspondant aux filtres actifs apparaîtront ici.',
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth >= 920) return _desktopTable(visible);
                  return Column(
                    children: visible.map((RefundCase refund) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _mobileCard(refund),
                    )).toList(growable: false),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _metrics({required int pending, required int approved, required int completed, required int exposure}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        final double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'À valider', value: '$pending', caption: 'dossiers en attente', icon: Symbols.fact_check_rounded, emphasis: BackofficePalette.warning),
          BackofficeMetricCard(label: 'À effectuer', value: '$approved', caption: 'remboursements approuvés', icon: Symbols.payments_rounded),
          BackofficeMetricCard(label: 'Finalisés', value: '$completed', caption: 'remboursés / rapprochés', icon: Symbols.task_alt_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Exposition', value: formatCfa(exposure), caption: 'montant encore engagé', icon: Symbols.account_balance_wallet_rounded, emphasis: BackofficePalette.cyan),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _filters({required List<RefundCase> all}) {
    int count(RefundStatus status) => all.where((RefundCase item) => item.status == status).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Référence, client, téléphone ou motif',
              prefixIcon: Icon(Symbols.search_rounded),
            ),
          );
          final Widget scope = DropdownButtonFormField<_RefundScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: <DropdownMenuItem<_RefundScope>>[
              DropdownMenuItem(value: _RefundScope.all, child: Text('Tous (${all.length})')),
              DropdownMenuItem(value: _RefundScope.pending, child: Text('À valider (${count(RefundStatus.pendingApproval)})')),
              DropdownMenuItem(value: _RefundScope.approved, child: Text('À effectuer (${count(RefundStatus.approved)})')),
              DropdownMenuItem(value: _RefundScope.refunded, child: Text('Remboursés (${count(RefundStatus.refunded)})')),
              DropdownMenuItem(value: _RefundScope.reconciled, child: Text('Rapprochés (${count(RefundStatus.reconciled)})')),
              DropdownMenuItem(value: _RefundScope.rejected, child: Text('Rejetés (${count(RefundStatus.rejected)})')),
            ],
            onChanged: (_RefundScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          if (constraints.maxWidth < 760) {
            return Column(children: <Widget>[search, const SizedBox(height: 10), scope]);
          }
          return Row(children: <Widget>[Expanded(flex: 3, child: search), const SizedBox(width: 10), SizedBox(width: 260, child: scope)]);
        },
      ),
    );
  }

  List<RefundCase> _filtered(List<RefundCase> all) {
    final String query = _query.trim().toLowerCase();
    final List<RefundCase> result = all.where((RefundCase item) {
      final bool inScope = switch (_scope) {
        _RefundScope.all => true,
        _RefundScope.pending => item.status == RefundStatus.pendingApproval,
        _RefundScope.approved => item.status == RefundStatus.approved,
        _RefundScope.refunded => item.status == RefundStatus.refunded,
        _RefundScope.reconciled => item.status == RefundStatus.reconciled,
        _RefundScope.rejected => item.status == RefundStatus.rejected,
      };
      if (!inScope) return false;
      if (query.isEmpty) return true;
      return <String>[item.orderReference, item.clientName, item.clientWhatsappPhone, item.reason.label, item.status.label].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
    result.sort((RefundCase a, RefundCase b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Widget _desktopTable(List<RefundCase> refunds) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'DOSSIER', flex: 3),
        BackofficeTableColumnSpec(label: 'CLIENT', flex: 3),
        BackofficeTableColumnSpec(label: 'MONTANT / MOTIF', flex: 3),
        BackofficeTableColumnSpec(label: 'ACTION', flex: 2, alignment: Alignment.centerRight),
      ],
      rows: refunds.map((RefundCase refund) {
        final Color color = _statusColor(refund.status);
        return BackofficeDesktopTableRow(
          accentColor: refund.status.isActive ? color : null,
          backgroundColor: refund.status == RefundStatus.pendingApproval ? BackofficePalette.warning.withValues(alpha: .025) : null,
          onTap: () => _openDetails(refund),
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(flex: 2, child: BackofficeStatusBadge(label: refund.status.label, color: color)),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(refund.orderReference, _formatDate(refund.requestedAt))),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(refund.clientName, refund.clientWhatsappPhone)),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(formatCfa(refund.amount), refund.reason.label)),
            BackofficeTableCellSpec(flex: 2, alignment: Alignment.centerRight, child: _primaryAction(refund)),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(RefundCase refund) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(refund),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[Expanded(child: BackofficeStatusBadge(label: refund.status.label, color: _statusColor(refund.status))), const SizedBox(width: 8), Text(formatCfa(refund.amount), style: Theme.of(context).textTheme.titleMedium)]),
              const SizedBox(height: 10),
              Text(refund.orderReference, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('${refund.clientName} • ${refund.reason.label}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: _primaryAction(refund)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoLines(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _primaryAction(RefundCase refund) {
    if (!widget.user.permissions.canManageRefunds) {
      return OutlinedButton(onPressed: () => _openDetails(refund), child: const Text('Voir'));
    }
    switch (refund.status) {
      case RefundStatus.pendingApproval:
        return FilledButton(onPressed: _submitting ? null : () => _approve(refund), child: const Text('Valider'));
      case RefundStatus.approved:
        return FilledButton(onPressed: _submitting ? null : () => _markRefunded(refund), child: const Text('Rembourser'));
      case RefundStatus.refunded:
        if (!refund.customerWasNotified) {
          return FilledButton(onPressed: _submitting ? null : () => _notifyCustomer(refund), child: const Text('Notifier'));
        }
        return OutlinedButton(onPressed: _submitting ? null : () => _reconcile(refund), child: const Text('Rapprocher'));
      case RefundStatus.reconciled:
      case RefundStatus.rejected:
        return OutlinedButton(onPressed: () => _openDetails(refund), child: const Text('Voir'));
    }
  }

  Future<void> _approve(RefundCase refund) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Valider le remboursement ?'),
        content: Text('${refund.orderReference} • ${formatCfa(refund.amount)}'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(() => widget.repository.approve(orderId: refund.orderId, staffId: widget.user.id, staffName: widget.user.name));
  }

  Future<void> _markRefunded(RefundCase refund) async {
    final String? reference = await _textDialog(title: 'Confirmer le remboursement', hint: 'Référence de remboursement Wave', actionLabel: 'Marquer remboursé');
    if (reference == null) return;
    await _runAction(() => widget.repository.markRefunded(orderId: refund.orderId, staffId: widget.user.id, staffName: widget.user.name, refundReference: reference));
  }

  Future<void> _notifyCustomer(RefundCase refund) async {
    await _runAction(() => widget.repository.markCustomerNotified(orderId: refund.orderId, staffId: widget.user.id, staffName: widget.user.name));
  }

  Future<void> _reconcile(RefundCase refund) async {
    await _runAction(() => widget.repository.reconcile(orderId: refund.orderId, staffId: widget.user.id, staffName: widget.user.name));
  }

  Future<void> _reject(RefundCase refund) async {
    final String? reason = await _textDialog(title: 'Rejeter le remboursement', hint: 'Motif du rejet', actionLabel: 'Rejeter');
    if (reason == null) return;
    await _runAction(() => widget.repository.reject(orderId: refund.orderId, staffId: widget.user.id, staffName: widget.user.name, reason: reason));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action enregistrée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _textDialog({required String title, required String hint, required String actionLabel}) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 440, child: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: hint))),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            final String value = controller.text.trim();
            if (value.length >= 3) Navigator.pop(context, value);
          }, child: Text(actionLabel)),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openDetails(RefundCase refund) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(children: <Widget>[Expanded(child: Text(refund.orderReference)), BackofficeStatusBadge(label: refund.status.label, color: _statusColor(refund.status))]),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _detail('Client', refund.clientName),
                _detail('WhatsApp', refund.clientWhatsappPhone),
                _detail('Montant', formatCfa(refund.amount)),
                _detail('Motif', refund.reason.label),
                if (refund.reasonNote.trim().isNotEmpty) _detail('Note', refund.reasonNote),
                _detail('Demandé le', _formatDate(refund.requestedAt)),
                if (refund.refundReference != null) _detail('Référence remboursement', refund.refundReference!),
                _detail('Client notifié', refund.customerWasNotified ? 'Oui' : 'Non'),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (widget.user.permissions.canManageRefunds && refund.status == RefundStatus.pendingApproval)
            TextButton(onPressed: () { Navigator.pop(context); _reject(refund); }, style: TextButton.styleFrom(foregroundColor: BackofficePalette.danger), child: const Text('Rejeter')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ]),
    );
  }

  Color _statusColor(RefundStatus status) {
    switch (status) {
      case RefundStatus.pendingApproval:
        return BackofficePalette.warning;
      case RefundStatus.approved:
        return BackofficePalette.primary;
      case RefundStatus.refunded:
      case RefundStatus.reconciled:
        return BackofficePalette.success;
      case RefundStatus.rejected:
        return BackofficePalette.danger;
    }
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }
}
