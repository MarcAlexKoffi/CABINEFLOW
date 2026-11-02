import 'dart:convert';
import 'package:cabine_flow/backoffice/data/repositories/backoffice_user_administration_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_user_admin_dialog.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_modal.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeUsersPage extends StatefulWidget {
  const BackofficeUsersPage({
    super.key,
    required this.currentUser,
    required this.repository,
    this.onManageManager,
    this.onManageAgent,
    this.administration,
  });

  final AppUser currentUser;
  final BackofficeUserRepository repository;
  final ValueChanged<BackofficeUserAccount>? onManageManager;
  final ValueChanged<BackofficeUserAccount>? onManageAgent;
  final BackofficeUserAdministration? administration;

  @override
  State<BackofficeUsersPage> createState() => _BackofficeUsersPageState();
}

class _BackofficeUsersPageState extends State<BackofficeUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  BackofficeAccountRole? _roleFilter;
  _AccountStatusFilter _statusFilter = _AccountStatusFilter.all;
  String _query = '';
  String? _zoneFilter;
  int _page = 0;
  late Stream<List<BackofficeUserAccount>> _users;
  List<BackofficeUserAccount>? _lastUsers;
  late final BackofficeUserAdministration _administration;
  List<UserAdminZone> _zones = const [];
  bool _working = false;

  Stream<List<BackofficeUserAccount>> _watchUsers() {
    return widget.repository.watchUsers().map((users) {
      _lastUsers = users;
      return users;
    });
  }

  void _reloadUsers() {
    setState(() {
      _lastUsers = null;
      _users = _watchUsers();
    });
  }

  String _registryErrorMessage(Object? error) {
    if (error is BackofficeUserRegistryException) {
      final String resource = switch (error.source) {
        BackofficeUserRegistrySource.firestore => 'le registre Firestore',
        BackofficeUserRegistrySource.supabase => 'le registre métier Supabase',
      };
      return '${BackendFailurePolicy.readMessageForKind(error.kind, resource: resource)} Code : ${error.code}.';
    }
    return 'La source des utilisateurs est momentanément indisponible. Vérifie la session puis réessaie.';
  }

  @override
  void initState() {
    super.initState();
    _users = _watchUsers();
    _administration =
        widget.administration ?? BackofficeUserAdministrationRepository();
    if (widget.currentUser.role == UserRole.administrator) {
      _administration
          .loadZones()
          .then((zones) {
            if (mounted) setState(() => _zones = zones);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void didUpdateWidget(covariant BackofficeUsersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _lastUsers = null;
      _users = _watchUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BackofficeUserAccount> _filter(List<BackofficeUserAccount> users) {
    final String query = _query.trim().toLowerCase();
    return users
        .where((BackofficeUserAccount user) {
          if (_roleFilter != null && user.role != _roleFilter) return false;
          if (!_statusFilter.matches(user)) return false;
          if (_zoneFilter != null && !user.zoneIds.contains(_zoneFilter)) {
            return false;
          }
          if (query.isEmpty) return true;
          return user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.phoneNumber.toLowerCase().contains(query) ||
              user.id.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _editUser([BackofficeUserAccount? user]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackofficeUserAdminDialog(
        administration: _administration,
        user: user,
      ),
    );
    if (saved == true && mounted) {
      IzyTelFeedback.success(
        context,
        'Compte enregistré. Les accès ont été synchronisés.',
      );
    }
  }

  Future<Map<String, dynamic>?> _command(
    String action,
    BackofficeUserAccount user, {
    String? confirmUid,
  }) async {
    if (_working) return null;
    _working = true;
    try {
      return await _administration.send({
        'action': action,
        'uid': user.id,
        'requestId': BackofficeUserAdministrationRepository.newRequestId(),
        'confirmUid': ?confirmUid,
      });
    } catch (error) {
      if (mounted) {
        IzyTelFeedback.error(
          context,
          error is UserAdminException
              ? error.toString()
              : 'Le résultat est incertain. Faites vérifier l’opération avant de recommencer.',
        );
      }
      return null;
    } finally {
      _working = false;
    }
  }

  Future<void> _resetPassword(BackofficeUserAccount user) async {
    final result = await _command('reset_password', user);
    if (result == null || !mounted) return;
    final link = result['resetLink']?.toString();
    if (link == null || link.isEmpty) {
      IzyTelFeedback.success(
        context,
        'La demande a déjà été traitée. Aucun lien n’a été envoyé automatiquement.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lien de réinitialisation'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ce lien donne accès à la réinitialisation du mot de passe. Transmettez-le uniquement au titulaire après vérification. Aucun e-mail n’a été envoyé.',
                ),
                const SizedBox(height: 14),
                SelectableText(link),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
            },
            child: const Text('Copier le lien'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(BackofficeUserAccount user) async {
    final confirmation = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Suppression définitive'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La suppression est bloquée tant que toutes les références historiques ne sont pas vérifiées. La désactivation conserve l’historique.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'Pour confirmer la demande, saisissez cet UID : ${user.id}',
                ),
                TextField(
                  controller: confirmation,
                  onChanged: (_) => setDialog(() {}),
                  decoration: const InputDecoration(
                    labelText: 'UID de confirmation',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: confirmation.text == user.id
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Vérifier et supprimer'),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (confirmed == true) await _command('delete', user, confirmUid: user.id);
  }

  void _showHistory(BackofficeUserAccount user) {
    final future = _administration.send({
      'action': 'audit',
      'uid': user.id,
      'requestId': BackofficeUserAdministrationRepository.newRequestId(),
    });
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Historique de ${user.name}'),
        content: SizedBox(
          width: 760,
          child: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Impossible de consulter l’historique. ${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final events = snapshot.data!['events'];
              if (events is! List || events.isEmpty) {
                return const Text(
                  'Aucune opération du nouveau registre administratif. Les opérations historiques antérieures ne sont pas reconstituées.',
                );
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final raw in events)
                      if (raw is Map)
                        ExpansionTile(
                          title: Text(
                            '${raw['action'] ?? 'Opération'} · ${raw['status'] ?? ''}',
                          ),
                          subtitle: Text(
                            '${raw['created_at'] ?? ''} · Auteur : ${raw['actor_uid'] ?? ''}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                const JsonEncoder.withIndent('  ').convert(raw),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser.role != UserRole.administrator) {
      return const _UsersAccessDenied();
    }

    return StreamBuilder<List<BackofficeUserAccount>>(
      stream: _users,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<BackofficeUserAccount>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _UsersLoadingState();
            }

            if (snapshot.hasData) {
              _lastUsers = snapshot.data;
            }
            final List<BackofficeUserAccount>? availableUsers =
                snapshot.data ?? _lastUsers;

            if (snapshot.hasError && availableUsers == null) {
              return _UsersErrorState(
                message: _registryErrorMessage(snapshot.error),
                onRetry: _reloadUsers,
              );
            }

            final List<BackofficeUserAccount> allUsers =
                availableUsers ?? const <BackofficeUserAccount>[];
            final List<BackofficeUserAccount> visibleUsers = _filter(allUsers);
            final page = _page.clamp(
              0,
              visibleUsers.isEmpty ? 0 : (visibleUsers.length - 1) ~/ 50,
            );
            final paged = visibleUsers
                .skip(page * 50)
                .take(50)
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _UsersHeader(onCreate: () => _editUser()),
                if (snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Le registre est partiellement indisponible. Certaines informations métier peuvent manquer.',
                    ),
                  ),
                const SizedBox(height: 22),
                _UsersSummary(users: allUsers),
                const SizedBox(height: 22),
                _UsersFilters(
                  searchController: _searchController,
                  roleFilter: _roleFilter,
                  statusFilter: _statusFilter,
                  onSearchChanged: (String value) =>
                      setState(() => _query = value),
                  onRoleChanged: (BackofficeAccountRole? value) =>
                      setState(() => _roleFilter = value),
                  onStatusChanged: (_AccountStatusFilter value) =>
                      setState(() => _statusFilter = value),
                  onReset: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _roleFilter = null;
                      _statusFilter = _AccountStatusFilter.all;
                      _zoneFilter = null;
                      _page = 0;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _zoneFilter,
                  decoration: const InputDecoration(labelText: 'Zone'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Toutes les zones'),
                    ),
                    for (final zone in _zones)
                      DropdownMenuItem(value: zone.id, child: Text(zone.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _zoneFilter = value;
                    _page = 0;
                  }),
                ),
                const SizedBox(height: 14),
                _UsersRegistry(
                  users: paged,
                  totalCount: allUsers.length,
                  zoneNames: {for (final zone in _zones) zone.id: zone.name},
                  onOpen: (BackofficeUserAccount user) =>
                      _showUserDetails(context, user),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${visibleUsers.length} résultats · Page ${page + 1}'),
                    IconButton(
                      tooltip: 'Page précédente',
                      onPressed: page > 0
                          ? () => setState(() => _page = page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Page suivante',
                      onPressed: (page + 1) * 50 < visibleUsers.length
                          ? () => setState(() => _page = page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
    );
  }

  void _showUserDetails(BuildContext context, BackofficeUserAccount user) {
    showBackofficeModal<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Color statusTone = user.isPending
            ? BackofficePalette.warning
            : user.isActive
            ? BackofficePalette.success
            : BackofficePalette.danger;
        return BackofficeModalShell(
          title: user.name,
          subtitle: user.email.trim().isEmpty
              ? 'Compte IzyTel'
              : user.email.trim(),
          leading: _LargeAvatar(user: user),
          maxWidth: 820,
          chips: <Widget>[
            _RolePill(role: user.role),
            _StatusPill(user: user),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (user.hasRoleConflict)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Deux profils métier actifs portent des rôles contradictoires. Vérifiez ce compte avant modification.',
                    style: TextStyle(color: BackofficePalette.danger),
                  ),
                ),
              BackofficeModalHero(
                leading: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusTone.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    user.isActive
                        ? Symbols.verified_user_rounded
                        : Symbols.person_off_rounded,
                    color: statusTone,
                    size: 27,
                    fill: 1,
                  ),
                ),
                eyebrow: 'Compte ${user.role.label}',
                value: user.statusLabel,
                caption: user.isPending
                    ? 'Ce compte attend encore une validation ou un provisioning.'
                    : user.isActive
                    ? 'Accès actif dans le registre IzyTel.'
                    : 'Accès désactivé dans le registre IzyTel.',
              ),
              const SizedBox(height: 14),
              BackofficeModalSection(
                title: 'Identité & contact',
                subtitle: 'Informations principales du compte.',
                icon: Symbols.account_circle_rounded,
                child: BackofficeInfoGrid(
                  items: <BackofficeInfoItem>[
                    BackofficeInfoItem(
                      label: 'Nom',
                      value: _fallback(user.name),
                      icon: Symbols.badge_rounded,
                      emphasis: true,
                    ),
                    BackofficeInfoItem(
                      label: 'E-mail',
                      value: _fallback(user.email),
                      icon: Symbols.mail_rounded,
                      selectable: true,
                    ),
                    BackofficeInfoItem(
                      label: 'Téléphone',
                      value: _fallback(user.phoneNumber),
                      icon: Symbols.phone_rounded,
                      selectable: true,
                    ),
                    BackofficeInfoItem(
                      label: 'Rôle',
                      value: user.role.label,
                      icon: Symbols.admin_panel_settings_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BackofficeModalSection(
                title: 'Accès & activité',
                subtitle: 'État du compte et repères temporels.',
                icon: Symbols.history_rounded,
                child: BackofficeInfoGrid(
                  items: <BackofficeInfoItem>[
                    BackofficeInfoItem(
                      label: 'Statut',
                      value: user.statusLabel,
                      icon: Symbols.rule_rounded,
                      emphasis: true,
                    ),
                    BackofficeInfoItem(
                      label: 'Créé le',
                      value: _formatDate(user.createdAt),
                      icon: Symbols.event_rounded,
                    ),
                    BackofficeInfoItem(
                      label: 'Dernière activité',
                      value: _formatDate(user.lastActivityAt),
                      icon: Symbols.schedule_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BackofficeModalSection(
                title: 'Identifiant technique',
                subtitle: 'À utiliser uniquement pour le support ou l’audit.',
                icon: Symbols.fingerprint_rounded,
                backgroundColor: const Color(0xFFFAFBFD),
                child: BackofficeInfoGrid(
                  minItemWidth: 520,
                  items: <BackofficeInfoItem>[
                    BackofficeInfoItem(
                      label: 'UID',
                      value: user.id,
                      icon: Symbols.key_rounded,
                      selectable: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showHistory(user);
              },
              child: const Text('Historique'),
            ),
            if (user.id != widget.currentUser.id &&
                !user.id.startsWith('partner:')) ...[
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _editUser(user);
                },
                child: const Text('Modifier / activer / désactiver'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _resetPassword(user);
                },
                child: const Text('Réinitialiser le mot de passe'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteUser(user);
                },
                child: const Text('Supprimer définitivement'),
              ),
            ],
            if (user.role == BackofficeAccountRole.manager &&
                widget.onManageManager != null)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  widget.onManageManager!(user);
                },
                icon: const Icon(Symbols.supervisor_account_rounded),
                label: const Text('Gérer dans Comptes Managers'),
              ),
            if (user.role == BackofficeAccountRole.agent &&
                widget.onManageAgent != null)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  widget.onManageAgent!(user);
                },
                icon: const Icon(Symbols.badge_rounded),
                label: const Text('Gérer dans Agents'),
              ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Symbols.check_rounded),
              label: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 720;
    final Widget action = _CreateUserButton(onPressed: onCreate);

    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ADMINISTRATION',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: BackofficePalette.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(height: 7),
        Text('Utilisateurs', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            'Registre des comptes IzyTel : Agents, Cabinistes, Managers, Administrateurs et comptes en attente.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[copy, const SizedBox(height: 16), action],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: copy),
        const SizedBox(width: 20),
        action,
      ],
    );
  }
}

class _CreateUserButton extends StatelessWidget {
  const _CreateUserButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: BackofficeGradients.brand,
          borderRadius: BorderRadius.circular(14),
          boxShadow: BackofficeShadows.glow,
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Symbols.person_add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nouvel utilisateur',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

class _UsersSummary extends StatelessWidget {
  const _UsersSummary({required this.users});

  final List<BackofficeUserAccount> users;

  @override
  Widget build(BuildContext context) {
    final int active = users
        .where((BackofficeUserAccount user) => user.isActive && !user.isPending)
        .length;
    final int pending = users
        .where((BackofficeUserAccount user) => user.isPending)
        .length;
    final int staff = users
        .where(
          (BackofficeUserAccount user) =>
              user.role == BackofficeAccountRole.administrator ||
              user.role == BackofficeAccountRole.manager,
        )
        .length;

    final List<_SummaryData> values = <_SummaryData>[
      _SummaryData(
        'Utilisateurs',
        users.length,
        Symbols.group_rounded,
        BackofficePalette.primary,
        const Color(0xFFEAF1FF),
      ),
      _SummaryData(
        'Comptes actifs',
        active,
        Symbols.verified_rounded,
        BackofficePalette.success,
        const Color(0xFFEAF9F3),
      ),
      _SummaryData(
        'En attente',
        pending,
        Symbols.schedule_rounded,
        BackofficePalette.warning,
        const Color(0xFFFFF6E5),
      ),
      _SummaryData(
        'Admin / Manager',
        staff,
        Symbols.admin_panel_settings_rounded,
        BackofficePalette.primaryStrong,
        const Color(0xFFE8F0FF),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1020
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        const double spacing = 14;
        final double cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: values
              .map(
                (_SummaryData data) => SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(data: data),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryData {
  const _SummaryData(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.softColor,
  );

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color softColor;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(18),
      decoration: backofficePanelDecoration(elevated: true),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.softColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              data.icon,
              color: data.color,
              size: 24,
              fill: 1,
              weight: 620,
              opticalSize: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${data.value}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersFilters extends StatelessWidget {
  const _UsersFilters({
    required this.searchController,
    required this.roleFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onReset,
  });

  final TextEditingController searchController;
  final BackofficeAccountRole? roleFilter;
  final _AccountStatusFilter statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<BackofficeAccountRole?> onRoleChanged;
  final ValueChanged<_AccountStatusFilter> onStatusChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Symbols.tune_rounded,
                  size: 19,
                  color: BackofficePalette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recherche & filtres',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Symbols.filter_alt_off_rounded, size: 18),
                label: const Text('Réinitialiser'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 780;
              final Widget search = TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Nom, e-mail, téléphone ou UID',
                  prefixIcon: Icon(Symbols.search_rounded),
                ),
              );
              final Widget role =
                  DropdownButtonFormField<BackofficeAccountRole?>(
                    isExpanded: true,
                    initialValue: roleFilter,
                    decoration: const InputDecoration(labelText: 'Rôle'),
                    items: <DropdownMenuItem<BackofficeAccountRole?>>[
                      const DropdownMenuItem<BackofficeAccountRole?>(
                        value: null,
                        child: Text('Tous les rôles'),
                      ),
                      ...BackofficeAccountRole.values
                          .where(
                            (BackofficeAccountRole value) =>
                                value != BackofficeAccountRole.unknown,
                          )
                          .map(
                            (BackofficeAccountRole value) =>
                                DropdownMenuItem<BackofficeAccountRole?>(
                                  value: value,
                                  child: Text(
                                    value.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          ),
                    ],
                    onChanged: onRoleChanged,
                  );
              final Widget status =
                  DropdownButtonFormField<_AccountStatusFilter>(
                    isExpanded: true,
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: _AccountStatusFilter.values
                        .map(
                          (_AccountStatusFilter value) =>
                              DropdownMenuItem<_AccountStatusFilter>(
                                value: value,
                                child: Text(
                                  value.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) onStatusChanged(value);
                    },
                  );

              if (compact) {
                return Column(
                  children: <Widget>[
                    search,
                    const SizedBox(height: 10),
                    role,
                    const SizedBox(height: 10),
                    status,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(flex: 4, child: search),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: role),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: status),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UsersRegistry extends StatelessWidget {
  const _UsersRegistry({
    required this.users,
    required this.totalCount,
    required this.onOpen,
    this.zoneNames = const {},
  });

  final List<BackofficeUserAccount> users;
  final int totalCount;
  final ValueChanged<BackofficeUserAccount> onOpen;
  final Map<String, String> zoneNames;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: backofficePanelDecoration(elevated: true),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 15),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Registre des comptes',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${users.length} résultat${users.length > 1 ? 's' : ''} affiché${users.length > 1 ? 's' : ''} sur $totalCount',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalCount comptes',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BackofficePalette.primaryStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (users.isEmpty)
            _UsersEmptyState(totalCount: totalCount)
          else if (MediaQuery.sizeOf(context).width >= 930)
            _UsersDesktopTable(
              users: users,
              onOpen: onOpen,
              zoneNames: zoneNames,
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: _UsersMobileList(users: users, onOpen: onOpen),
            ),
        ],
      ),
    );
  }
}

class _UsersDesktopTable extends StatelessWidget {
  const _UsersDesktopTable({
    required this.users,
    required this.onOpen,
    required this.zoneNames,
  });

  final List<BackofficeUserAccount> users;
  final ValueChanged<BackofficeUserAccount> onOpen;
  final Map<String, String> zoneNames;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 20,
        columnSpacing: 28,
        columns: const <DataColumn>[
          DataColumn(label: Text('UTILISATEUR')),
          DataColumn(label: Text('RÔLE')),
          DataColumn(label: Text('STATUT')),
          DataColumn(label: Text('ZONE(S)')),
          DataColumn(label: Text('CRÉÉ LE')),
          DataColumn(label: Text('DERNIÈRE ACTIVITÉ')),
          DataColumn(label: Text('')),
        ],
        rows: users
            .map(
              (BackofficeUserAccount user) => DataRow(
                cells: <DataCell>[
                  DataCell(
                    SizedBox(width: 270, child: _UserIdentity(user: user)),
                    onTap: () => onOpen(user),
                  ),
                  DataCell(_RolePill(role: user.role)),
                  DataCell(_StatusPill(user: user)),
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        user.zoneIds
                            .map((id) => zoneNames[id] ?? id)
                            .join(', '),
                      ),
                    ),
                  ),
                  DataCell(Text(_formatDate(user.createdAt))),
                  DataCell(Text(_formatDate(user.lastActivityAt))),
                  DataCell(
                    IconButton(
                      tooltip: 'Voir le détail',
                      onPressed: () => onOpen(user),
                      icon: const Icon(Symbols.north_east_rounded, size: 19),
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _UsersMobileList extends StatelessWidget {
  const _UsersMobileList({required this.users, required this.onOpen});

  final List<BackofficeUserAccount> users;
  final ValueChanged<BackofficeUserAccount> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: users
          .map(
            (BackofficeUserAccount user) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: BackofficePalette.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onOpen(user),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: BackofficePalette.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(child: _UserIdentity(user: user)),
                            const Icon(
                              Symbols.chevron_right_rounded,
                              color: BackofficePalette.faint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _RolePill(role: user.role),
                            _StatusPill(user: user),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Symbols.history_rounded,
                              size: 16,
                              color: BackofficePalette.faint,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Dernière activité ${_formatDate(user.lastActivityAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});

  final BackofficeUserAccount user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _LargeAvatar(user: user, compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: BackofficePalette.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email.isEmpty ? user.id : user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.user, this.compact = false});

  final BackofficeUserAccount user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 38 : 48;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: BackofficeGradients.brand,
        shape: BoxShape.circle,
        boxShadow: compact ? const <BoxShadow>[] : BackofficeShadows.glow,
      ),
      child: Text(
        _initials(user.name),
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final BackofficeAccountRole role;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (role) {
      BackofficeAccountRole.administrator => BackofficePalette.primary,
      BackofficeAccountRole.manager => BackofficePalette.primaryStrong,
      BackofficeAccountRole.agent => BackofficePalette.success,
      BackofficeAccountRole.cabiniste => BackofficePalette.primaryStrong,
      BackofficeAccountRole.pending => BackofficePalette.warning,
      BackofficeAccountRole.operator => BackofficePalette.muted,
      BackofficeAccountRole.unknown => BackofficePalette.danger,
    };

    return _Pill(label: role.label, color: color);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.user});

  final BackofficeUserAccount user;

  @override
  Widget build(BuildContext context) {
    final Color color = user.hasRoleConflict
        ? BackofficePalette.danger
        : user.isPending
        ? BackofficePalette.warning
        : user.isActive
        ? BackofficePalette.success
        : BackofficePalette.danger;
    return _Pill(label: user.statusLabel, color: color, showDot: true);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.showDot = false});

  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        border: Border.all(color: color.withValues(alpha: .14)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showDot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersLoadingState extends StatelessWidget {
  const _UsersLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: BackofficeShadows.panel,
              ),
              child: const CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 14),
            Text(
              'Chargement des utilisateurs…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  const _UsersEmptyState({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Symbols.person_search_rounded,
                size: 28,
                color: BackofficePalette.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aucun utilisateur ne correspond aux filtres.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (totalCount == 0) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                'Le registre users ne contient actuellement aucun compte lisible.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsersErrorState extends StatelessWidget {
  const _UsersErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 90),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(26),
          decoration: backofficePanelDecoration(elevated: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Symbols.cloud_off_rounded,
                  size: 28,
                  color: BackofficePalette.danger,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Impossible de charger les utilisateurs.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersAccessDenied extends StatelessWidget {
  const _UsersAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 90),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(26),
          decoration: backofficePanelDecoration(elevated: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Symbols.lock_rounded,
                  size: 28,
                  color: BackofficePalette.warning,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Accès réservé à l’Administrateur.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AccountStatusFilter { all, active, inactive, pending }

extension on _AccountStatusFilter {
  String get label {
    switch (this) {
      case _AccountStatusFilter.all:
        return 'Tous les statuts';
      case _AccountStatusFilter.active:
        return 'Actifs';
      case _AccountStatusFilter.inactive:
        return 'Inactifs';
      case _AccountStatusFilter.pending:
        return 'En attente';
    }
  }

  bool matches(BackofficeUserAccount user) {
    switch (this) {
      case _AccountStatusFilter.all:
        return true;
      case _AccountStatusFilter.active:
        return user.isActive && !user.isPending;
      case _AccountStatusFilter.inactive:
        return !user.isActive && !user.isPending;
      case _AccountStatusFilter.pending:
        return user.isPending;
    }
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Non disponible';
  final DateTime local = value.toLocal();
  String two(int input) => input.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _fallback(String value) {
  return value.trim().isEmpty ? 'Non renseigné' : value.trim();
}

String _initials(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
