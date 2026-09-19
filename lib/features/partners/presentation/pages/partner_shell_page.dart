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
      await widget.repository.accept(order.orderId);
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Commande ${order.orderReference} acceptée.',
      );
      _reload();
    } catch (error) {
      if (mounted) IzyTelFeedback.error(context, _friendlyError(error));
    }
  }

  Future<void> _refuseOrder(PartnerOrderSnapshot order) async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du refus',
            hintText: 'Ex. capacité insuffisante ou indisponibilité réseau',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Confirmer le refus'),
          ),
        ],
      ),
    );
    controller.dispose();
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
  bool _proofReady = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    unawaited(_loadProofState());
  }

  Future<void> _loadProofState() async {
    try {
      final bool hasProof = await widget.repository.hasProof(_order.orderId);
      if (mounted) setState(() => _proofReady = hasProof);
    } catch (_) {
      // Une preuve indisponible au chargement ne doit pas bloquer la page.
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

  Future<String?> _askReason({
    required String title,
    required String hint,
  }) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.length >= 3) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _captureProof() async {
    if (_busy) return;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Symbols.photo_camera_rounded),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Symbols.photo_library_rounded),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _busy = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1440,
      );
      if (image == null) return;
      final List<int> bytes = await image.readAsBytes();
      await widget.repository.saveProof(
        orderId: _order.orderId,
        fileName: '${_order.orderReference}_preuve.jpg',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _proofReady = true);
      IzyTelFeedback.success(context, 'Preuve enregistrée.');
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    if (_busy) return;
    if (!_proofReady) {
      IzyTelFeedback.show(
        context,
        'Ajoute la preuve du transfert avant de terminer.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }
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
      final PartnerOrderSnapshot? resolvedOrder = refreshed;
      if (resolvedOrder != null) {
        setState(() => _order = resolvedOrder);
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

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(_order);
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: Text(_order.orderReference),
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          IzyTelSpacing.lg,
          IzyTelSpacing.md,
          IzyTelSpacing.lg,
          IzyTelSpacing.xxl,
        ),
        children: <Widget>[
          IzyTelSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _formatMoney(_order.amount),
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IzyTelStatusPill(
                      label: _statusLabel(_order),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoLine(label: 'Réseau', value: _order.network.toUpperCase()),
                _InfoLine(
                  label: 'Numéro bénéficiaire',
                  value: _order.beneficiaryPhone.isEmpty
                      ? 'Non renseigné'
                      : _order.beneficiaryPhone,
                ),
                _InfoLine(
                  label: 'Opération',
                  value: _order.operationType.isEmpty
                      ? 'Recharge'
                      : _order.operationType,
                ),
                if (_order.offerLabel.isNotEmpty)
                  _InfoLine(label: 'Offre', value: _order.offerLabel),
              ],
            ),
          ),
          const SizedBox(height: IzyTelSpacing.lg),
          if (_order.isAwaitingDecision) ...<Widget>[
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => widget.repository.accept(_order.orderId),
                        successMessage: 'Commande acceptée.',
                      ),
              icon: const Icon(Symbols.check_circle_rounded),
              label: const Text('Accepter la commande'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final String? reason = await _askReason(
                        title: 'Refuser la commande',
                        hint: 'Indique le motif du refus.',
                      );
                      if (reason == null) return;
                      await _run(
                        () => widget.repository.refuse(
                          orderId: _order.orderId,
                          reason: reason,
                        ),
                        successMessage: 'Commande refusée.',
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Symbols.close_rounded),
              label: const Text('Refuser'),
            ),
          ],
          if (_order.isAccepted && _order.orderStatus == 'paidReady')
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => widget.repository.startProcessing(_order.orderId),
                        successMessage: 'Traitement démarré.',
                      ),
              icon: const Icon(Symbols.play_arrow_rounded),
              label: const Text('Démarrer le traitement'),
            ),
          if (_order.isInProgress) ...<Widget>[
            IzyTelSurface(
              child: Row(
                children: <Widget>[
                  Icon(
                    _proofReady
                        ? Symbols.verified_rounded
                        : Symbols.photo_camera_rounded,
                    color: _proofReady
                        ? IzyTelColors.success
                        : IzyTelColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _proofReady
                          ? 'Preuve enregistrée'
                          : 'Une preuve photo est obligatoire avant le succès.',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _captureProof,
                    child: Text(_proofReady ? 'Remplacer' : 'Ajouter'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _finalize,
              icon: const Icon(Symbols.task_alt_rounded),
              label: const Text('Marquer comme terminée'),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final String? reason = await _askReason(
                              title: 'Mettre en attente',
                              hint: 'Pourquoi la commande est-elle en attente ?',
                            );
                            if (reason == null) return;
                            await _run(
                              () => widget.repository.hold(
                                orderId: _order.orderId,
                                reason: reason,
                              ),
                              successMessage: 'Commande mise en attente.',
                            );
                          },
                    icon: const Icon(Symbols.pause_rounded),
                    label: const Text('Attente'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final String? note = await _askReason(
                              title: 'Signaler un échec',
                              hint: 'Décris brièvement le problème.',
                            );
                            if (note == null) return;
                            await _run(
                              () => widget.repository.fail(
                                orderId: _order.orderId,
                                reason: 'other',
                                observation: note,
                              ),
                              successMessage: 'Échec enregistré.',
                            );
                          },
                    icon: const Icon(Symbols.error_rounded),
                    label: const Text('Échec'),
                  ),
                ),
              ],
            ),
          ],
          if (_order.isOnHold)
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => widget.repository.resume(_order.orderId),
                        successMessage: 'Traitement repris.',
                      ),
              icon: const Icon(Symbols.play_arrow_rounded),
              label: const Text('Reprendre le traitement'),
            ),
          if (_order.isCompleted || _order.isFailed)
            IzyTelSurface(
              child: Row(
                children: <Widget>[
                  Icon(
                    _order.isCompleted
                        ? Symbols.check_circle_rounded
                        : Symbols.error_rounded,
                    color: _order.isCompleted
                        ? IzyTelColors.success
                        : IzyTelColors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _order.isCompleted
                          ? 'Cette commande est terminée.'
                          : 'Cette commande est clôturée en échec.',
                    ),
                  ),
                ],
              ),
            ),
          if (_busy) ...<Widget>[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
  if (raw.contains('network_not_authorized')) {
    return 'Ce réseau n’est pas autorisé sur ton compte.';
  }
  return 'L’opération n’a pas pu être effectuée. Réessaie.';
}
