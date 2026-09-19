import 'dart:async';
import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/notifications/firebase_messaging_bootstrap.dart';
import 'package:cabine_flow/core/notifications/izytel_notification_device_registry.dart';
import 'package:cabine_flow/core/notifications/izytel_notification_payload.dart';
import 'package:cabine_flow/core/services/session_preferences.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_personal_profile_page.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/partners/data/repositories/supabase_partner_order_repository.dart';
import 'package:cabine_flow/features/partners/domain/models/partner_order_models.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

class PartnerShellPage extends StatefulWidget {
  const PartnerShellPage({
    super.key,
    required this.user,
    required this.authRepository,
    required this.repository,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final SupabasePartnerOrderRepository repository;

  @override
  State<PartnerShellPage> createState() => _PartnerShellPageState();
}

class _PartnerShellPageState extends State<PartnerShellPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  DateTime? _lastBackPressAt;
  bool _handlingBack = false;
  StreamSubscription<IzyTelNotificationPayload>? _notificationOpened;
  StreamSubscription<IzyTelNotificationPayload>? _notificationForeground;
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(
    4,
    (int index) => GlobalKey<NavigatorState>(
      debugLabel: 'cabiniste-tab-$index',
    ),
  );
  final ValueNotifier<int> _refreshOrders = ValueNotifier<int>(0);
  final ValueNotifier<int> _refreshProfile = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startNotifications());
    _notificationForeground = FirebaseMessagingBootstrap.foregroundPayloads
        .listen((IzyTelNotificationPayload payload) {
      if (!mounted) return;
      IzyTelFeedback.show(context, payload.displayMessage);
      if (payload.targetsOrder ||
          payload.type == 'order_assigned' ||
          payload.type == 'order_reassigned') {
        _refreshOrders.value++;
      }
    });
    _notificationOpened = FirebaseMessagingBootstrap.openedPayloads.listen(
      _handleNotificationOpen,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final IzyTelNotificationPayload? pending =
          FirebaseMessagingBootstrap.takePendingOpenedPayload();
      if (pending != null) _handleNotificationOpen(pending);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationOpened?.cancel();
    _notificationForeground?.cancel();
    _refreshOrders.dispose();
    _refreshProfile.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(IzyTelNotificationDeviceRegistry.refresh(user: widget.user));
    _refreshOrders.value++;
  }

  Future<void> _startNotifications() async {
    try {
      await IzyTelNotificationDeviceRegistry.start(user: widget.user);
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'PartnerShell.notification-registry',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleNotificationOpen(IzyTelNotificationPayload payload) {
    if (!mounted) return;
    if (payload.targetsOrder ||
        payload.type == 'order_assigned' ||
        payload.type == 'order_reassigned') {
      _selectTab(1);
      _refreshOrders.value++;
    }
  }

  void _selectTab(int index) {
    _lastBackPressAt = null;
    _navigatorKeys[index].currentState?.popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  Widget _tabNavigator(int index, Widget page) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => page,
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Tu devras te reconnecter pour accéder de nouveau à ton espace Cabiniste.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Symbols.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await IzyTelNotificationDeviceRegistry.deactivateCurrentDevice();
      await widget.authRepository.logout();
      await SessionPreferences.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> route) => false,
      );
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'PartnerShell.logout',
        error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      IzyTelFeedback.error(
        context,
        'Impossible de se déconnecter pour le moment.',
      );
    }
  }

  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final NavigatorState? current =
          _navigatorKeys[_selectedIndex].currentState;
      if (current != null && current.canPop()) {
        current.pop();
        _lastBackPressAt = null;
        return;
      }

      if (_selectedIndex != 0) {
        _selectTab(0);
        return;
      }

      final DateTime now = DateTime.now();
      if (_lastBackPressAt == null ||
          now.difference(_lastBackPressAt!) > const Duration(seconds: 2)) {
        _lastBackPressAt = now;
        if (mounted) {
          IzyTelFeedback.show(
            context,
            'Appuie encore une fois pour quitter IzyTel.',
          );
        }
        return;
      }

      await SystemNavigator.pop();
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _PartnerHomePage(
        user: widget.user,
        repository: widget.repository,
        onOpenOrders: () => _selectTab(1),
        onOpenHistory: () => _selectTab(2),
        onOpenProfile: () => _selectTab(3),
        refreshOrders: _refreshOrders,
        refreshProfile: _refreshProfile,
      ),
      _PartnerOrdersPage(
        user: widget.user,
        repository: widget.repository,
        refreshSignal: _refreshOrders,
        profileRefreshSignal: _refreshProfile,
        onOpenProfile: () => _selectTab(3),
        onLogout: _logout,
      ),
      _PartnerHistoryPage(
        repository: widget.repository,
        refreshSignal: _refreshOrders,
      ),
      _PartnerProfilePage(
        user: widget.user,
        repository: widget.repository,
        isLoggingOut: _isLoggingOut,
        onLogout: _logout,
        onProfileUpdated: () => _refreshProfile.value++,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: IzyTelColors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            pages.length,
            (int index) => _tabNavigator(index, pages[index]),
          ),
        ),
        bottomNavigationBar: _PartnerBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}

class _PartnerHomePage extends StatefulWidget {
  const _PartnerHomePage({
    required this.user,
    required this.repository,
    required this.onOpenOrders,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.refreshOrders,
    required this.refreshProfile,
  });

  final AppUser user;
  final SupabasePartnerOrderRepository repository;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  final ValueListenable<int> refreshOrders;
  final ValueListenable<int> refreshProfile;

  @override
  State<_PartnerHomePage> createState() => _PartnerHomePageState();
}

class _PartnerHomePageState extends State<_PartnerHomePage> {
  final SupabaseStaffProfileRepository _profileRepository =
      SupabaseStaffProfileRepository();
  Future<_PartnerHomeData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refreshOrders.addListener(_refresh);
    widget.refreshProfile.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.refreshOrders.removeListener(_refresh);
    widget.refreshProfile.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<_PartnerHomeData> _load() async {
    final PartnerAccountSnapshot? account = await widget.repository.fetchOwnAccount();
    final List<PartnerOrderSnapshot> orders =
        await widget.repository.fetchAssignedOrders();
    final PartnerFinanceSnapshot finance =
        await widget.repository.fetchFinanceSnapshot();
    StaffProfile? profile;
    String? avatarUrl;
    try {
      profile = await _profileRepository.fetchProfile(widget.user.id);
      avatarUrl = await _profileRepository.fetchAvatarUrl(
        widget.user.id,
        knownPath: profile?.avatarPath,
      );
    } catch (_) {
      profile = null;
      avatarUrl = null;
    }
    return _PartnerHomeData(
      account: account,
      orders: orders,
      finance: finance,
      profile: profile,
      avatarUrl: avatarUrl,
    );
  }

  void _openFinance() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _PartnerFinancePage(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_PartnerHomeData>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<_PartnerHomeData> snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData || snap.data!.account == null) {
              return _PartnerErrorState(onRetry: _refresh);
            }

            final _PartnerHomeData data = snap.data!;
            final PartnerAccountSnapshot account = data.account!;
            final String displayName = data.profile?.displayName.trim().isNotEmpty == true
                ? data.profile!.displayName
                : account.displayName;
            final String firstName = displayName.trim().isEmpty
                ? 'Cabiniste'
                : displayName.trim().split(RegExp(r'\s+')).first;
            final int toAccept = data.orders
                .where((PartnerOrderSnapshot order) => order.isAwaitingDecision)
                .length;
            final int inProgress = data.orders.where((PartnerOrderSnapshot order) {
              return order.isAccepted &&
                  (order.orderStatus == 'paidReady' ||
                      order.orderStatus == 'inProgress' ||
                      order.orderStatus == 'onHold');
            }).length;
            final int completed = data.orders
                .where((PartnerOrderSnapshot order) => order.isCompleted)
                .length;

            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  IzyTelSpacing.lg,
                  IzyTelSpacing.md,
                  IzyTelSpacing.lg,
                  IzyTelSpacing.xxl,
                ),
                children: <Widget>[
                  _PartnerAgentStyleHeader(
                    firstName: firstName,
                    displayName: displayName,
                    available: account.isAvailable,
                    avatarUrl: data.avatarUrl,
                    onAvatarTap: widget.onOpenProfile,
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  _PartnerPriorityActionCard(
                    toAccept: toAccept,
                    inProgress: inProgress,
                    onOpenOrders: widget.onOpenOrders,
                  ),
                  const SizedBox(height: IzyTelSpacing.lg),
                  _PartnerOperationalSummary(
                    toAccept: toAccept,
                    inProgress: inProgress,
                    completed: completed,
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const IzyTelSectionHeader(title: 'Mon suivi'),
                  const SizedBox(height: IzyTelSpacing.sm),
                  IzyTelSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IzyTelMenuRow(
                          icon: Symbols.account_balance_wallet_rounded,
                          title: 'Mes règlements',
                          subtitle: data.finance.balanceDue > 0
                              ? '${_formatMoney(data.finance.balanceDue)} à recevoir.'
                              : 'Consulter mes gains et les versements reçus.',
                          iconColor: IzyTelColors.success,
                          onTap: _openFinance,
                        ),
                        const Divider(height: 1),
                        IzyTelMenuRow(
                          icon: Symbols.history_rounded,
                          title: 'Mon historique',
                          subtitle: 'Commandes traitées, refusées et terminées.',
                          iconColor: IzyTelColors.primary,
                          onTap: widget.onOpenHistory,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  const IzyTelSectionHeader(title: 'Mes capacités'),
                  const SizedBox(height: IzyTelSpacing.sm),
                  IzyTelSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: <Widget>[
                        _PartnerCapacitySummaryRow(
                          network: 'orange',
                          capacity: account.orangeCapacity,
                        ),
                        const Divider(height: 1),
                        _PartnerCapacitySummaryRow(
                          network: 'mtn',
                          capacity: account.mtnCapacity,
                        ),
                        const Divider(height: 1),
                        _PartnerCapacitySummaryRow(
                          network: 'moov',
                          capacity: account.moovCapacity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenHistory,
                          icon: const Icon(Symbols.history_rounded),
                          label: const Text('Historique'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onOpenProfile,
                          icon: const Icon(Symbols.person_rounded),
                          label: const Text('Profil'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _PartnerOrdersTab { toAccept, inProgress, completed }

class _PartnerOrdersPage extends StatefulWidget {
  const _PartnerOrdersPage({
    required this.user,
    required this.repository,
    required this.refreshSignal,
    required this.profileRefreshSignal,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final AppUser user;
  final SupabasePartnerOrderRepository repository;
  final ValueListenable<int> refreshSignal;
  final ValueListenable<int> profileRefreshSignal;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onLogout;

  @override
  State<_PartnerOrdersPage> createState() => _PartnerOrdersPageState();
}

class _PartnerOrdersPageState extends State<_PartnerOrdersPage> {
  PartnerAccountSnapshot? _account;
  StaffProfile? _profile;
  String? _avatarUrl;
  Future<List<PartnerOrderSnapshot>>? _initialOrders;
  _PartnerOrdersTab _selectedTab = _PartnerOrdersTab.toAccept;
  final SupabaseStaffProfileRepository _profileRepository =
      SupabaseStaffProfileRepository();

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_reload);
    widget.profileRefreshSignal.addListener(_reloadProfile);
    unawaited(_loadAccount());
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_reload);
    widget.profileRefreshSignal.removeListener(_reloadProfile);
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final PartnerAccountSnapshot? account =
          await widget.repository.fetchOwnAccount();
      StaffProfile? profile;
      String? avatar;
      try {
        profile = await _profileRepository.fetchProfile(widget.user.id);
        avatar = await _profileRepository.fetchAvatarUrl(
          widget.user.id,
          knownPath: profile?.avatarPath,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _account = account;
        _profile = profile;
        _avatarUrl = avatar;
        _initialOrders = widget.repository.fetchAssignedOrders();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialOrders = widget.repository.fetchAssignedOrders();
      });
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _initialOrders = widget.repository.fetchAssignedOrders();
    });
  }

  void _reloadProfile() {
    if (!mounted) return;
    unawaited(_loadAccount());
  }

  void _openAccountMenu() {
    final String displayName = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : (_account?.displayName ?? widget.user.name);
    showIzyTelAccountSheet(
      context: context,
      name: displayName,
      role: 'Cabiniste • ${_account?.isAvailable == true ? 'Disponible' : 'Indisponible'}',
      actions: <IzyTelAccountAction>[
        IzyTelAccountAction(
          icon: Symbols.person_rounded,
          label: 'Mon profil',
          onTap: widget.onOpenProfile,
        ),
        IzyTelAccountAction(
          icon: Symbols.logout_rounded,
          label: 'Se déconnecter',
          destructive: true,
          onTap: () => widget.onLogout(),
        ),
      ],
      avatarImageUrl: _avatarUrl,
    );
  }

  Future<void> _acceptOrder(PartnerOrderSnapshot order) async {
    try {
      final PartnerOrderSnapshot accepted =
          await widget.repository.accept(order.orderId);
      PartnerOrderSnapshot treatmentOrder = accepted;
      bool started = false;
      try {
        treatmentOrder = await widget.repository.startProcessing(order.orderId);
        started = true;
      } catch (_) {
        // L'acceptation reste valide même si le démarrage doit être relancé
        // depuis le détail de la commande.
      }
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        started
            ? 'Commande ${order.orderReference} acceptée. Traitement démarré.'
            : 'Commande ${order.orderReference} acceptée.',
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PartnerOrderDetailPage(
            initialOrder: treatmentOrder,
            repository: widget.repository,
          ),
        ),
      );
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (mounted) IzyTelFeedback.error(context, _friendlyError(error));
    }
  }

  Future<void> _refuseOrder(PartnerOrderSnapshot order) async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartnerReasonSheet(
        title: 'Refuser la commande',
        subtitle:
            '${order.orderReference} sera renvoyée dans le circuit de réaffectation.',
        label: 'Motif du refus',
        hint: 'Ex. capacité insuffisante ou indisponibilité réseau…',
        confirmLabel: 'Confirmer le refus',
        confirmColor: IzyTelColors.error,
        maxLength: 500,
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await widget.repository.refuse(orderId: order.orderId, reason: reason);
      if (!mounted) return;
      IzyTelFeedback.show(
        context,
        'Commande ${order.orderReference} refusée et renvoyée pour réaffectation.',
      );
      _reload();
    } catch (error) {
      if (mounted) IzyTelFeedback.error(context, _friendlyError(error));
    }
  }

  Future<void> _openQueueModeMenu(Map<_PartnerOrdersTab, int> counts) async {
    final _PartnerOrdersTab? selected = await showModalBottomSheet<_PartnerOrdersTab>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: IzyTelColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: IzyTelColors.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              _queueChoice(sheetContext, _PartnerOrdersTab.toAccept,
                  Symbols.inbox_rounded, 'À accepter', counts[_PartnerOrdersTab.toAccept] ?? 0),
              _queueChoice(sheetContext, _PartnerOrdersTab.inProgress,
                  Symbols.autorenew_rounded, 'En cours', counts[_PartnerOrdersTab.inProgress] ?? 0),
              _queueChoice(sheetContext, _PartnerOrdersTab.completed,
                  Symbols.check_circle_rounded, 'Terminées', counts[_PartnerOrdersTab.completed] ?? 0),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selectedTab = selected);
  }

  Widget _queueChoice(
    BuildContext sheetContext,
    _PartnerOrdersTab tab,
    IconData icon,
    String label,
    int count,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text('$count'),
      onTap: () => Navigator.of(sheetContext).pop(tab),
    );
  }

  String _queueHeading(int count) {
    switch (_selectedTab) {
      case _PartnerOrdersTab.toAccept:
        return '$count commande${count > 1 ? 's' : ''} à traiter';
      case _PartnerOrdersTab.inProgress:
        return '$count commande${count > 1 ? 's' : ''} en cours';
      case _PartnerOrdersTab.completed:
        return '$count commande${count > 1 ? 's' : ''} terminée${count > 1 ? 's' : ''}';
    }
  }

  List<PartnerOrderSnapshot> _filterOrders(List<PartnerOrderSnapshot> orders) {
    return orders.where((PartnerOrderSnapshot order) {
      switch (_selectedTab) {
        case _PartnerOrdersTab.toAccept:
          return order.isAwaitingDecision;
        case _PartnerOrdersTab.inProgress:
          return order.isAccepted &&
              (order.orderStatus == 'paidReady' ||
                  order.isInProgress ||
                  order.isOnHold);
        case _PartnerOrdersTab.completed:
          return order.isCompleted;
      }
    }).toList(growable: false)
      ..sort((PartnerOrderSnapshot a, PartnerOrderSnapshot b) =>
          b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    Widget contentFor(List<PartnerOrderSnapshot> allOrders) {
      final Map<_PartnerOrdersTab, int> counts = <_PartnerOrdersTab, int>{
        _PartnerOrdersTab.toAccept:
            allOrders.where((PartnerOrderSnapshot o) => o.isAwaitingDecision).length,
        _PartnerOrdersTab.inProgress: allOrders.where((PartnerOrderSnapshot o) =>
            o.isAccepted && (o.orderStatus == 'paidReady' || o.isInProgress || o.isOnHold)).length,
        _PartnerOrdersTab.completed:
            allOrders.where((PartnerOrderSnapshot o) => o.isCompleted).length,
      };
      final List<PartnerOrderSnapshot> visible = _filterOrders(allOrders);
      final String displayName = _profile?.displayName.trim().isNotEmpty == true
          ? _profile!.displayName
          : (_account?.displayName ?? widget.user.name);
      final String firstName = displayName.trim().isEmpty
          ? 'Cabiniste'
          : displayName.trim().split(RegExp(r'\s+')).first;

      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: <Widget>[
            _PartnerAgentStyleHeader(
              firstName: firstName,
              displayName: displayName,
              available: _account?.isAvailable == true,
              avatarUrl: _avatarUrl,
              onAvatarTap: _openAccountMenu,
            ),
            const SizedBox(height: 32),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _queueHeading(visible.length),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: IzyTelTypeScale.title2,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.25,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Afficher une autre file',
                  onPressed: () => _openQueueModeMenu(counts),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Symbols.tune_rounded, size: IzyTelIconSize.action),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              _PartnerOrdersEmptyState(tab: _selectedTab)
            else
              ...List<Widget>.generate(visible.length, (int index) {
                final PartnerOrderSnapshot order = visible[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PartnerOrderCard(
                    order: order,
                    queuePosition: _selectedTab == _PartnerOrdersTab.toAccept
                        ? index + 1
                        : null,
                    onAccept: _selectedTab == _PartnerOrdersTab.toAccept
                        ? () => _acceptOrder(order)
                        : null,
                    onRefuse: _selectedTab == _PartnerOrdersTab.toAccept
                        ? () => _refuseOrder(order)
                        : null,
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => PartnerOrderDetailPage(
                            initialOrder: order,
                            repository: widget.repository,
                          ),
                        ),
                      );
                      _reload();
                    },
                  ),
                );
              }),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: _account == null
            ? FutureBuilder<List<PartnerOrderSnapshot>>(
                future: _initialOrders,
                builder: (BuildContext context,
                    AsyncSnapshot<List<PartnerOrderSnapshot>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return _PartnerErrorState(onRetry: _loadAccount);
                  return contentFor(snapshot.data ?? const <PartnerOrderSnapshot>[]);
                },
              )
            : StreamBuilder<List<PartnerOrderSnapshot>>(
                stream: widget.repository.watchAssignedOrders(partnerId: _account!.id),
                builder: (BuildContext context,
                    AsyncSnapshot<List<PartnerOrderSnapshot>> snapshot) {
                  if (snapshot.hasData) return contentFor(snapshot.data!);
                  return FutureBuilder<List<PartnerOrderSnapshot>>(
                    future: _initialOrders,
                    builder: (BuildContext context,
                        AsyncSnapshot<List<PartnerOrderSnapshot>> fallback) {
                      if (fallback.hasData) return contentFor(fallback.data!);
                      if (snapshot.hasError || fallback.hasError) {
                        return _PartnerErrorState(onRetry: _reload);
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _PartnerHistoryPage extends StatefulWidget {
  const _PartnerHistoryPage({
    required this.repository,
    required this.refreshSignal,
  });

  final SupabasePartnerOrderRepository repository;
  final ValueListenable<int> refreshSignal;

  @override
  State<_PartnerHistoryPage> createState() => _PartnerHistoryPageState();
}

class _PartnerHistoryPageState extends State<_PartnerHistoryPage> {
  Future<List<PartnerAssignmentHistoryItem>>? _future;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = widget.repository.fetchOwnAssignmentHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<PartnerAssignmentHistoryItem>>(
            future: _future,
            builder: (BuildContext context,
                AsyncSnapshot<List<PartnerAssignmentHistoryItem>> snapshot) {
              final List<PartnerAssignmentHistoryItem> items =
                  snapshot.data ?? const <PartnerAssignmentHistoryItem>[];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  IzyTelSpacing.lg,
                  IzyTelSpacing.md,
                  IzyTelSpacing.lg,
                  IzyTelSpacing.xxl,
                ),
                children: <Widget>[
                  IzyTelPageHeader(
                    title: 'Historique',
                    subtitle: 'Retrouve tes commandes et décisions passées.',
                    actions: <Widget>[
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: _reload,
                        icon: const Icon(Symbols.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: IzyTelSpacing.xl),
                  if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError && items.isEmpty)
                    _PartnerErrorState(onRetry: _reload)
                  else if (items.isEmpty)
                    const IzyTelSurface(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun historique Cabiniste pour le moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: IzyTelColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...items.map((PartnerAssignmentHistoryItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PartnerHistoryCard(item: item),
                    )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
class PartnerOrderDetailPage extends StatefulWidget {
  const PartnerOrderDetailPage({
    super.key,
    required this.initialOrder,
    required this.repository,
  });

  final PartnerOrderSnapshot initialOrder;
  final SupabasePartnerOrderRepository repository;

  @override
  State<PartnerOrderDetailPage> createState() => _PartnerOrderDetailPageState();
}

class _PartnerOrderDetailPageState extends State<PartnerOrderDetailPage> {
  final ImagePicker _picker = ImagePicker();
  late PartnerOrderSnapshot _order;
  Uint8List? _proofBytes;
  bool _proofReady = false;
  bool _isLoadingProof = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    unawaited(_loadProofState());
  }

  Future<void> _loadProofState() async {
    try {
      final Uint8List? bytes = await widget.repository.loadProofBytes(
        _order.orderId,
      );
      if (!mounted) return;
      setState(() {
        _proofBytes = bytes;
        _proofReady = bytes != null && bytes.isNotEmpty;
        _isLoadingProof = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProof = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (error) {
      IzyTelFeedback.error(context, message);
    } else {
      IzyTelFeedback.show(context, message);
    }
  }

  Future<void> _run(
    Future<PartnerOrderSnapshot> Function() action, {
    String successMessage = 'Commande mise à jour.',
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final PartnerOrderSnapshot updated = await action();
      if (!mounted) return;
      setState(() => _order = updated);
      IzyTelFeedback.success(context, successMessage);
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptAndStart() async {
    if (_busy) return;
    setState(() => _busy = true);
    PartnerOrderSnapshot? accepted;
    try {
      accepted = await widget.repository.accept(_order.orderId);
      PartnerOrderSnapshot updated = accepted;
      String message = 'Commande acceptée.';
      try {
        updated = await widget.repository.startProcessing(_order.orderId);
        message = 'Commande acceptée. Traitement démarré.';
      } catch (_) {
        message =
            'Commande acceptée. Tu peux démarrer le traitement depuis ce détail.';
      }
      if (!mounted) return;
      setState(() => _order = updated);
      IzyTelFeedback.success(context, message);
    } catch (error) {
      if (!mounted) return;
      if (accepted != null) {
        final PartnerOrderSnapshot acceptedOrder = accepted;
        setState(() => _order = acceptedOrder);
      }
      IzyTelFeedback.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refuse() async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartnerReasonSheet(
        title: 'Refuser la commande',
        subtitle:
            '${_order.orderReference} sera renvoyée dans le circuit de réaffectation.',
        label: 'Motif du refus',
        hint: 'Ex. réseau indisponible ou capacité insuffisante…',
        confirmLabel: 'Confirmer le refus',
        confirmColor: IzyTelColors.error,
        maxLength: 500,
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.refuse(orderId: _order.orderId, reason: reason);
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Commande refusée et renvoyée pour réaffectation.',
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _putOnHold() async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PartnerHoldReasonSheet(),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => widget.repository.hold(orderId: _order.orderId, reason: reason),
      successMessage: 'Commande mise en attente.',
    );
  }

  Future<void> _markFailed() async {
    final _PartnerFailureResult? result =
        await showModalBottomSheet<_PartnerFailureResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PartnerFailureSheet(),
    );
    if (result == null || !mounted) return;
    await _run(
      () => widget.repository.fail(
        orderId: _order.orderId,
        reason: result.reason,
        observation: result.observation,
      ),
      successMessage: 'Échec enregistré.',
    );
  }

  Future<void> _chooseProofSource() async {
    if (_busy || (!_order.isInProgress && !_order.isOnHold)) return;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PartnerProofSourceSheet(),
    );
    if (source == null || !mounted) return;
    await _captureProof(source);
  }

  Future<void> _captureProof(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final Uint8List bytes = await image.readAsBytes();
      await widget.repository.saveProof(
        orderId: _order.orderId,
        fileName: '${_order.orderReference}_preuve.jpg',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _proofReady = true;
        _proofBytes = bytes;
        _isLoadingProof = false;
      });
      IzyTelFeedback.success(
        context,
        source == ImageSource.camera
            ? 'Photo prise et preuve enregistrée.'
            : 'Preuve enregistrée.',
      );
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSuccess() async {
    if (!_proofReady) {
      _showMessage(
        'Ajoute d’abord une preuve du transfert.',
        error: false,
      );
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirmer la réussite'),
        content: Text(
          'La commande ${_order.orderReference} sera marquée comme réussie.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: IzyTelColors.success,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finalize();
  }

  Future<void> _finalize() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final PartnerFinalizationResult result =
          await widget.repository.finalizeSuccess(_order.orderId);
      final List<PartnerOrderSnapshot> orders =
          await widget.repository.fetchAssignedOrders();
      PartnerOrderSnapshot? refreshed;
      for (final PartnerOrderSnapshot item in orders) {
        if (item.orderId == _order.orderId) {
          refreshed = item;
          break;
        }
      }
      if (!mounted) return;
      if (refreshed != null) {
        final PartnerOrderSnapshot refreshedOrder = refreshed;
        setState(() => _order = refreshedOrder);
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Commande terminée'),
          content: Text(
            'Règlement Cabiniste : ${_formatMoney(result.cabinisteSettlementAmount)}\n'
            'Marge Cabiniste : ${_formatMoney(result.cabinisteMarginAmount)}',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showInfoSheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(
          color: IzyTelColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: IzyTelColors.outlineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  int _activityCount(PartnerOrderSnapshot order) {
    int count = 1;
    if (order.paymentConfirmedAt != null || order.paidAt != null) count++;
    if (order.assignedAt != null) count++;
    if (order.processingStartedAt != null) count++;
    if (order.lastHeldAt != null) count++;
    if (order.lastResumedAt != null) count++;
    if (order.completedAt != null) count++;
    return count;
  }

  Widget? _buildBottomActions(PartnerOrderSnapshot order) {
    if (order.isAwaitingDecision) {
      return _PartnerSingleBottomAction(
        isBusy: _busy,
        label: 'Accepter',
        icon: Symbols.check_rounded,
        onPressed: _acceptAndStart,
      );
    }
    if (order.isAccepted && order.orderStatus == 'paidReady') {
      return _PartnerSingleBottomAction(
        isBusy: _busy,
        label: 'Démarrer le traitement',
        icon: Symbols.play_arrow_rounded,
        onPressed: () => _run(
          () => widget.repository.startProcessing(order.orderId),
          successMessage: 'Traitement démarré.',
        ),
      );
    }
    if (order.isOnHold) {
      return _PartnerSingleBottomAction(
        isBusy: _busy,
        label: 'Reprendre le traitement',
        icon: Symbols.play_arrow_rounded,
        onPressed: () => _run(
          () => widget.repository.resume(order.orderId),
          successMessage: 'Traitement repris.',
        ),
      );
    }
    if (order.isInProgress) {
      return _PartnerProcessingBottomActions(
        isBusy: _busy,
        onHold: _putOnHold,
        onSuccess: _confirmSuccess,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final PartnerOrderSnapshot order = _order;
    final Widget? bottomActions = _buildBottomActions(order);
    final double referenceScale =
        (MediaQuery.sizeOf(context).width / 290).clamp(.95, 1.35);

    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _PartnerReferenceDetailTopBar(
              order: order,
              onBack: () => Navigator.of(context).pop(),
              onMenuSelected: (String value) {
                if (value == 'refuse') {
                  unawaited(_refuse());
                } else if (value == 'failure') {
                  unawaited(_markFailed());
                }
              },
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  12 * referenceScale,
                  13 * referenceScale,
                  12 * referenceScale,
                  bottomActions == null ? 24 : 106,
                ),
                children: <Widget>[
                  _PartnerReferenceOrderSummary(order: order),
                  SizedBox(height: 18 * referenceScale),
                  _PartnerReferenceProgress(order: order),
                  SizedBox(height: 18 * referenceScale),
                  _PartnerDetailMenuCard(
                    rows: <_PartnerDetailMenuRowData>[
                      _PartnerDetailMenuRowData(
                        icon: Symbols.person_rounded,
                        label: 'Client',
                        onTap: () => _showInfoSheet(
                          title: 'Client',
                          child: _PartnerInfoSheetRows(
                            rows: <MapEntry<String, String>>[
                              MapEntry('Nom', order.clientName),
                              MapEntry(
                                'WhatsApp',
                                _partnerFormatPhone(order.clientWhatsappPhone),
                              ),
                              MapEntry(
                                'Bénéficiaire',
                                _partnerFormatPhone(order.beneficiaryPhone),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _PartnerDetailMenuRowData(
                        icon: Symbols.wallet_rounded,
                        label: 'Paiement',
                        trailing: order.isFundedForProcessing
                            ? _PartnerTinyStateBadge(
                                label: order.paymentStatus == 'credit'
                                    ? 'Crédit'
                                    : 'Confirmé',
                                color: order.paymentStatus == 'credit'
                                    ? IzyTelColors.warning
                                    : IzyTelColors.success,
                              )
                            : null,
                        onTap: () => _showInfoSheet(
                          title: 'Paiement',
                          child: _PartnerInfoSheetRows(
                            rows: <MapEntry<String, String>>[
                              MapEntry('Montant', _formatMoney(order.amount)),
                              MapEntry(
                                'Payeur',
                                order.paymentPayerName ?? order.clientName,
                              ),
                              MapEntry(
                                'Référence',
                                order.paymentReference ?? 'Non renseignée',
                              ),
                              MapEntry(
                                'Statut',
                                _partnerPaymentStatusLabel(order.paymentStatus),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _PartnerDetailMenuRowData(
                        icon: Symbols.format_list_bulleted_rounded,
                        label: 'Détails de l’offre',
                        onTap: () => _showInfoSheet(
                          title: 'Détails de l’offre',
                          child: _PartnerInfoSheetRows(
                            rows: <MapEntry<String, String>>[
                              MapEntry('Réseau', _networkLabel(order.network)),
                              MapEntry(
                                'Opération',
                                _partnerOperationLabel(order.operationType),
                              ),
                              MapEntry(
                                'Offre',
                                order.offerLabel.isEmpty
                                    ? 'Non renseignée'
                                    : order.offerLabel,
                              ),
                              MapEntry('Montant', _formatMoney(order.amount)),
                              MapEntry(
                                'Bénéficiaire',
                                _partnerFormatPhone(order.beneficiaryPhone),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _PartnerDetailMenuRowData(
                        icon: Symbols.image_rounded,
                        label: 'Preuve',
                        trailing: _PartnerProofThumbnail(
                          bytes: _proofBytes,
                          isLoading: _isLoadingProof,
                        ),
                        onTap: (order.isInProgress || order.isOnHold)
                            ? _chooseProofSource
                            : () {
                                if (_proofBytes == null) {
                                  _showMessage('Aucune preuve enregistrée.');
                                  return;
                                }
                                _showInfoSheet(
                                  title: 'Preuve de transfert',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      _proofBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              },
                      ),
                      if (order.isFailed)
                        _PartnerDetailMenuRowData(
                          icon: Symbols.error_rounded,
                          label: 'Échec du traitement',
                          trailing: const _PartnerTinyStateBadge(
                            label: 'À analyser',
                            color: IzyTelColors.error,
                          ),
                          onTap: () => _showInfoSheet(
                            title: 'Détails de l’échec',
                            child: _PartnerInfoSheetRows(
                              rows: <MapEntry<String, String>>[
                                MapEntry(
                                  'Motif',
                                  _partnerFailureReasonLabel(
                                    order.failureReason,
                                  ),
                                ),
                                MapEntry(
                                  'Observation',
                                  order.observation?.trim().isNotEmpty == true
                                      ? order.observation!.trim()
                                      : 'Aucune observation',
                                ),
                                MapEntry(
                                  'Date',
                                  _partnerDateTimeLabel(order.completedAt),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _PartnerDetailMenuRowData(
                        icon: Symbols.history_rounded,
                        label: 'Journal d’activité',
                        trailing: _PartnerCountBadge(
                          value: _activityCount(order),
                        ),
                        onTap: () => _showInfoSheet(
                          title: 'Journal d’activité',
                          child: _PartnerActivitySheet(order: order),
                        ),
                      ),
                      _PartnerDetailMenuRowData(
                        icon: Symbols.chat_bubble_rounded,
                        label: 'Demande client',
                        onTap: () => _showInfoSheet(
                          title: 'Demande client',
                          child: Text(
                            'Les demandes client sont traitées par le Manager depuis le centre de support IzyTel.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      _PartnerDetailMenuRowData(
                        icon: Symbols.payments_rounded,
                        label: 'Remboursement',
                        onTap: () => _showInfoSheet(
                          title: 'Remboursement',
                          child: Text(
                            'En cas d’échec, l’analyse et la décision de remboursement ou de réaffectation appartiennent au Manager.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            ?bottomActions,
          ],
        ),
      ),
    );
  }
}

class _PartnerReferenceDetailTopBar extends StatelessWidget {
  const _PartnerReferenceDetailTopBar({
    required this.order,
    required this.onBack,
    required this.onMenuSelected,
  });

  final PartnerOrderSnapshot order;
  final VoidCallback onBack;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final List<PopupMenuEntry<String>> actions = <PopupMenuEntry<String>>[];
    if (order.isAwaitingDecision) {
      actions.add(
        const PopupMenuItem<String>(
          value: 'refuse',
          child: Text('Refuser la commande'),
        ),
      );
    }
    if (order.isInProgress) {
      actions.add(
        const PopupMenuItem<String>(
          value: 'failure',
          child: Text('Signaler un échec'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 6, 7, 6),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(bottom: BorderSide(color: IzyTelColors.outline)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Symbols.arrow_back_rounded,
              size: IzyTelIconSize.action,
            ),
          ),
          Expanded(
            child: Text(
              'Détail commande',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: IzyTelTypeScale.cardTitle,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<String>(
              key: const ValueKey<String>('cabiniste-order-detail-actions'),
              tooltip: 'Actions de la commande',
              onSelected: onMenuSelected,
              itemBuilder: (_) => actions,
              icon: const Icon(
                Symbols.more_vert_rounded,
                size: IzyTelIconSize.action,
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _PartnerReferenceOrderSummary extends StatelessWidget {
  const _PartnerReferenceOrderSummary({required this.order});

  final PartnerOrderSnapshot order;

  @override
  Widget build(BuildContext context) {
    final Color accent = _networkColor(order.network);
    final Color statusColor = _statusColor(order);
    final double scale =
        (MediaQuery.sizeOf(context).width / 290).clamp(.95, 1.35);
    return SizedBox(
      height: 132 * scale,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          14 * scale,
          12 * scale,
          12 * scale,
        ),
        decoration: BoxDecoration(
          color: IzyTelColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IzyTelColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 27 * scale,
                  height: 27 * scale,
                  padding: EdgeInsets.all(2.5 * scale),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(7 * scale),
                  ),
                  child: Image.asset(
                    _partnerNetworkAsset(order.network),
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    _networkLabel(order.network),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _PartnerTinyStateBadge(
                  label: _statusLabel(order),
                  color: statusColor,
                ),
              ],
            ),
            Text(
              order.offerLabel.isEmpty
                  ? _partnerOperationLabel(order.operationType)
                  : order.offerLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: IzyTelTypeScale.title3,
                    height: 1.22,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _partnerFormatPhone(order.beneficiaryPhone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.title3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .15,
                        ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Text(
                  _formatMoney(order.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IzyTelColors.primaryStrong,
                        fontSize: IzyTelTypeScale.title2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                order.orderReference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: IzyTelColors.textMuted,
                      fontSize: IzyTelTypeScale.micro,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PartnerReferenceStepState { done, active, pending }

class _PartnerReferenceProgress extends StatelessWidget {
  const _PartnerReferenceProgress({required this.order});
  final PartnerOrderSnapshot order;

  bool get _isAssigned =>
      order.assignedAt != null ||
      order.isAwaitingDecision ||
      order.isAccepted ||
      _isProcessing ||
      _isFinished;

  bool get _isProcessing => order.isInProgress || order.isOnHold || _isFinished;
  bool get _isFinished => order.isCompleted || order.isFailed;

  _PartnerReferenceStepState _state(int index) {
    if (index == 0) {
      return order.isFundedForProcessing
          ? _PartnerReferenceStepState.done
          : _PartnerReferenceStepState.active;
    }
    if (index == 1) {
      return _isAssigned
          ? _PartnerReferenceStepState.done
          : _PartnerReferenceStepState.pending;
    }
    if (index == 2) {
      if (_isFinished) return _PartnerReferenceStepState.done;
      if (_isProcessing) return _PartnerReferenceStepState.active;
      return _PartnerReferenceStepState.pending;
    }
    return _isFinished
        ? _PartnerReferenceStepState.done
        : _PartnerReferenceStepState.pending;
  }

  String _dateLabel(int index) {
    final DateTime? date = switch (index) {
      0 => order.paymentConfirmedAt ?? order.paidAt,
      1 => order.assignedAt,
      2 => order.lastResumedAt ?? order.processingStartedAt,
      _ => order.completedAt,
    };
    if (date == null) return '';
    final DateTime local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} · ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Payée',
      'Affectée',
      'En traitement',
      'Terminée',
    ];
    final double scale =
        (MediaQuery.sizeOf(context).width / 290).clamp(.95, 1.35);
    return SizedBox(
      height: 54 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(labels.length, (int index) {
            return Expanded(
              child: _PartnerReferenceProgressStep(
                label: labels[index],
                date: _dateLabel(index),
                state: _state(index),
                showLeftLine: index > 0,
                showRightLine: index < labels.length - 1,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PartnerReferenceProgressStep extends StatelessWidget {
  const _PartnerReferenceProgressStep({
    required this.label,
    required this.date,
    required this.state,
    required this.showLeftLine,
    required this.showRightLine,
  });

  final String label;
  final String date;
  final _PartnerReferenceStepState state;
  final bool showLeftLine;
  final bool showRightLine;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      _PartnerReferenceStepState.done => IzyTelColors.success,
      _PartnerReferenceStepState.active => IzyTelColors.primary,
      _PartnerReferenceStepState.pending => IzyTelColors.outlineStrong,
    };
    return Column(
      children: <Widget>[
        SizedBox(
          height: 31,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (showLeftLine)
                Positioned(
                  left: 0,
                  right: 15,
                  child: Container(
                    height: 1.5,
                    color: state == _PartnerReferenceStepState.pending
                        ? IzyTelColors.outline
                        : color.withAlpha(140),
                  ),
                ),
              if (showRightLine)
                Positioned(
                  left: 15,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    color: state == _PartnerReferenceStepState.done
                        ? IzyTelColors.success.withAlpha(140)
                        : IzyTelColors.outline,
                  ),
                ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == _PartnerReferenceStepState.pending
                      ? Colors.white
                      : color,
                  shape: BoxShape.circle,
                  border: state == _PartnerReferenceStepState.pending
                      ? Border.all(color: IzyTelColors.outlineStrong)
                      : null,
                ),
                child: Icon(
                  state == _PartnerReferenceStepState.done
                      ? Symbols.check_rounded
                      : state == _PartnerReferenceStepState.active
                          ? Symbols.hourglass_top_rounded
                          : Symbols.person_rounded,
                  size: IzyTelIconSize.info,
                  color: state == _PartnerReferenceStepState.pending
                      ? IzyTelColors.textMuted
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: state == _PartnerReferenceStepState.pending
                      ? IzyTelColors.textSecondary
                      : IzyTelColors.textPrimary,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: state == _PartnerReferenceStepState.active
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            date,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: IzyTelColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ),
      ],
    );
  }
}

class _PartnerDetailMenuRowData {
  const _PartnerDetailMenuRowData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
}

class _PartnerDetailMenuCard extends StatelessWidget {
  const _PartnerDetailMenuCard({required this.rows});
  final List<_PartnerDetailMenuRowData> rows;

  @override
  Widget build(BuildContext context) {
    final double scale =
        (MediaQuery.sizeOf(context).width / 290).clamp(.95, 1.35);
    final double rowHeight = 41 * scale;
    return Container(
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        children: List<Widget>.generate(rows.length, (int index) {
          final _PartnerDetailMenuRowData row = rows[index];
          return Column(
            children: <Widget>[
              SizedBox(
                height: rowHeight,
                child: InkWell(
                  onTap: row.onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          row.icon,
                          size: IzyTelIconSize.action,
                          color: IzyTelColors.textPrimary,
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: Text(
                            row.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: IzyTelColors.textPrimary,
                                  fontSize: IzyTelTypeScale.text,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        if (row.trailing != null) ...<Widget>[
                          row.trailing!,
                          SizedBox(width: 5 * scale),
                        ],
                        const Icon(
                          Symbols.chevron_right_rounded,
                          size: IzyTelIconSize.info,
                          color: IzyTelColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index < rows.length - 1)
                Divider(indent: 12 * scale, endIndent: 12 * scale),
            ],
          );
        }),
      ),
    );
  }
}

class _PartnerTinyStateBadge extends StatelessWidget {
  const _PartnerTinyStateBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PartnerCountBadge extends StatelessWidget {
  const _PartnerCountBadge({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: IzyTelColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: IzyTelColors.primary,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PartnerProofThumbnail extends StatelessWidget {
  const _PartnerProofThumbnail({required this.bytes, required this.isLoading});
  final Uint8List? bytes;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: 28,
        child: Padding(
          padding: EdgeInsets.all(7),
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.memory(bytes!, width: 34, height: 28, fit: BoxFit.cover),
    );
  }
}

class _PartnerInfoSheetRows extends StatelessWidget {
  const _PartnerInfoSheetRows({required this.rows});
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (MapEntry<String, String> row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 105,
                    child: Text(
                      row.key,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: IzyTelTypeScale.text,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PartnerActivitySheet extends StatelessWidget {
  const _PartnerActivitySheet({required this.order});
  final PartnerOrderSnapshot order;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, DateTime?>> entries =
        <MapEntry<String, DateTime?>>[
      MapEntry('Commande reçue', order.firebaseCreatedAt),
      MapEntry('Paiement confirmé', order.paymentConfirmedAt ?? order.paidAt),
      MapEntry('Commande affectée', order.assignedAt),
      MapEntry('Traitement démarré', order.processingStartedAt),
      MapEntry('Commande mise en attente', order.lastHeldAt),
      MapEntry('Traitement repris', order.lastResumedAt),
      MapEntry('Traitement terminé', order.completedAt),
    ];
    return Column(
      children: entries
          .where((MapEntry<String, DateTime?> entry) => entry.value != null)
          .map((MapEntry<String, DateTime?> entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            children: <Widget>[
              const Icon(
                Symbols.check_circle_rounded,
                size: 17,
                color: IzyTelColors.success,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: IzyTelTypeScale.label,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                _partnerDateTimeLabel(entry.value),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: IzyTelTypeScale.micro,
                    ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _PartnerSingleBottomAction extends StatelessWidget {
  const _PartnerSingleBottomAction({
    required this.isBusy,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final bool isBusy;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(top: BorderSide(color: IzyTelColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onPressed,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 16),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class _PartnerProcessingBottomActions extends StatelessWidget {
  const _PartnerProcessingBottomActions({
    required this.isBusy,
    required this.onHold,
    required this.onSuccess,
  });
  final bool isBusy;
  final VoidCallback onHold;
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(top: BorderSide(color: IzyTelColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: isBusy ? null : onHold,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Symbols.pause_rounded, size: IzyTelIconSize.info),
                      SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Mettre en attente',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: IzyTelTypeScale.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isBusy ? null : onSuccess,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (isBusy)
                        const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Symbols.check_circle_rounded,
                          size: IzyTelIconSize.info,
                        ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Marquer comme réussie',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: IzyTelTypeScale.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerSheetFrame extends StatelessWidget {
  const _PartnerSheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PartnerSheetHeader extends StatelessWidget {
  const _PartnerSheetHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: IzyTelColors.outlineStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PartnerReasonSheet extends StatefulWidget {
  const _PartnerReasonSheet({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.confirmColor,
    required this.maxLength,
  });
  final String title;
  final String subtitle;
  final String label;
  final String hint;
  final String confirmLabel;
  final Color confirmColor;
  final int maxLength;

  @override
  State<_PartnerReasonSheet> createState() => _PartnerReasonSheetState();
}

class _PartnerReasonSheetState extends State<_PartnerReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < 3) {
      setState(() => _error = 'Indique un motif avant de continuer.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return _PartnerSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PartnerSheetHeader(title: widget.title),
          const SizedBox(height: 5),
          Text(
            widget.subtitle,
            style: const TextStyle(color: IzyTelColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            maxLength: widget.maxLength,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: widget.confirmColor,
              ),
              child: Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerHoldReasonSheet extends StatefulWidget {
  const _PartnerHoldReasonSheet();

  @override
  State<_PartnerHoldReasonSheet> createState() =>
      _PartnerHoldReasonSheetState();
}

class _PartnerHoldReasonSheetState extends State<_PartnerHoldReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  static const List<String> suggestions = <String>[
    'Réseau momentanément indisponible',
    'Solde ou capacité à vérifier',
    'Problème technique temporaire',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < 3) {
      setState(
        () => _error = 'Indique pourquoi la commande est mise en attente.',
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return _PartnerSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PartnerSheetHeader(title: 'Mettre en attente'),
          const SizedBox(height: 5),
          const Text(
            'Choisis un motif rapide ou saisis le tien.',
            style: TextStyle(color: IzyTelColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: suggestions.map((String suggestion) {
              return ActionChip(
                backgroundColor: IzyTelColors.surface,
                side: const BorderSide(color: IzyTelColors.outline),
                label: Text(suggestion),
                onPressed: () {
                  _controller.text = suggestion;
                  setState(() => _error = null);
                },
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Motif',
              hintText: 'Ex. le réseau revient dans quelques minutes…',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: IzyTelColors.warningSoft,
                foregroundColor: IzyTelColors.textPrimary,
              ),
              child: const Text('Mettre en attente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerFailureResult {
  const _PartnerFailureResult({required this.reason, this.observation});
  final String reason;
  final String? observation;
}

class _PartnerFailureSheet extends StatefulWidget {
  const _PartnerFailureSheet();

  @override
  State<_PartnerFailureSheet> createState() => _PartnerFailureSheetState();
}

class _PartnerFailureSheetState extends State<_PartnerFailureSheet> {
  final TextEditingController _observationController = TextEditingController();
  String? _selectedReason;
  static const Map<String, String> reasons = <String, String>{
    'incorrectNumber': 'Numéro incorrect',
    'networkUnavailable': 'Réseau indisponible',
    'offerUnavailable': 'Offre indisponible',
    'insufficientBalance': 'Solde insuffisant',
    'technicalError': 'Erreur technique',
    'incorrectPayment': 'Paiement incorrect',
    'other': 'Autre motif',
  };

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  void _submit() {
    final String? reason = _selectedReason;
    if (reason == null) return;
    final String observation = _observationController.text.trim();
    Navigator.of(context).pop(
      _PartnerFailureResult(
        reason: reason,
        observation: observation.isEmpty ? null : observation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PartnerSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PartnerSheetHeader(title: 'Signaler un échec'),
          const SizedBox(height: 5),
          const Text(
            'Choisis la cause principale. Le Manager analysera ensuite la commande.',
            style: TextStyle(color: IzyTelColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: reasons.entries.map((MapEntry<String, String> entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: _selectedReason == entry.key,
                onSelected: (_) => setState(() => _selectedReason = entry.key),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _observationController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Observation (facultatif)',
              hintText: 'Ajoute un détail utile au Manager…',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedReason == null ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: IzyTelColors.error,
              ),
              child: const Text('Enregistrer l’échec'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerProofSourceSheet extends StatelessWidget {
  const _PartnerProofSourceSheet();

  @override
  Widget build(BuildContext context) {
    return _PartnerSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PartnerSheetHeader(title: 'Ajouter une preuve'),
          const SizedBox(height: 5),
          const Text(
            'Choisis une photo existante ou prends-en une maintenant.',
            style: TextStyle(color: IzyTelColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Symbols.photo_camera_rounded),
            title: const Text('Appareil photo'),
            subtitle: const Text('Prendre une photo en temps réel'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Symbols.photo_library_rounded),
            title: const Text('Galerie'),
            subtitle: const Text('Choisir une capture déjà enregistrée'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

String _partnerNetworkAsset(String network) {
  return switch (network.trim().toLowerCase()) {
    'orange' => 'assets/brands/operators/orange_ci.png',
    'mtn' => 'assets/brands/operators/mtn_ci.png',
    _ => 'assets/brands/operators/moov_africa_ci.png',
  };
}

String _partnerFormatPhone(String value) {
  final String digits = value.replaceAll(RegExp(r'\D'), '');
  String local = digits;
  if (local.startsWith('225') && local.length > 10) {
    local = local.substring(3);
  }
  if (local.length == 10) {
    return '${local.substring(0, 2)} ${local.substring(2, 4)} '
        '${local.substring(4, 6)} ${local.substring(6, 8)} '
        '${local.substring(8, 10)}';
  }
  return value.trim().isEmpty ? 'Non renseigné' : value.trim();
}

String _partnerPaymentStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'confirmed' => 'Confirmé',
    'credit' => 'Crédit autorisé',
    'pending' => 'En attente',
    'declared' => 'Déclaré',
    'rejected' => 'Rejeté',
    'expired' => 'Expiré',
    _ => status.trim().isEmpty ? 'Non renseigné' : status,
  };
}

String _partnerOperationLabel(String operationType) {
  return switch (operationType.trim()) {
    'internetSubscription' => 'Souscription Internet',
    'unitTransfer' => 'Transfert d’unités',
    'callBundle' => 'Forfait d’appels',
    'mixedBundle' => 'Forfait mixte',
    'other' => 'Autre service',
    _ => operationType.trim().isEmpty ? 'Autre service' : operationType,
  };
}

String _partnerFailureReasonLabel(String? reason) {
  return switch (reason) {
    'incorrectNumber' => 'Numéro incorrect',
    'networkUnavailable' => 'Réseau indisponible',
    'offerUnavailable' => 'Offre indisponible',
    'insufficientBalance' => 'Solde insuffisant',
    'technicalError' => 'Erreur technique',
    'incorrectPayment' => 'Paiement incorrect',
    'other' => 'Autre motif',
    _ => 'Non renseigné',
  };
}

String _partnerDateTimeLabel(DateTime? value) {
  if (value == null) return 'Non renseignée';
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _PartnerFinancePage extends StatefulWidget {
  const _PartnerFinancePage({required this.repository});

  final SupabasePartnerOrderRepository repository;

  @override
  State<_PartnerFinancePage> createState() => _PartnerFinancePageState();
}

class _PartnerFinancePageState extends State<_PartnerFinancePage> {
  Future<PartnerFinanceSnapshot>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchFinanceSnapshot();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.fetchFinanceSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text('Mes gains'),
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _reload,
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<PartnerFinanceSnapshot>(
        future: _future,
        builder: (BuildContext context,
            AsyncSnapshot<PartnerFinanceSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _PartnerErrorState(onRetry: _reload);
          }
          final PartnerFinanceSnapshot finance = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                IzyTelSpacing.lg,
                IzyTelSpacing.md,
                IzyTelSpacing.lg,
                IzyTelSpacing.xxl,
              ),
              children: <Widget>[
                IzyTelSurface(
                  backgroundColor: IzyTelColors.primary,
                  borderColor: IzyTelColors.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'À recevoir',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMoney(finance.balanceDue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _FinanceMiniStat(
                              label: 'Acquis',
                              value: _formatMoney(finance.earnedTotal),
                            ),
                          ),
                          Expanded(
                            child: _FinanceMiniStat(
                              label: 'Payé',
                              value: _formatMoney(finance.paidTotal),
                            ),
                          ),
                          Expanded(
                            child: _FinanceMiniStat(
                              label: 'Transactions',
                              value: '${finance.earnedTransactions}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.xl),
                const IzyTelSectionHeader(title: 'Historique des règlements'),
                const SizedBox(height: IzyTelSpacing.sm),
                if (finance.payouts.isEmpty)
                  const IzyTelSurface(
                    child: Text(
                      'Aucun règlement enregistré pour le moment.',
                      style: TextStyle(color: IzyTelColors.textSecondary),
                    ),
                  )
                else
                  ...finance.payouts.map(
                    (PartnerFinancePayout payout) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: IzyTelSurface(
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Symbols.payments_rounded,
                              color: IzyTelColors.success,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _formatMoney(payout.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: IzyTelColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${payout.channel.toUpperCase()} · ${payout.reference}',
                                    style: const TextStyle(
                                      color: IzyTelColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _shortDate(payout.paidAt),
                              style: const TextStyle(
                                color: IzyTelColors.textMuted,
                                fontSize: 11,
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

class _PartnerProfilePage extends StatefulWidget {
  const _PartnerProfilePage({
    required this.user,
    required this.repository,
    required this.isLoggingOut,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final AppUser user;
  final SupabasePartnerOrderRepository repository;
  final bool isLoggingOut;
  final Future<void> Function() onLogout;
  final VoidCallback onProfileUpdated;

  @override
  State<_PartnerProfilePage> createState() => _PartnerProfilePageState();
}

class _PartnerProfilePageState extends State<_PartnerProfilePage> {
  final SupabaseStaffProfileRepository _profileRepository =
      SupabaseStaffProfileRepository();
  PartnerAccountSnapshot? _account;
  StaffProfile? _profile;
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final PartnerAccountSnapshot? account =
          await widget.repository.fetchOwnAccount();
      StaffProfile? profile;
      String? avatar;
      try {
        profile = await _profileRepository.fetchProfile(widget.user.id);
        avatar = await _profileRepository.fetchAvatarUrl(
          widget.user.id,
          knownPath: profile?.avatarPath,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _account = account;
        _profile = profile;
        _avatarUrl = avatar;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _saveOperations({
    bool? available,
    String? toggledNetwork,
    bool? networkEnabled,
    String? capacityNetwork,
    int? capacity,
  }) async {
    final PartnerAccountSnapshot? account = _account;
    if (_saving || account == null) return false;
    final Set<String> active = account.activeNetworks.toSet();
    if (toggledNetwork != null && networkEnabled != null) {
      if (networkEnabled) {
        active.add(toggledNetwork);
      } else {
        active.remove(toggledNetwork);
      }
    }
    int orange = account.orangeCapacity;
    int mtn = account.mtnCapacity;
    int moov = account.moovCapacity;
    if (capacityNetwork == 'orange' && capacity != null) orange = capacity;
    if (capacityNetwork == 'mtn' && capacity != null) mtn = capacity;
    if (capacityNetwork == 'moov' && capacity != null) moov = capacity;

    setState(() => _saving = true);
    try {
      await widget.repository.updateOwnOperations(
        available: available ?? account.isAvailable,
        activeNetworks: active.toList(growable: false),
        orangeCapacity: orange,
        mtnCapacity: mtn,
        moovCapacity: moov,
      );
      await _load();
      if (!mounted) return true;
      IzyTelFeedback.success(context, 'Réglages Cabiniste mis à jour.');
      return true;
    } catch (error) {
      if (mounted) IzyTelFeedback.error(context, _friendlyError(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCapacity(String network) async {
    final PartnerAccountSnapshot? account = _account;
    if (account == null) return;
    final int? amount = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartnerCapacityEditorSheet(
        network: network,
        initialAmount: account.capacityFor(network),
      ),
    );
    if (amount == null || !mounted) return;
    await _saveOperations(capacityNetwork: network, capacity: amount);
  }

  Future<void> _openPersonalProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentPersonalProfilePage(
          user: widget.user,
          roleLabel: 'Cabiniste',
        ),
      ),
    );
    if (mounted) {
      await _load();
      widget.onProfileUpdated();
    }
  }

  void _openFinance() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _PartnerFinancePage(repository: widget.repository),
      ),
    );
  }

  void _openAccountMenu(PartnerAccountSnapshot account) {
    final String displayName = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : account.displayName;
    showIzyTelAccountSheet(
      context: context,
      name: displayName,
      role: 'Cabiniste • ${account.isAvailable ? 'Disponible' : 'Indisponible'}',
      actions: <IzyTelAccountAction>[
        IzyTelAccountAction(
          icon: Symbols.manage_accounts_rounded,
          label: 'Modifier mon profil',
          onTap: _openPersonalProfile,
        ),
        IzyTelAccountAction(
          icon: Symbols.account_balance_wallet_rounded,
          label: 'Mes règlements',
          onTap: _openFinance,
        ),
        IzyTelAccountAction(
          icon: Symbols.logout_rounded,
          label: 'Se déconnecter',
          destructive: true,
          onTap: () => widget.onLogout(),
        ),
      ],
      avatarImageUrl: _avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: IzyTelColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_account == null) {
      return Scaffold(
        backgroundColor: IzyTelColors.background,
        body: SafeArea(child: _PartnerErrorState(onRetry: _load)),
      );
    }

    final PartnerAccountSnapshot account = _account!;
    final String displayName = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : account.displayName;
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              IzyTelSpacing.lg,
              IzyTelSpacing.md,
              IzyTelSpacing.lg,
              IzyTelSpacing.xxl,
            ),
            children: <Widget>[
              IzyTelPageHeader(
                title: 'Profil',
                subtitle: 'Tes informations et réglages opérationnels.',
                actions: <Widget>[
                  IzyTelAvatar(
                    name: displayName,
                    imageUrl: _avatarUrl,
                    size: 42,
                    onTap: () => _openAccountMenu(account),
                  ),
                ],
              ),
              const SizedBox(height: IzyTelSpacing.lg),
              _PartnerIdentityHero(
                displayName: displayName,
                partnerCode: account.partnerCode,
                phoneNumber: _profile?.phoneNumber.isNotEmpty == true
                    ? _profile!.phoneNumber
                    : account.phoneNumber,
                city: _profile?.city.isNotEmpty == true
                    ? _profile!.city
                    : account.city,
                avatarUrl: _avatarUrl,
                verificationStatus: _profile?.verificationStatus,
              ),
              const SizedBox(height: IzyTelSpacing.md),
              IzyTelSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: IzyTelMenuRow(
                  icon: Symbols.manage_accounts_rounded,
                  title: 'Informations personnelles',
                  subtitle: _profile == null
                      ? 'Complète ton identité, tes contacts et ta pièce d’identité.'
                      : 'Profil ${_profile!.verificationStatus.label.toLowerCase()} · photo, contacts et identité.',
                  badge: _profile?.verificationStatus ==
                          StaffProfileVerificationStatus.verified
                      ? 'Vérifié'
                      : null,
                  iconColor: IzyTelColors.primary,
                  onTap: _openPersonalProfile,
                ),
              ),
              const SizedBox(height: IzyTelSpacing.md),
              _PartnerAvailabilityCard(
                available: account.isAvailable,
                isSaving: _saving,
                onChanged: (bool enabled) =>
                    _saveOperations(available: enabled),
              ),
              const SizedBox(height: IzyTelSpacing.xl),
              const _PartnerSectionLabel('Disponibilité'),
              const SizedBox(height: 6),
              IzyTelSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int index = 0;
                        index < const <String>['orange', 'mtn', 'moov'].length;
                        index++) ...<Widget>[
                      _PartnerNetworkAvailabilityRow(
                        network: const <String>['orange', 'mtn', 'moov'][index],
                        account: account,
                        isSaving: _saving,
                        onToggle: (bool enabled) => _saveOperations(
                          toggledNetwork:
                              const <String>['orange', 'mtn', 'moov'][index],
                          networkEnabled: enabled,
                        ),
                        onEditCapacity: account.authorizedNetworks.contains(
                          const <String>['orange', 'mtn', 'moov'][index],
                        )
                            ? () => _editCapacity(
                                  const <String>['orange', 'mtn', 'moov'][index],
                                )
                            : null,
                      ),
                      if (index < 2) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: IzyTelSpacing.xl),
              const _PartnerSectionLabel('Mon suivi'),
              const SizedBox(height: 6),
              IzyTelSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: IzyTelMenuRow(
                  icon: Symbols.account_balance_wallet_rounded,
                  title: 'Mes règlements',
                  subtitle: 'Gains acquis, montants à recevoir et versements reçus.',
                  iconColor: IzyTelColors.success,
                  onTap: _openFinance,
                ),
              ),
              const SizedBox(height: IzyTelSpacing.xl),
              const _PartnerSectionLabel('Compte'),
              const SizedBox(height: 6),
              IzyTelSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: IzyTelMenuRow(
                  icon: Symbols.logout_rounded,
                  title: widget.isLoggingOut ? 'Déconnexion...' : 'Se déconnecter',
                  subtitle: 'Fermer ta session Cabiniste sur cet appareil.',
                  destructive: true,
                  onTap: widget.isLoggingOut ? () {} : () => widget.onLogout(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerBottomNavigationBar extends StatelessWidget {
  const _PartnerBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const List<({String label, IconData icon})> _items =
      <({String label, IconData icon})>[
    (label: 'Accueil', icon: Symbols.home_rounded),
    (label: 'Commandes', icon: Symbols.receipt_long_rounded),
    (label: 'Historique', icon: Symbols.history_rounded),
    (label: 'Profil', icon: Symbols.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(top: BorderSide(color: IzyTelColors.outline)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 22,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List<Widget>.generate(_items.length, (int index) {
              final bool selected = index == selectedIndex;
              final Color color = selected
                  ? IzyTelColors.primary
                  : IzyTelColors.textSecondary;
              return Expanded(
                child: InkWell(
                  key: ValueKey<String>(
                    'cabiniste-nav-${_items[index].label.toLowerCase()}',
                  ),
                  onTap: () => onSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? IzyTelColors.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _items[index].icon,
                          size: IzyTelIconSize.navigation,
                          color: color,
                          fill: selected ? 1 : 0,
                          weight: selected ? 600 : 450,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[index].label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontSize: IzyTelTypeScale.micro,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PartnerAgentStyleHeader extends StatelessWidget {
  const _PartnerAgentStyleHeader({
    required this.firstName,
    required this.displayName,
    required this.available,
    required this.avatarUrl,
    required this.onAvatarTap,
  });

  final String firstName;
  final String displayName;
  final bool available;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                Symbols.notifications_rounded,
                size: IzyTelIconSize.action,
                color: IzyTelColors.textPrimary,
              ),
            ),
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: IzyTelColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Bonjour $firstName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: IzyTelTypeScale.title3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: available
                          ? IzyTelColors.success
                          : IzyTelColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    available ? 'Disponible' : 'Indisponible',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: available
                          ? IzyTelColors.textPrimary
                          : IzyTelColors.textSecondary,
                      fontSize: IzyTelTypeScale.micro,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IzyTelAvatar(
              name: displayName,
              imageUrl: avatarUrl,
              onTap: onAvatarTap,
              size: 38,
            ),
            const Icon(
              Symbols.keyboard_arrow_down_rounded,
              size: IzyTelIconSize.info,
              color: IzyTelColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _PartnerPriorityActionCard extends StatelessWidget {
  const _PartnerPriorityActionCard({
    required this.toAccept,
    required this.inProgress,
    required this.onOpenOrders,
  });

  final int toAccept;
  final int inProgress;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      backgroundColor: IzyTelColors.primary,
      borderColor: IzyTelColors.primary,
      onTap: onOpenOrders,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Commandes à traiter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$toAccept nouvelle${toAccept > 1 ? 's' : ''} · $inProgress en cours',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Symbols.arrow_forward_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

class _PartnerOperationalSummary extends StatelessWidget {
  const _PartnerOperationalSummary({
    required this.toAccept,
    required this.inProgress,
    required this.completed,
  });

  final int toAccept;
  final int inProgress;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: _PartnerSummaryItem(label: 'À accepter', value: toAccept)),
          const SizedBox(height: 38, child: VerticalDivider(width: 1)),
          Expanded(child: _PartnerSummaryItem(label: 'En cours', value: inProgress)),
          const SizedBox(height: 38, child: VerticalDivider(width: 1)),
          Expanded(child: _PartnerSummaryItem(label: 'Terminées', value: completed)),
        ],
      ),
    );
  }
}

class _PartnerSummaryItem extends StatelessWidget {
  const _PartnerSummaryItem({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _PartnerCapacitySummaryRow extends StatelessWidget {
  const _PartnerCapacitySummaryRow({required this.network, required this.capacity});
  final String network;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          _PartnerNetworkLogo(network: network),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _networkLabel(network),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            _formatMoney(capacity),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PartnerOrdersEmptyState extends StatelessWidget {
  const _PartnerOrdersEmptyState({required this.tab});
  final _PartnerOrdersTab tab;

  @override
  Widget build(BuildContext context) {
    final String message = switch (tab) {
      _PartnerOrdersTab.toAccept => 'Aucune nouvelle commande à accepter.',
      _PartnerOrdersTab.inProgress => 'Aucune commande en cours de traitement.',
      _PartnerOrdersTab.completed => 'Aucune commande terminée pour le moment.',
    };
    return IzyTelSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: <Widget>[
            const Icon(Symbols.inbox_rounded, color: IzyTelColors.textMuted, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IzyTelColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerHistoryCard extends StatelessWidget {
  const _PartnerHistoryCard({required this.item});
  final PartnerAssignmentHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (item.status) {
      'completed' => IzyTelColors.success,
      'refused' => IzyTelColors.warning,
      'failed' => IzyTelColors.error,
      _ => IzyTelColors.primary,
    };
    final String label = switch (item.status) {
      'completed' => 'Terminée',
      'refused' => 'Refusée',
      'failed' => 'Échec',
      'accepted' => 'Acceptée',
      'in_progress' => 'En cours',
      'on_hold' => 'En attente',
      _ => item.status.isEmpty ? 'Historique' : item.status,
    };
    return IzyTelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _PartnerNetworkLogo(network: item.network),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.orderReference,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '${_networkLabel(item.network)} · ${_formatMoney(item.amount)}',
                      style: const TextStyle(
                        color: IzyTelColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IzyTelStatusPill(label: label, color: color),
            ],
          ),
          if (item.refusalReason?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              item.refusalReason!,
              style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _shortDate(item.completedAt ?? item.refusedAt ?? item.updatedAt),
            style: const TextStyle(color: IzyTelColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PartnerIdentityHero extends StatelessWidget {
  const _PartnerIdentityHero({
    required this.displayName,
    required this.partnerCode,
    required this.phoneNumber,
    required this.city,
    required this.avatarUrl,
    required this.verificationStatus,
  });

  final String displayName;
  final String partnerCode;
  final String phoneNumber;
  final String city;
  final String? avatarUrl;
  final StaffProfileVerificationStatus? verificationStatus;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: Row(
        children: <Widget>[
          IzyTelAvatar(name: displayName, imageUrl: avatarUrl, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(displayName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '$partnerCode · Cabiniste',
                  style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12),
                ),
                if (phoneNumber.trim().isNotEmpty || city.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    <String>[phoneNumber.trim(), city.trim()]
                        .where((String value) => value.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: IzyTelColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (verificationStatus != null)
            IzyTelStatusPill(
              label: verificationStatus!.label,
              color: verificationStatus == StaffProfileVerificationStatus.verified
                  ? IzyTelColors.success
                  : IzyTelColors.warning,
            ),
        ],
      ),
    );
  }
}

class _PartnerAvailabilityCard extends StatelessWidget {
  const _PartnerAvailabilityCard({
    required this.available,
    required this.isSaving,
    required this.onChanged,
  });

  final bool available;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (available ? IzyTelColors.success : IzyTelColors.textMuted)
                  .withAlpha(22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              available ? Symbols.check_circle_rounded : Symbols.pause_circle_rounded,
              color: available ? IzyTelColors.success : IzyTelColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  available ? 'Disponible' : 'Indisponible',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Tu peux recevoir de nouvelles commandes.'
                      : 'Aucune nouvelle commande ne te sera affectée.',
                  style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(value: available, onChanged: isSaving ? null : onChanged),
        ],
      ),
    );
  }
}

class _PartnerNetworkAvailabilityRow extends StatelessWidget {
  const _PartnerNetworkAvailabilityRow({
    required this.network,
    required this.account,
    required this.isSaving,
    required this.onToggle,
    required this.onEditCapacity,
  });

  final String network;
  final PartnerAccountSnapshot account;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEditCapacity;

  @override
  Widget build(BuildContext context) {
    final bool authorized = account.authorizedNetworks.contains(network);
    final bool active = authorized && account.activeNetworks.contains(network);
    final Color accent = _networkColor(network);
    final VoidCallback? editAction = authorized && !isSaving
        ? onEditCapacity
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IzyTelSpacing.md,
        vertical: IzyTelSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          _PartnerNetworkLogo(network: network),
          const SizedBox(width: IzyTelSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      _networkLabel(network),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? accent : IzyTelColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (authorized)
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '${_formatMoney(account.capacityFor(network))} disponibles',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: IzyTelColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        key: ValueKey<String>('cabiniste-capacity-edit-$network'),
                        onPressed: editAction,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Symbols.edit_rounded, size: 15),
                        label: const Text('Modifier'),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Réseau non autorisé par l’administration',
                    style: TextStyle(
                      color: IzyTelColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: active,
            onChanged: !authorized || isSaving ? null : onToggle,
          ),
        ],
      ),
    );
  }
}

class _PartnerNetworkLogo extends StatelessWidget {
  const _PartnerNetworkLogo({required this.network});
  final String network;

  @override
  Widget build(BuildContext context) {
    final String asset = switch (network.toLowerCase()) {
      'orange' => 'assets/brands/operators/orange_ci.png',
      'mtn' => 'assets/brands/operators/mtn_ci.png',
      _ => 'assets/brands/operators/moov_africa_ci.png',
    };
    final Color background = switch (network.toLowerCase()) {
      'orange' => IzyTelColors.orangeSoft,
      'mtn' => IzyTelColors.mtnSoft,
      _ => IzyTelColors.moovSoft,
    };
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _PartnerCapacityEditorSheet extends StatefulWidget {
  const _PartnerCapacityEditorSheet({
    required this.network,
    required this.initialAmount,
  });

  final String network;
  final int initialAmount;

  @override
  State<_PartnerCapacityEditorSheet> createState() =>
      _PartnerCapacityEditorSheetState();
}

class _PartnerCapacityEditorSheetState
    extends State<_PartnerCapacityEditorSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialAmount}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String raw = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int? value = int.tryParse(raw);
    if (value == null || value < 0) {
      setState(() => _errorText = 'Saisis un montant valide.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
        child: Container(
          padding: const EdgeInsets.all(IzyTelSpacing.lg),
          decoration: const BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.all(
              Radius.circular(IzyTelRadii.sheet),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _PartnerNetworkLogo(network: widget.network),
                    const SizedBox(width: IzyTelSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Capacité ${_networkLabel(widget.network)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: IzyTelColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Indique le montant réellement disponible sur ce réseau.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: IzyTelColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Montant disponible',
                    suffixText: 'F CFA',
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    key: ValueKey<String>(
                      'cabiniste-capacity-save-${widget.network}',
                    ),
                    onPressed: _submit,
                    icon: const Icon(Symbols.save_rounded),
                    label: const Text(
                      'Enregistrer la capacité',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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

class _PartnerSectionLabel extends StatelessWidget {
  const _PartnerSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: IzyTelColors.textPrimary,
          ),
    );
  }
}

class _PartnerOrderCard extends StatelessWidget {
  const _PartnerOrderCard({
    required this.order,
    required this.onTap,
    this.queuePosition,
    this.onAccept,
    this.onRefuse,
  });

  final PartnerOrderSnapshot order;
  final VoidCallback onTap;
  final int? queuePosition;
  final VoidCallback? onAccept;
  final VoidCallback? onRefuse;

  @override
  Widget build(BuildContext context) {
    final Color priorityColor = switch (queuePosition ?? 3) {
      1 => IzyTelColors.error,
      2 => IzyTelColors.warning,
      _ => _networkColor(order.network),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: priorityColor.withAlpha(75)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: IzyTelColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _PartnerNetworkLogo(network: order.network),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(order.orderReference,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          order.beneficiaryPhone.isEmpty
                              ? _networkLabel(order.network)
                              : order.beneficiaryPhone,
                          style: const TextStyle(
                            color: IzyTelColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IzyTelStatusPill(
                    label: _statusLabel(order),
                    color: _statusColor(order),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.offerLabel.isEmpty
                          ? _networkLabel(order.network)
                          : order.offerLabel,
                      style: const TextStyle(color: IzyTelColors.textMuted, fontSize: 12),
                    ),
                  ),
                  Text(
                    _formatMoney(order.amount),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Symbols.chevron_right_rounded, color: IzyTelColors.textMuted),
                ],
              ),
              if (onAccept != null && onRefuse != null) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRefuse,
                        child: const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        child: const Text('Accepter'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceMiniStat extends StatelessWidget {
  const _FinanceMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerErrorState extends StatelessWidget {
  const _PartnerErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Symbols.cloud_off_rounded, color: IzyTelColors.textMuted, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger les informations Cabiniste.',
              textAlign: TextAlign.center,
              style: TextStyle(color: IzyTelColors.textSecondary),
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

class _PartnerHomeData {
  const _PartnerHomeData({
    required this.account,
    required this.orders,
    required this.finance,
    required this.profile,
    required this.avatarUrl,
  });

  final PartnerAccountSnapshot? account;
  final List<PartnerOrderSnapshot> orders;
  final PartnerFinanceSnapshot finance;
  final StaffProfile? profile;
  final String? avatarUrl;
}

String _statusLabel(PartnerOrderSnapshot order) {
  if (order.isAwaitingDecision) return 'À accepter';
  if (order.isAccepted && order.orderStatus == 'paidReady') return 'Acceptée';
  if (order.isInProgress) return 'En cours';
  if (order.isOnHold) return 'En attente';
  if (order.isCompleted) return 'Terminée';
  if (order.isFailed) return 'Échec';
  return order.orderStatus.isEmpty ? order.assignmentState : order.orderStatus;
}

Color _statusColor(PartnerOrderSnapshot order) {
  if (order.isAwaitingDecision) return IzyTelColors.warning;
  if (order.isAccepted && order.orderStatus == 'paidReady') return IzyTelColors.primary;
  if (order.isInProgress) return IzyTelColors.primary;
  if (order.isOnHold) return IzyTelColors.warning;
  if (order.isCompleted) return IzyTelColors.success;
  if (order.isFailed) return IzyTelColors.error;
  return IzyTelColors.textSecondary;
}

Color _networkColor(String network) {
  return switch (network.trim().toLowerCase()) {
    'orange' => IzyTelColors.orange,
    'mtn' => IzyTelColors.mtn,
    'moov' => IzyTelColors.moov,
    _ => IzyTelColors.primary,
  };
}

String _networkLabel(String network) {
  return switch (network.trim().toLowerCase()) {
    'orange' => 'Orange',
    'mtn' => 'MTN',
    'moov' => 'Moov',
    _ => network.toUpperCase(),
  };
}

String _formatMoney(int amount) {
  final bool negative = amount < 0;
  final String digits = amount.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}${buffer.toString()} F';
}

String _shortDate(DateTime? date) {
  if (date == null) return '';
  final DateTime local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _friendlyError(Object error) {
  final String raw = error.toString().toLowerCase();
  if (raw.contains('proof_required')) {
    return 'Ajoute une preuve avant de terminer la commande.';
  }
  if (raw.contains('insufficient_capacity')) {
    return 'Ta capacité disponible est insuffisante pour cette commande.';
  }
  if (raw.contains('capacity_below_reserved')) {
    return 'Cette capacité est déjà engagée sur une ou plusieurs commandes en cours.';
  }
  if (raw.contains('partner_not_active') || raw.contains('active_partner_required')) {
    return 'Ton compte Cabiniste n’est pas actif.';
  }
  if (raw.contains('order_not_assigned') || raw.contains('order_not_owned')) {
    return 'Cette commande ne t’est plus affectée.';
  }
  if (raw.contains('order_not_in_progress')) {
    return 'Cette commande n’est plus en cours de traitement.';
  }
  if (raw.contains('order_not_on_hold')) {
    return 'Cette commande n’est plus en attente.';
  }
  if (raw.contains('invalid_hold_reason')) {
    return 'Indique un motif de mise en attente valide.';
  }
  if (raw.contains('invalid_failure_reason')) {
    return 'Choisis un motif d’échec valide.';
  }
  if (raw.contains('network_not_authorized')) {
    return 'Ce réseau n’est pas autorisé sur ton compte.';
  }
  return 'L’opération n’a pas pu être effectuée. Réessaie.';
}
