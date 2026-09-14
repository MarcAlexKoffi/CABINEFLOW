import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _SupportScope { all, newRequests, inProgress, resolved }

class BackofficeSupportRequestsPage extends StatefulWidget {
  const BackofficeSupportRequestsPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final SupportRequestRepository repository;

  @override
  State<BackofficeSupportRequestsPage> createState() =>
      _BackofficeSupportRequestsPageState();
}

class _BackofficeSupportRequestsPageState
    extends State<BackofficeSupportRequestsPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<SupportRequest>> _stream;
  _SupportScope _scope = _SupportScope.newRequests;
  String _query = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchAllRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportRequest>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<SupportRequest>> snapshot) {
        if (snapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.cloud_off_rounded,
            title: 'Demandes clients indisponibles',
            message: 'Le centre d’assistance ne peut pas être chargé pour le moment.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<SupportRequest> all = snapshot.data!;
        final int newCount = all
            .where((SupportRequest item) => item.status == SupportRequestStatus.newRequest)
            .length;
        final int inProgressCount = all
            .where((SupportRequest item) => item.status == SupportRequestStatus.inProgress)
            .length;
        final int resolvedCount = all.where((SupportRequest item) => item.isResolved).length;
        final List<SupportRequest> visible = _filtered(all);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BackofficePageIntro(
              eyebrow: 'Clients / Assistance',
              title: 'Centre des demandes clients',
              description: widget.user.permissions.canProcessSupportRequests
                  ? 'Centralise les incidents clients, attribue leur traitement et conserve une trace claire de chaque résolution.'
                  : 'Supervise les demandes clients et leur avancement en lecture seule depuis le back-office.',
              icon: Symbols.support_agent_rounded,
            ),
            const SizedBox(height: 18),
            _metrics(
              allCount: all.length,
              newCount: newCount,
              inProgressCount: inProgressCount,
              resolvedCount: resolvedCount,
            ),
            const SizedBox(height: 14),
            _filters(
              allCount: all.length,
              newCount: newCount,
              inProgressCount: inProgressCount,
              resolvedCount: resolvedCount,
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const BackofficeEmptyState(
                icon: Symbols.inbox_rounded,
                title: 'Aucune demande dans cette vue',
                message: 'Les demandes correspondant aux filtres actifs apparaîtront ici.',
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth >= 920) {
                    return _desktopTable(visible);
                  }
                  return Column(
                    children: visible
                        .map((SupportRequest request) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _mobileCard(request),
                            ))
                        .toList(growable: false),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _metrics({
    required int allCount,
    required int newCount,
    required int inProgressCount,
    required int resolvedCount,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        final double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(
            label: 'À traiter',
            value: '$newCount',
            caption: 'nouvelles demandes',
            icon: Symbols.support_agent_rounded,
            emphasis: BackofficePalette.warning,
          ),
          BackofficeMetricCard(
            label: 'En cours',
            value: '$inProgressCount',
            caption: 'prises en charge',
            icon: Symbols.fact_check_rounded,
          ),
          BackofficeMetricCard(
            label: 'Traitées',
            value: '$resolvedCount',
            caption: 'résolues ou fermées',
            icon: Symbols.task_alt_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Total',
            value: '$allCount',
            caption: 'demandes suivies',
            icon: Symbols.support_agent_rounded,
            emphasis: BackofficePalette.cyan,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _filters({
    required int allCount,
    required int newCount,
    required int inProgressCount,
    required int resolvedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Référence, motif, description ou responsable',
              prefixIcon: Icon(Symbols.search_rounded),
            ),
          );
          final Widget scope = DropdownButtonFormField<_SupportScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: <DropdownMenuItem<_SupportScope>>[
              DropdownMenuItem(value: _SupportScope.all, child: Text('Toutes ($allCount)')),
              DropdownMenuItem(value: _SupportScope.newRequests, child: Text('À traiter ($newCount)')),
              DropdownMenuItem(value: _SupportScope.inProgress, child: Text('En cours ($inProgressCount)')),
              DropdownMenuItem(value: _SupportScope.resolved, child: Text('Historique ($resolvedCount)')),
            ],
            onChanged: (_SupportScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          if (constraints.maxWidth < 760) {
            return Column(children: <Widget>[search, const SizedBox(height: 10), scope]);
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 250, child: scope),
            ],
          );
        },
      ),
    );
  }

  List<SupportRequest> _filtered(List<SupportRequest> all) {
    final String query = _query.trim().toLowerCase();
    final Iterable<SupportRequest> scoped = all.where((SupportRequest item) {
      switch (_scope) {
        case _SupportScope.all:
          return true;
        case _SupportScope.newRequests:
          return item.status == SupportRequestStatus.newRequest;
        case _SupportScope.inProgress:
          return item.status == SupportRequestStatus.inProgress;
        case _SupportScope.resolved:
          return item.isResolved;
      }
    });
    final List<SupportRequest> result = scoped.where((SupportRequest item) {
      if (query.isEmpty) return true;
      return <String>[
        item.orderReference,
        item.type.label,
        item.description,
        item.status.label,
        item.assignedToName ?? '',
        item.resolvedByName ?? '',
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
    result.sort((SupportRequest a, SupportRequest b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Widget _desktopTable(List<SupportRequest> requests) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'DEMANDE', flex: 4),
        BackofficeTableColumnSpec(label: 'COMMANDE', flex: 3),
        BackofficeTableColumnSpec(label: 'PRISE EN CHARGE', flex: 3),
        BackofficeTableColumnSpec(label: 'ACTION', flex: 2, alignment: Alignment.centerRight),
      ],
      rows: requests.map((SupportRequest request) {
        final Color color = _statusColor(request.status);
        return BackofficeDesktopTableRow(
          accentColor: request.status == SupportRequestStatus.newRequest ? BackofficePalette.warning : null,
          backgroundColor: request.status == SupportRequestStatus.newRequest
              ? BackofficePalette.warning.withValues(alpha: .025)
              : null,
          onTap: () => _openDetails(request),
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(
              flex: 2,
              child: BackofficeStatusBadge(label: request.status.label, color: color),
            ),
            BackofficeTableCellSpec(
              flex: 4,
              child: _twoLines(request.type.label, request.description.isEmpty ? 'Sans description' : request.description),
            ),
            BackofficeTableCellSpec(
              flex: 3,
              child: _twoLines(request.orderReference, _formatDate(request.createdAt)),
            ),
            BackofficeTableCellSpec(
              flex: 3,
              child: _twoLines(request.assignedToName ?? 'Non attribuée', request.customerWasNotified ? 'Client notifié' : 'Notification client en attente'),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              alignment: Alignment.centerRight,
              child: _primaryAction(request),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(SupportRequest request) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(request),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: BackofficeStatusBadge(label: request.status.label, color: _statusColor(request.status))),
                  const SizedBox(width: 8),
                  Text(_formatDate(request.createdAt), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              Text(request.type.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(request.orderReference, style: Theme.of(context).textTheme.bodySmall),
              if (request.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(request.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: _primaryAction(request)),
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

  Widget _primaryAction(SupportRequest request) {
    if (!widget.user.permissions.canProcessSupportRequests) {
      return OutlinedButton(onPressed: () => _openDetails(request), child: const Text('Voir'));
    }
    switch (request.status) {
      case SupportRequestStatus.newRequest:
        return FilledButton(
          onPressed: _submitting ? null : () => _takeInCharge(request),
          child: const Text('Prendre'),
        );
      case SupportRequestStatus.inProgress:
        return FilledButton(
          onPressed: _submitting ? null : () => _resolve(request),
          child: const Text('Résoudre'),
        );
      case SupportRequestStatus.resolved:
        if (!request.customerWasNotified) {
          return FilledButton(
            onPressed: _submitting ? null : () => _notifyCustomer(request),
            child: const Text('Notifier'),
          );
        }
        return OutlinedButton(
          onPressed: _submitting ? null : () => _close(request),
          child: const Text('Fermer'),
        );
      case SupportRequestStatus.closed:
        return OutlinedButton(onPressed: () => _openDetails(request), child: const Text('Voir'));
    }
  }

  Future<void> _takeInCharge(SupportRequest request) async {
    await _runAction(() => widget.repository.takeInCharge(
          requestId: request.id,
          staffId: widget.user.id,
          staffName: widget.user.name,
        ));
  }

  Future<void> _resolve(SupportRequest request) async {
    final String? note = await _textDialog(
      title: 'Résoudre la demande',
      hint: 'Note de résolution',
      actionLabel: 'Confirmer la résolution',
    );
    if (note == null) return;
    await _runAction(() => widget.repository.resolve(
          requestId: request.id,
          staffId: widget.user.id,
          staffName: widget.user.name,
          resolutionNote: note,
        ));
  }

  Future<void> _notifyCustomer(SupportRequest request) async {
    await _runAction(() => widget.repository.markCustomerNotified(
          requestId: request.id,
          staffId: widget.user.id,
          staffName: widget.user.name,
        ));
  }

  Future<void> _close(SupportRequest request) async {
    await _runAction(() => widget.repository.close(
          requestId: request.id,
          staffId: widget.user.id,
          staffName: widget.user.name,
        ));
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

  Future<String?> _textDialog({
    required String title,
    required String hint,
    required String actionLabel,
  }) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.length >= 3) Navigator.pop(context, value);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openDetails(SupportRequest request) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: <Widget>[
            Expanded(child: Text(request.orderReference)),
            BackofficeStatusBadge(label: request.status.label, color: _statusColor(request.status)),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _detail('Motif', request.type.label),
                _detail('Description', request.description.isEmpty ? 'Aucune description' : request.description),
                _detail('Créée le', _formatDate(request.createdAt)),
                _detail('Responsable', request.assignedToName ?? 'Non attribuée'),
                if (request.resolutionNote != null) _detail('Résolution', request.resolutionNote!),
                _detail('Client notifié', request.customerWasNotified ? 'Oui' : 'Non'),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Color _statusColor(SupportRequestStatus status) {
    switch (status) {
      case SupportRequestStatus.newRequest:
        return BackofficePalette.warning;
      case SupportRequestStatus.inProgress:
        return BackofficePalette.primary;
      case SupportRequestStatus.resolved:
        return BackofficePalette.success;
      case SupportRequestStatus.closed:
        return BackofficePalette.muted;
    }
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }
}
