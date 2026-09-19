import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/backoffice/domain/repositories/territory_repository.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/team/presentation/pages/team_member_detail_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

// ManagerAvatarRepository : ancienne façade photo remplacée par StaffProfileAvatar.
enum _ManagerScope { all, available, unavailable, suspended, withoutZone }

class BackofficeManagersPage extends StatefulWidget {
  const BackofficeManagersPage({
    super.key,
    required this.user,
    required this.territoryRepository,
    required this.agentRepository,
  });

  final AppUser user;
  final TerritoryRepository territoryRepository;
  final AgentRepository agentRepository;

  @override
  State<BackofficeManagersPage> createState() => _BackofficeManagersPageState();
}

class _BackofficeManagersPageState extends State<BackofficeManagersPage> {
  final TextEditingController _searchController = TextEditingController();
  _ManagerScope _scope = _ManagerScope.all;
  String _query = '';
  bool _loading = true;
  bool _registrySynced = false;
  Object? _error;
  List<TerritoryManager> _managers = const <TerritoryManager>[];
  List<TerritoryZone> _zones = const <TerritoryZone>[];
  List<AgentDirectoryEntry> _agents = const <AgentDirectoryEntry>[];

  bool get _canManage => widget.user.role == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    _load(syncRegistry: _canManage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool syncRegistry = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (syncRegistry && !_registrySynced && _canManage) {
        await widget.territoryRepository.syncManagersFromStaffRegistry();
        _registrySynced = true;
      }
      final List<Object> data = await Future.wait<Object>(<Future<Object>>[
        widget.territoryRepository.fetchManagers(),
        widget.territoryRepository.fetchZones(),
        widget.agentRepository.watchAgents().first,
      ]);
      if (!mounted) return;
      setState(() {
        _managers = data[0] as List<TerritoryManager>;
        _zones = data[1] as List<TerritoryZone>;
        _agents = data[2] as List<AgentDirectoryEntry>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return BackofficeEmptyState(
        icon: Symbols.cloud_off_rounded,
        title: 'Managers indisponibles',
        message: 'Le registre territorial des Managers ne peut pas être chargé pour le moment.',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Symbols.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      );
    }

    final Map<String, TerritoryZone> zoneById = <String, TerritoryZone>{
      for (final TerritoryZone zone in _zones) zone.id: zone,
    };
    final List<TerritoryManager> visible = _filtered();
    final int activeAccounts = _managers.where((TerritoryManager manager) => manager.accountActive).length;
    final int availableManagers = _managers.where((TerritoryManager manager) => manager.canReceiveZone).length;
    final int assignedZones = _zones.where((TerritoryZone zone) => zone.managerId != null).length;
    final int supervisedAgents = _agents.where((AgentDirectoryEntry agent) {
      final List<String> zoneIds = agent.profile?.zoneIds ?? const <String>[];
      return zoneIds.any((String zoneId) => zoneById[zoneId]?.managerId != null);
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BackofficePageIntro(
          eyebrow: 'Équipe / Managers',
          title: 'Comptes Managers et supervision territoriale',
          description: _canManage
              ? 'Gère les Managers IzyTel, leurs coordonnées, leurs zones et les Agents rattachés à leurs périmètres.'
              : 'Consulte les Managers, leurs zones et les Agents rattachés aux périmètres supervisés.',
          icon: Symbols.supervisor_account_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _load,
                icon: const Icon(Symbols.refresh_rounded),
              ),
              if (_canManage) ...<Widget>[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: _syncManagers,
                  icon: const Icon(Symbols.sync_rounded),
                  label: const Text('Synchroniser le registre'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _metrics(
          total: _managers.length,
          activeAccounts: activeAccounts,
          available: availableManagers,
          assignedZones: assignedZones,
          supervisedAgents: supervisedAgents,
        ),
        const SizedBox(height: 14),
        _filters(),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const BackofficeEmptyState(
            icon: Symbols.person_search_rounded,
            title: 'Aucun Manager dans cette vue',
            message: 'Modifie la recherche ou les filtres pour afficher d’autres Managers.',
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth >= 980) {
                return _desktopTable(visible);
              }
              return Column(
                children: visible
                    .map(
                      (TerritoryManager manager) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _mobileCard(manager),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }

  Widget _metrics({
    required int total,
    required int activeAccounts,
    required int available,
    required int assignedZones,
    required int supervisedAgents,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1180 ? 5 : constraints.maxWidth >= 760 ? 3 : 2;
        const double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(
            label: 'Managers',
            value: '$total',
            caption: '$activeAccounts comptes actifs',
            icon: Symbols.supervisor_account_rounded,
          ),
          BackofficeMetricCard(
            label: 'Disponibles',
            value: '$available',
            caption: 'attribuables aux zones',
            icon: Symbols.task_alt_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Zones attribuées',
            value: '$assignedZones',
            caption: 'avec Manager responsable',
            icon: Symbols.map_rounded,
            emphasis: BackofficePalette.primaryStrong,
          ),
          BackofficeMetricCard(
            label: 'Agents supervisés',
            value: '$supervisedAgents',
            caption: 'rattachés aux zones gérées',
            icon: Symbols.groups_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'À attribuer',
            value: '${_zones.where((TerritoryZone zone) => zone.managerId == null).length}',
            caption: 'zones sans Manager',
            icon: Symbols.assignment_late_rounded,
            emphasis: _zones.any((TerritoryZone zone) => zone.managerId == null)
                ? BackofficePalette.warning
                : BackofficePalette.success,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((Widget card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Nom, téléphone, e-mail, ville ou zone',
              prefixIcon: Icon(Symbols.search_rounded),
            ),
          );
          final Widget scope = DropdownButtonFormField<_ManagerScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: const <DropdownMenuItem<_ManagerScope>>[
              DropdownMenuItem(value: _ManagerScope.all, child: Text('Tous')),
              DropdownMenuItem(value: _ManagerScope.available, child: Text('Disponibles')),
              DropdownMenuItem(value: _ManagerScope.unavailable, child: Text('Indisponibles')),
              DropdownMenuItem(value: _ManagerScope.suspended, child: Text('Comptes suspendus')),
              DropdownMenuItem(value: _ManagerScope.withoutZone, child: Text('Sans zone')),
            ],
            onChanged: (_ManagerScope? value) {
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

  List<TerritoryManager> _filtered() {
    final String query = _query.trim().toLowerCase();
    final List<TerritoryManager> result = _managers.where((TerritoryManager manager) {
      final List<TerritoryZone> zones = _zones
          .where((TerritoryZone zone) => zone.managerId == manager.firebaseUid)
          .toList(growable: false);
      final bool inScope = switch (_scope) {
        _ManagerScope.all => true,
        _ManagerScope.available => manager.canReceiveZone,
        _ManagerScope.unavailable => manager.accountActive && !manager.isAvailable,
        _ManagerScope.suspended => !manager.accountActive,
        _ManagerScope.withoutZone => zones.isEmpty,
      };
      if (!inScope) return false;
      if (query.isEmpty) {
        return true;
      }
      final String zoneNames = zones.map((TerritoryZone zone) => zone.displayLabel).join(' ');
      return <String>[
        manager.displayName,
        manager.email,
        manager.phoneNumber,
        manager.secondaryPhone,
        manager.city,
        zoneNames,
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
    result.sort((TerritoryManager a, TerritoryManager b) {
      if (a.canReceiveZone != b.canReceiveZone) return a.canReceiveZone ? -1 : 1;
      if (a.accountActive != b.accountActive) return a.accountActive ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return result;
  }

  Widget _desktopTable(List<TerritoryManager> managers) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'MANAGER', flex: 4),
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'ZONES', flex: 4),
        BackofficeTableColumnSpec(label: 'AGENTS', flex: 2),
        BackofficeTableColumnSpec(label: 'ACTIVITÉ', flex: 3),
        BackofficeTableColumnSpec(label: 'ACTION', flex: 2, alignment: Alignment.centerRight),
      ],
      rows: managers.map((TerritoryManager manager) {
        final List<TerritoryZone> zones = _zonesForManager(manager);
        final int agents = _agentsForManager(manager).length;
        return BackofficeDesktopTableRow(
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(
              flex: 4,
              child: Row(
                children: <Widget>[
                  _ManagerAvatar(manager: manager, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _titleSubtitle(
                      manager.displayName,
                      manager.contactLabel,
                    ),
                  ),
                ],
              ),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BackofficeStatusBadge(
                      label: manager.accountActive ? 'Compte actif' : 'Compte suspendu',
                      color: manager.accountActive ? BackofficePalette.primaryStrong : BackofficePalette.danger,
                    ),
                    const SizedBox(height: 5),
                    BackofficeStatusBadge(
                      label: manager.canReceiveZone ? 'Disponible' : 'Indisponible',
                      color: manager.canReceiveZone ? BackofficePalette.success : BackofficePalette.muted,
                    ),
                  ],
                ),
              ),
            ),
            BackofficeTableCellSpec(
              flex: 4,
              child: Text(
                zones.isEmpty
                    ? 'Aucune zone'
                    : zones.map((TerritoryZone zone) => zone.displayLabel).join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              child: Text('$agents'),
            ),
            BackofficeTableCellSpec(
              flex: 3,
              child: Text(_formatDate(manager.lastActivityAt ?? manager.updatedAt)),
            ),
            BackofficeTableCellSpec(
              flex: 2,
              alignment: Alignment.centerRight,
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => _openManager(manager),
                  child: Text(_canManage ? 'Voir / gérer le compte' : 'Voir le compte'),
                ),
              ),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(TerritoryManager manager) {
    final List<TerritoryZone> zones = _zonesForManager(manager);
    final int agents = _agentsForManager(manager).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ManagerAvatar(manager: manager, size: 46),
              const SizedBox(width: 10),
              Expanded(child: _titleSubtitle(manager.displayName, manager.contactLabel)),
              BackofficeStatusBadge(
                label: !manager.accountActive ? 'Suspendu' : manager.isAvailable ? 'Disponible' : 'Indisponible',
                color: !manager.accountActive ? BackofficePalette.danger : manager.isAvailable ? BackofficePalette.success : BackofficePalette.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            zones.isEmpty
                ? 'Aucune zone attribuée'
                : zones.map((TerritoryZone zone) => zone.displayLabel).join(' • '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text('$agents Agent${agents > 1 ? 's' : ''} supervisé${agents > 1 ? 's' : ''}'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => _openManager(manager),
              child: Text(_canManage ? 'Voir / gérer le compte' : 'Voir le compte'),
            ),
          ),
        ],
      ),
    );
  }

  List<TerritoryZone> _zonesForManager(TerritoryManager manager) {
    return _zones
        .where((TerritoryZone zone) => zone.managerId == manager.firebaseUid)
        .toList(growable: false);
  }

  List<AgentDirectoryEntry> _agentsForManager(TerritoryManager manager) {
    final Set<String> managedZoneIds = _zonesForManager(manager)
        .map((TerritoryZone zone) => zone.id)
        .toSet();
    return _agents.where((AgentDirectoryEntry agent) {
      final List<String> zoneIds = agent.profile?.zoneIds ?? const <String>[];
      return zoneIds.any(managedZoneIds.contains);
    }).toList(growable: false);
  }

  Future<void> _syncManagers() async {
    try {
      await widget.territoryRepository.syncManagersFromStaffRegistry();
      _registrySynced = true;
      await _load();
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Registre Managers synchronisé.');
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, error.toString());
    }
  }

  Future<void> _openManager(TerritoryManager manager) async {
    if (!_canManage) {
      await _showManagerDetails(manager);
      return;
    }

    final TextEditingController name = TextEditingController(text: manager.displayName);
    final TextEditingController email = TextEditingController(text: manager.email);
    final TextEditingController phone = TextEditingController(text: manager.phoneNumber);
    final TextEditingController secondary = TextEditingController(text: manager.secondaryPhone);
    final TextEditingController city = TextEditingController(text: manager.city);
    final TextEditingController address = TextEditingController(text: manager.address);
    final TextEditingController notes = TextEditingController(text: manager.notes);
    final SupabaseStaffProfileRepository staffRepository =
        SupabaseStaffProfileRepository();
    StaffProfile? personalProfile;
    try {
      personalProfile = await staffRepository.fetchProfile(manager.firebaseUid);
    } catch (_) {
      personalProfile = null;
    }
    if (!mounted) {
      return;
    }
    StaffProfileVerificationStatus reviewStatus =
        personalProfile?.verificationStatus ??
        StaffProfileVerificationStatus.incomplete;
    final TextEditingController reviewNote = TextEditingController(
      text: personalProfile?.verificationNote ?? '',
    );
    bool available = manager.isAvailable;
    bool saving = false;
    final List<TerritoryZone> zones = _zonesForManager(manager);
    final List<AgentDirectoryEntry> agents = _agentsForManager(manager);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: Row(
              children: <Widget>[
                _ManagerAvatar(manager: manager, size: 46),
                const SizedBox(width: 12),
                Expanded(child: Text('Gérer ${manager.displayName}')),
              ],
            ),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _adaptiveFields(<Widget>[
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom affiché')),
                      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
                    ]),
                    const SizedBox(height: 10),
                    _adaptiveFields(<Widget>[
                      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone principal')),
                      TextField(controller: secondary, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone secondaire')),
                    ]),
                    const SizedBox(height: 10),
                    _adaptiveFields(<Widget>[
                      TextField(controller: city, decoration: const InputDecoration(labelText: 'Ville')),
                      TextField(controller: address, decoration: const InputDecoration(labelText: 'Adresse')),
                    ]),
                    const SizedBox(height: 14),
                    _managerPersonalProfilePanel(
                      manager: manager,
                      profile: personalProfile,
                      repository: staffRepository,
                      reviewStatus: reviewStatus,
                      reviewNote: reviewNote,
                      onReviewStatusChanged:
                          (StaffProfileVerificationStatus value) {
                        setDialogState(() => reviewStatus = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notes opérationnelles'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Disponible pour l’attribution des zones'),
                      subtitle: Text(
                        !manager.accountActive
                            ? 'Le compte est suspendu dans Utilisateurs : aucune zone ne peut lui être attribuée.'
                            : available
                                ? 'Ce Manager peut recevoir de nouvelles zones.'
                                : 'Ce Manager reste visible mais ne peut pas recevoir de nouvelles zones.',
                      ),
                      value: available,
                      onChanged: manager.accountActive
                          ? (bool value) => setDialogState(() => available = value)
                          : null,
                    ),
                    const Divider(height: 28),
                    _sectionTitle('Zones supervisées'),
                    const SizedBox(height: 8),
                    if (zones.isEmpty)
                      const Text('Aucune zone attribuée. L’attribution se fait depuis Zones & capacités.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: zones.map((TerritoryZone zone) => Chip(label: Text(zone.displayLabel))).toList(growable: false),
                      ),
                    const SizedBox(height: 18),
                    _sectionTitle('Agents des zones'),
                    const SizedBox(height: 8),
                    if (agents.isEmpty)
                      const Text('Aucun Agent rattaché aux zones de ce Manager.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: agents.map((AgentDirectoryEntry agent) => Chip(label: Text(agent.name))).toList(growable: false),
                      ),
                    const SizedBox(height: 18),
                    _sectionTitle('Historique territorial'),
                    const SizedBox(height: 8),
                    _auditHistory(manager.firebaseUid),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.of(dialogContext).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => TeamMemberDetailPage(
                              viewer: widget.user,
                              actorType: 'manager',
                              actorId: manager.firebaseUid,
                              fallbackName: manager.displayName,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Symbols.monitoring_rounded),
                label: const Text('Identité, zone et gains'),
              ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().length < 2) {
                          IzyTelFeedback.error(dialogContext, 'Renseigne le nom du Manager.');
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await widget.territoryRepository.saveManagerProfile(
                            manager: manager,
                            update: TerritoryManagerUpdate(
                              displayName: name.text.trim(),
                              email: email.text.trim(),
                              phoneNumber: phone.text.trim(),
                              secondaryPhone: secondary.text.trim(),
                              city: city.text.trim(),
                              address: address.text.trim(),
                              notes: notes.text.trim(),
                              isAvailable: available,
                            ),
                          );
                          if (personalProfile != null &&
                              (reviewStatus != personalProfile!.verificationStatus ||
                                  reviewNote.text.trim() !=
                                      (personalProfile!.verificationNote ?? ''))) {
                            personalProfile = await staffRepository.reviewProfile(
                              firebaseUid: manager.firebaseUid,
                              status: reviewStatus,
                              note: reviewNote.text.trim(),
                            );
                          }
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                          await _load();
                          if (!mounted) {
                            return;
                          }
                          IzyTelFeedback.success(this.context, 'Profil Manager mis à jour.');
                        } catch (error) {
                          if (!dialogContext.mounted) {
                            return;
                          }
                          IzyTelFeedback.error(dialogContext, error.toString());
                          setDialogState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    name.dispose();
    email.dispose();
    phone.dispose();
    secondary.dispose();
    city.dispose();
    address.dispose();
    notes.dispose();
    reviewNote.dispose();
  }

  Widget _managerPersonalProfilePanel({
    required TerritoryManager manager,
    required StaffProfile? profile,
    required SupabaseStaffProfileRepository repository,
    required StaffProfileVerificationStatus reviewStatus,
    required TextEditingController reviewNote,
    required ValueChanged<StaffProfileVerificationStatus>
        onReviewStatusChanged,
  }) {
    if (profile == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BackofficePalette.surfaceAlt,
          border: Border.all(color: BackofficePalette.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Dossier personnel non renseigné. Le Manager peut le compléter depuis « Mon profil ».',
        ),
      );
    }

    final String birthDate = profile.dateOfBirth == null
        ? 'Non renseignée'
        : _formatDateOnly(profile.dateOfBirth!);
    final String emergency = profile.emergencyContactName.trim().isEmpty &&
            profile.emergencyContactPhone.trim().isEmpty
        ? 'Non renseigné'
        : '${profile.emergencyContactName} • ${profile.emergencyContactPhone}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BackofficePalette.primarySoft.withValues(alpha: .45),
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Symbols.contact_page_rounded,
                color: BackofficePalette.primaryStrong,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DOSSIER PERSONNEL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BackofficePalette.primaryStrong,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Date de naissance : $birthDate'),
          Text(
            'Contact d’urgence : $emergency',
          ),
          Text(
            'Dernière activité : ${_formatDate(profile.lastActivityAt ?? profile.updatedAt)}',
          ),
          if (profile.hasIdentityDocument) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openStaffIdentityDocument(
                  manager.firebaseUid,
                  repository,
                ),
                icon: const Icon(Symbols.id_card_rounded),
                label: const Text('Voir la pièce d’identité'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<StaffProfileVerificationStatus>(
            initialValue: reviewStatus,
            decoration: const InputDecoration(labelText: 'Vérification'),
            items: StaffProfileVerificationStatus.values
                .map(
                  (StaffProfileVerificationStatus value) =>
                      DropdownMenuItem<StaffProfileVerificationStatus>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (StaffProfileVerificationStatus? value) {
              if (value != null) {
                onReviewStatusChanged(value);
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: reviewNote,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Note de vérification',
              hintText: 'Motif de validation ou correction demandée',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStaffIdentityDocument(
    String firebaseUid,
    SupabaseStaffProfileRepository repository,
  ) async {
    try {
      final String? url = await repository.fetchIdentityDocumentUrl(firebaseUid);
      if (!mounted) {
        return;
      }
      if (url == null || url.isEmpty) {
        IzyTelFeedback.error(context, 'Pièce d’identité indisponible.');
        return;
      }
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!opened) {
        IzyTelFeedback.error(context, 'Impossible d’ouvrir la pièce d’identité.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      IzyTelFeedback.error(context, error.toString());
    }
  }

  String _formatDateOnly(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  Future<void> _showManagerDetails(TerritoryManager manager) async {
    final List<TerritoryZone> zones = _zonesForManager(manager);
    final List<AgentDirectoryEntry> agents = _agentsForManager(manager);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: <Widget>[
            _ManagerAvatar(manager: manager, size: 46),
            const SizedBox(width: 12),
            Expanded(child: Text(manager.displayName)),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _detail('Statut du compte', manager.accountActive ? 'Actif' : 'Suspendu'),
                _detail('Disponibilité territoriale', manager.canReceiveZone ? 'Disponible' : 'Indisponible'),
                _detail('Téléphone', manager.phoneNumber.isEmpty ? 'Non renseigné' : manager.phoneNumber),
                _detail('E-mail', manager.email.isEmpty ? 'Non renseigné' : manager.email),
                _detail('Ville', manager.city.isEmpty ? 'Non renseignée' : manager.city),
                _detail('Zones', zones.isEmpty ? 'Aucune zone' : zones.map((TerritoryZone zone) => zone.displayLabel).join(' • ')),
                _detail('Agents supervisés', agents.isEmpty ? 'Aucun Agent' : agents.map((AgentDirectoryEntry agent) => agent.name).join(' • ')),
                _detail('Dernière activité', _formatDate(manager.lastActivityAt ?? manager.updatedAt)),
                _sectionTitle('Historique territorial'),
                const SizedBox(height: 8),
                _auditHistory(manager.firebaseUid),
              ],
            ),
          ),
        ),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Widget _auditHistory(String managerId) {
    return FutureBuilder<List<TerritoryAuditEvent>>(
      future: widget.territoryRepository.fetchAuditEvents(
        entityType: 'manager',
        entityId: managerId,
        limit: 8,
      ),
      builder: (BuildContext context, AsyncSnapshot<List<TerritoryAuditEvent>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return Text('Historique indisponible.', style: Theme.of(context).textTheme.bodySmall);
        }
        final List<TerritoryAuditEvent> events = snapshot.data ?? const <TerritoryAuditEvent>[];
        if (events.isEmpty) {
          return Text('Aucune modification territoriale enregistrée.', style: Theme.of(context).textTheme.bodySmall);
        }
        return Column(
          children: events.map((TerritoryAuditEvent event) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Symbols.history_rounded, size: 18, color: BackofficePalette.primaryStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${event.actionLabel} • ${event.actorName} • ${_formatDate(event.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _adaptiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: <Widget>[
              for (int index = 0; index < fields.length; index += 1) ...<Widget>[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: <Widget>[
            for (int index = 0; index < fields.length; index += 1) ...<Widget>[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _titleSubtitle(String title, String subtitle) {
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

  Widget _sectionTitle(String label) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: BackofficePalette.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle(label),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Non disponible';
    final DateTime local = value.toLocal();
    String two(int input) => input.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _ManagerAvatar extends StatelessWidget {
  const _ManagerAvatar({required this.manager, required this.size});

  final TerritoryManager manager;
  final double size;

  @override
  Widget build(BuildContext context) {
    return StaffProfileAvatar(
      firebaseUid: manager.firebaseUid,
      displayName: manager.displayName,
      knownAvatarPath: manager.avatarPath,
      size: size,
    );
  }
}
