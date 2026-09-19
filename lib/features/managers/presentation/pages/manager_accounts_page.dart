import 'package:cabine_flow/backoffice/data/repositories/supabase_territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/data/repositories/supabase_staff_profile_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/staff_profile.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ManagerAccountsPage extends StatefulWidget {
  const ManagerAccountsPage({super.key});

  @override
  State<ManagerAccountsPage> createState() => _ManagerAccountsPageState();
}

class _ManagerAccountsPageState extends State<ManagerAccountsPage> {
  final SupabaseTerritoryRepository _repository = SupabaseTerritoryRepository();
  final SupabaseStaffProfileRepository _staffRepository =
      SupabaseStaffProfileRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<TerritoryManager>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _loadManagers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<TerritoryManager>> _loadManagers() async {
    try {
      await _repository.syncManagersFromStaffRegistry();
    } catch (_) {
      // La synchronisation est réservée aux comptes autorisés. La lecture du
      // registre existant reste suffisante si elle est refusée.
    }
    return _repository.fetchManagers();
  }

  Future<void> _reload() async {
    final Future<List<TerritoryManager>> next = _loadManagers();
    setState(() => _future = next);
    await next;
  }

  List<TerritoryManager> _filtered(List<TerritoryManager> managers) {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return managers;
    return managers.where((TerritoryManager manager) {
      return <String>[
        manager.displayName,
        manager.email,
        manager.phoneNumber,
        manager.secondaryPhone,
        manager.city,
      ].any((String value) => value.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  Future<void> _openManager(TerritoryManager manager) async {
    StaffProfile? personalProfile;
    try {
      personalProfile = await _staffRepository.fetchProfile(manager.firebaseUid);
    } catch (_) {
      personalProfile = null;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: IzyTelColors.background,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          minChildSize: .55,
          maxChildSize: .96,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    StaffProfileAvatar(
                      firebaseUid: manager.firebaseUid,
                      displayName: manager.displayName,
                      knownAvatarPath: manager.avatarPath,
                      size: 54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            manager.displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Compte Manager',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: IzyTelColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                IzyTelSurface(
                  padding: const EdgeInsets.all(IzyTelSpacing.md),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _statusChip(
                        manager.accountActive ? 'Compte actif' : 'Compte suspendu',
                        manager.accountActive
                            ? IzyTelColors.success
                            : IzyTelColors.error,
                      ),
                      _statusChip(
                        manager.isAvailable ? 'Disponible' : 'Indisponible',
                        manager.isAvailable
                            ? IzyTelColors.primary
                            : IzyTelColors.textMuted,
                      ),
                      if (personalProfile != null)
                        _statusChip(
                          personalProfile.verificationStatus.label,
                          personalProfile.verificationStatus ==
                                  StaffProfileVerificationStatus.verified
                              ? IzyTelColors.success
                              : IzyTelColors.warning,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                const IzyTelSectionHeader(title: 'Informations du compte'),
                const SizedBox(height: 8),
                IzyTelSurface(
                  padding: const EdgeInsets.all(IzyTelSpacing.md),
                  child: Column(
                    children: <Widget>[
                      _detail('Nom', personalProfile?.displayName ?? manager.displayName),
                      _detail('E-mail', _firstValue(personalProfile?.email, manager.email)),
                      _detail(
                        'Téléphone',
                        _firstValue(personalProfile?.phoneNumber, manager.phoneNumber),
                      ),
                      _detail(
                        'Téléphone secondaire',
                        _firstValue(
                          personalProfile?.secondaryPhone,
                          manager.secondaryPhone,
                        ),
                      ),
                      _detail('Ville', _firstValue(personalProfile?.city, manager.city)),
                      _detail(
                        'Adresse',
                        _firstValue(personalProfile?.address, manager.address),
                      ),
                      _detail(
                        'Contact d’urgence',
                        personalProfile == null
                            ? ''
                            : <String>[
                                personalProfile.emergencyContactName,
                                personalProfile.emergencyContactPhone,
                              ].where((String value) => value.trim().isNotEmpty).join(' · '),
                      ),
                      _detail(
                        'Dernière activité',
                        _formatDate(
                          personalProfile?.lastActivityAt ?? manager.lastActivityAt,
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
        surfaceTintColor: Colors.transparent,
        title: const Text('Managers'),
      ),
      body: FutureBuilder<List<TerritoryManager>>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<TerritoryManager>> snapshot,
        ) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return _ManagerLoadError(onRetry: _reload);
          }

          final List<TerritoryManager> all = snapshot.data!;
          final List<TerritoryManager> managers = _filtered(all);
          final int active = all
              .where((TerritoryManager manager) => manager.accountActive)
              .length;
          final int available = all
              .where((TerritoryManager manager) => manager.canReceiveZone)
              .length;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: <Widget>[
                const IzyTelPageHeader(
                  title: 'Comptes Managers',
                  subtitle:
                      'Consulte les informations, le statut et les coordonnées de chaque Manager.',
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        label: 'Managers',
                        value: '${all.length}',
                        icon: Symbols.supervisor_account_rounded,
                        color: IzyTelColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Actifs',
                        value: '$active',
                        icon: Symbols.verified_rounded,
                        color: IzyTelColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Disponibles',
                        value: '$available',
                        icon: Symbols.task_alt_rounded,
                        color: IzyTelColors.moov,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                TextField(
                  controller: _searchController,
                  onChanged: (String value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Symbols.search_rounded),
                    hintText: 'Rechercher un Manager',
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                if (managers.isEmpty)
                  const IzyTelSurface(
                    padding: EdgeInsets.all(IzyTelSpacing.lg),
                    child: Text('Aucun Manager ne correspond à cette recherche.'),
                  )
                else
                  ...managers.map(
                    (TerritoryManager manager) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: IzyTelSurface(
                        onTap: () => _openManager(manager),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            StaffProfileAvatar(
                              firebaseUid: manager.firebaseUid,
                              displayName: manager.displayName,
                              knownAvatarPath: manager.avatarPath,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    manager.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    manager.contactLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: IzyTelColors.textSecondary),
                                  ),
                                  if (manager.city.trim().isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 2),
                                    Text(
                                      manager.city,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: IzyTelColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              manager.accountActive
                                  ? Symbols.verified_rounded
                                  : Symbols.block_rounded,
                              color: manager.accountActive
                                  ? IzyTelColors.success
                                  : IzyTelColors.error,
                            ),
                            const Icon(
                              Symbols.chevron_right_rounded,
                              color: IzyTelColors.textMuted,
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _detail(
    String label,
    String value, {
    bool showDivider = true,
  }) {
    final String display = value.trim().isEmpty ? 'Non renseigné' : value.trim();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 132,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  display,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  String _firstValue(String? first, String second) {
    final String primary = first?.trim() ?? '';
    if (primary.isNotEmpty) return primary;
    return second.trim();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Non renseignée';
    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} à $hour:$minute';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: IzyTelColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ManagerLoadError extends StatelessWidget {
  const _ManagerLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Symbols.cloud_off_rounded,
              size: 40,
              color: IzyTelColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text('Impossible de charger les comptes Managers.'),
            const SizedBox(height: 12),
            FilledButton.icon(
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
