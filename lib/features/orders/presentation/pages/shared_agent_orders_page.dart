import 'dart:async';
import 'package:cabine_flow/core/notifications/izytel_notification_payload.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_order_detail_route_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/shared_order_queue_view_model.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SharedAgentOrdersPage extends StatefulWidget {
  const SharedAgentOrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    this.agentRepository,
    this.onOpenProfile,
    this.onOpenPerformance,
    this.onOpenCommissions,
    this.onLogout,
    this.notificationOrderRequest,
    this.sharedRepository,
  });
  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository? agentRepository;
  final SharedOrderQueueRepository? sharedRepository;
  final VoidCallback? onOpenProfile,
      onOpenPerformance,
      onOpenCommissions,
      onLogout;
  final ValueListenable<IzyTelNotificationPayload?>? notificationOrderRequest;
  @override
  State<SharedAgentOrdersPage> createState() => _SharedAgentOrdersPageState();
}

class _SharedAgentOrdersPageState extends State<SharedAgentOrdersPage>
    with WidgetsBindingObserver {
  SharedOrderQueueViewModel? _queue;
  late final AgentOrdersViewModel _detail;
  final _scrollController = ScrollController();
  bool _available = true, _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final raw =
        widget.sharedRepository ??
        (widget.ordersRepository is SharedOrderQueueRepository
            ? widget.ordersRepository as SharedOrderQueueRepository
            : null);
    if (raw != null) {
      _queue = SharedOrderQueueViewModel(raw)..start();
    }
    _detail = AgentOrdersViewModel(
      agentId: widget.user.id,
      ordersRepository: widget.ordersRepository,
      agentRepository: widget.agentRepository,
    );
    if (raw != null) unawaited(_detail.start());
    widget.notificationOrderRequest?.addListener(_notification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notification();
    });
  }

  @override
  void didUpdateWidget(covariant SharedAgentOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notificationOrderRequest != widget.notificationOrderRequest) {
      oldWidget.notificationOrderRequest?.removeListener(_notification);
      widget.notificationOrderRequest?.addListener(_notification);
      _notification();
    }
  }

  void _notification() {
    final payload = widget.notificationOrderRequest?.value;
    if (payload == null || _queue == null || !mounted) return;
    setState(
      () => _available =
          payload.type == 'order_available' || payload.route == 'shared_queue',
    );
    if (_available) unawaited(_queue!.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _queue != null) {
      unawaited(_queue!.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationOrderRequest?.removeListener(_notification);
    _queue?.dispose();
    _detail.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _claim(AvailableSharedOrder item) async {
    if (_opening) return;
    final order = await _queue!.claim(item);
    if (!mounted) return;
    if (order == null) {
      if (_queue!.errorMessage != null) {
        IzyTelFeedback.error(context, _queue!.errorMessage!);
      }
      return;
    }
    if (order.assignedAgentId != widget.user.id) {
      IzyTelFeedback.error(
        context,
        'L’acceptation n’a pas pu être confirmée pour votre session.',
      );
      return;
    }
    _detail.includeClaimedOrder(order);
    IzyTelFeedback.success(
      context,
      'Commande acceptée. Vous pouvez la traiter.',
    );
    _opening = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: 'agent-order-detail/${order.id}'),
          builder: (_) => AgentOrderDetailRoutePage(
            user: widget.user,
            initialOrder: order,
            viewModel: _detail,
          ),
        ),
      );
    } finally {
      _opening = false;
      if (mounted) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        unawaited(_queue!.refresh());
      }
    }
  }

  Widget _personal({SharedOrderQueueViewModel? queue}) => AgentOrdersPage(
    user: widget.user,
    ordersRepository: widget.ordersRepository,
    agentRepository: widget.agentRepository,
    onOpenProfile: widget.onOpenProfile,
    onOpenPerformance: widget.onOpenPerformance,
    onOpenCommissions: widget.onOpenCommissions,
    onLogout: widget.onLogout,
    notificationOrderRequest: _queue == null || !_available
        ? widget.notificationOrderRequest
        : null,
    queueTabs: queue == null
        ? null
        : Row(
            children: [
              Expanded(child: _tab('À prendre', true)),
              const SizedBox(width: 8),
              Expanded(child: _tab('Mes commandes', false)),
            ],
          ),
    sharedQueueChildren: queue != null && _available
        ? _availableContent(queue)
        : null,
    onRefreshSharedQueue: queue?.refresh,
    scrollController: _scrollController,
  );

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    if (queue == null) return _personal();
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) => _personal(queue: queue),
    );
  }

  Widget _tab(String label, bool available) => Semantics(
    selected: _available == available,
    child: TextButton(
      onPressed: () => setState(() => _available = available),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: _available == available
            ? IzyTelColors.primaryStrong
            : IzyTelColors.textSecondary,
        backgroundColor: _available == available
            ? IzyTelColors.primarySoft
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: IzyTelTypeScale.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
    String? action,
    VoidCallback? onAction,
  }) => IzyTelSurface(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(icon, size: IzyTelIconSize.state, color: IzyTelColors.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: IzyTelTypeScale.cardTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: IzyTelColors.textSecondary,
            fontSize: IzyTelTypeScale.label,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ],
    ),
  );

  List<Widget> _availableContent(SharedOrderQueueViewModel queue) {
    if (queue.loading) {
      return [
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (queue.errorMessage != null && queue.orders.isEmpty) {
      return [
        _state(
          icon: Symbols.cloud_off_rounded,
          title: 'La file est indisponible',
          message: queue.errorMessage!,
          action: 'Réessayer',
          onAction: queue.refresh,
        ),
      ];
    }
    if (queue.snapshot?.enabled == false) {
      return [
        _state(
          icon: Symbols.inbox_rounded,
          title: 'La file partagée sera bientôt disponible',
          message: 'Retrouvez vos commandes attribuées dans Mes commandes.',
          action: 'Voir mes commandes',
          onAction: () => setState(() => _available = false),
        ),
      ];
    }
    return [
      Text(
        '${queue.orders.length} commande${queue.orders.length > 1 ? 's' : ''} à prendre',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: IzyTelTypeScale.title2,
          fontWeight: FontWeight.w800,
          height: 1.18,
          letterSpacing: -.25,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Les commandes disponibles dans vos zones.',
        style: TextStyle(
          color: IzyTelColors.textSecondary,
          fontSize: IzyTelTypeScale.label,
        ),
      ),
      const SizedBox(height: 16),
      if (queue.errorMessage != null) ...[
        _state(
          icon: Symbols.sync_problem_rounded,
          title: 'Actualisation nécessaire',
          message: queue.errorMessage!,
          action: 'Réessayer',
          onAction: queue.refresh,
        ),
        const SizedBox(height: 12),
      ],
      if (queue.orders.isEmpty)
        _state(
          icon: Symbols.inbox_rounded,
          title: 'Aucune commande à prendre',
          message: 'Les nouvelles commandes de vos zones apparaîtront ici.',
        )
      else
        ...queue.orders.map((item) => _card(item, queue)),
    ];
  }

  Widget _card(AvailableSharedOrder item, SharedOrderQueueViewModel queue) {
    final age = queue.snapshot!.serverNow.difference(item.availableAt);
    final ageText = age.inMinutes <= 0 ? 'À l’instant' : '${age.inMinutes} min';
    final busy = queue.busyOrderId == item.id;
    final canAccept = queue.canAct && item.canAccept;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IzyTelSurface(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: IzyTelColors.primarySoft.withAlpha(120),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Image.asset(
                    networkAsset(item.network),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    networkLabel(item.network),
                    style: const TextStyle(
                      color: IzyTelColors.textSecondary,
                      fontSize: IzyTelTypeScale.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: IzyTelStatusPill(
                    label: !queue.fresh
                        ? 'À vérifier'
                        : item.canAccept
                        ? 'Disponible'
                        : 'Indisponible',
                    color: canAccept
                        ? IzyTelColors.success
                        : IzyTelColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.offerLabel,
              style: const TextStyle(
                fontSize: IzyTelTypeScale.title3,
                height: 1.18,
                fontWeight: FontWeight.w700,
                color: IzyTelColors.textPrimary,
              ),
            ),
            if (item.serviceLabel != item.offerLabel) ...[
              const SizedBox(height: 4),
              Text(
                item.serviceLabel,
                style: const TextStyle(
                  color: IzyTelColors.textSecondary,
                  fontSize: IzyTelTypeScale.micro,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: IzyTelColors.primarySoft.withAlpha(120),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Symbols.phone_iphone_rounded,
                    size: IzyTelIconSize.info,
                    color: IzyTelColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item.beneficiaryMasked,
                      style: const TextStyle(
                        fontSize: IzyTelTypeScale.label,
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formatCfa(item.amount),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: IzyTelColors.primaryStrong,
                        fontSize: IzyTelTypeScale.money,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.reference,
                    style: const TextStyle(
                      fontSize: IzyTelTypeScale.micro,
                      color: IzyTelColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Symbols.schedule_rounded,
                  size: 14,
                  color: IzyTelColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ageText,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: IzyTelTypeScale.micro,
                      color: IzyTelColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: canAccept ? () => _claim(item) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(child: Text('Acceptation en cours…')),
                      ],
                    )
                  : const Text('Accepter et traiter'),
            ),
            if (!item.canAccept)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Votre disponibilité, votre réseau ou votre capacité ne permet pas cette prise en charge.',
                  style: TextStyle(
                    fontSize: IzyTelTypeScale.micro,
                    color: IzyTelColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
