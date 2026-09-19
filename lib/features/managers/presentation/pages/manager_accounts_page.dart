import 'package:cabine_flow/backoffice/data/repositories/supabase_territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/features/team/presentation/pages/team_member_detail_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ManagerAccountsPage extends StatefulWidget {
  const ManagerAccountsPage({super.key, required this.viewer});

  final AppUser viewer;

  @override
  State<ManagerAccountsPage> createState() => _ManagerAccountsPageState();
}

class _ManagerAccountsPageState extends State<ManagerAccountsPage> {
  final SupabaseTerritoryRepository _repository = SupabaseTerritoryRepository();
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeamMemberDetailPage(
          viewer: widget.viewer,
          actorType: 'manager',
          actorId: manager.firebaseUid,
          fallbackName: manager.displayName,
        ),
      ),
    );
    if (mounted) await _reload();
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
