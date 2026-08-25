import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/presentation/pages/offer_editor_page.dart';
import 'package:cabine_flow/features/offers/presentation/view_models/offer_management_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

class OfferManagementPage extends StatefulWidget {
  const OfferManagementPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AdminOfferRepository repository;

  @override
  State<OfferManagementPage> createState() => _OfferManagementPageState();
}

class _OfferManagementPageState extends State<OfferManagementPage> {
  late final OfferManagementViewModel _viewModel;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _viewModel = OfferManagementViewModel(repository: widget.repository)
      ..start();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openEditor([AdminOffer? offer]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: offer == null,
        builder: (BuildContext context) {
          return OfferEditorPage(repository: widget.repository, offer: offer);
        },
      ),
    );
  }

  Future<void> _toggleStatus(AdminOffer offer) async {
    final bool target = !offer.isActive;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Text(target ? 'Réactiver l’offre ?' : 'Suspendre l’offre ?'),
          content: Text(
            target
                ? 'Cette offre redeviendra visible pour les nouvelles commandes.'
                : 'Cette offre disparaîtra immédiatement des nouvelles commandes, sans modifier l’historique existant.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: target ? AppColors.primary : AppColors.error,
              ),
              child: Text(target ? 'Réactiver' : 'Suspendre'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    final bool success = await _viewModel.setOfferActive(offer, target);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? target
                      ? 'Offre réactivée.'
                      : 'Offre suspendue.'
                : _viewModel.errorMessage ?? 'Action impossible.',
          ),
        ),
      );
  }

  void _clearAll() {
    _searchController.clear();
    _viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: const Text('Gestion des offres'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary.withAlpha(35),
              child: Text(
                _initial(widget.user.name),
                style: const TextStyle(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (BuildContext context, Widget? child) {
            final List<AdminOffer> offers = _viewModel.filteredOffers;
            return RefreshIndicator(
              onRefresh: () async => _viewModel.start(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _SummaryHeader(
                    total: _viewModel.offers.length,
                    active: _viewModel.activeCount,
                    suspended: _viewModel.suspendedCount,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ajouter une offre'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _searchController,
                    onChanged: _viewModel.updateSearch,
                    style: const TextStyle(color: AppColors.onBackground),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une offre…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _viewModel.searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _viewModel.updateSearch('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FilterSection(
                    title: 'Réseau',
                    children: MobileNetwork.values
                        .map((MobileNetwork network) {
                          return _FilterChip(
                            label: _networkLabel(network),
                            color: _networkColor(network),
                            selected: _viewModel.networkFilter == network,
                            onPressed: () =>
                                _viewModel.setNetworkFilter(network),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  _FilterSection(
                    title: 'Service',
                    children: OfferService.values
                        .map((OfferService service) {
                          return _FilterChip(
                            label: service.label,
                            color: AppColors.primary,
                            selected: _viewModel.serviceFilter == service,
                            onPressed: () =>
                                _viewModel.setServiceFilter(service),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  _FilterSection(
                    title: 'Statut',
                    children: [
                      _FilterChip(
                        label: 'Toutes',
                        color: AppColors.primary,
                        selected:
                            _viewModel.statusFilter == OfferStatusFilter.all,
                        onPressed: () =>
                            _viewModel.setStatusFilter(OfferStatusFilter.all),
                      ),
                      _FilterChip(
                        label: 'Actives',
                        color: AppColors.success,
                        selected:
                            _viewModel.statusFilter == OfferStatusFilter.active,
                        onPressed: () => _viewModel.setStatusFilter(
                          OfferStatusFilter.active,
                        ),
                      ),
                      _FilterChip(
                        label: 'Suspendues',
                        color: AppColors.error,
                        selected:
                            _viewModel.statusFilter ==
                            OfferStatusFilter.suspended,
                        onPressed: () => _viewModel.setStatusFilter(
                          OfferStatusFilter.suspended,
                        ),
                      ),
                    ],
                  ),
                  if (_viewModel.searchQuery.isNotEmpty ||
                      _viewModel.networkFilter != null ||
                      _viewModel.serviceFilter != null ||
                      _viewModel.statusFilter != OfferStatusFilter.all) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 18,
                        ),
                        label: const Text('Effacer les filtres'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_viewModel.isLoading && _viewModel.offers.isEmpty)
                    const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.errorMessage != null &&
                      _viewModel.offers.isEmpty)
                    _ErrorState(
                      message: _viewModel.errorMessage!,
                      onRetry: _viewModel.start,
                    )
                  else if (offers.isEmpty)
                    const _EmptyState()
                  else ...[
                    Text(
                      '${offers.length} offre${offers.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...offers.map((AdminOffer offer) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfferCard(
                          offer: offer,
                          isBusy: _viewModel.isBusy(offer.id),
                          onEdit: () => _openEditor(offer),
                          onToggleStatus: () => _toggleStatus(offer),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.active,
    required this.suspended,
  });

  final int total;
  final int active;
  final int suspended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'Total',
              value: total,
              color: AppColors.primaryContainer,
            ),
          ),
          Expanded(
            child: _Metric(
              label: 'Actives',
              value: active,
              color: AppColors.success,
            ),
          ),
          Expanded(
            child: _Metric(
              label: 'Suspendues',
              value: suspended,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$title :',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: children)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(35) : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.onBackground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.isBusy,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final AdminOffer offer;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final Color networkColor = _networkColor(offer.network);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: networkColor),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 12, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: networkColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.signal_cellular_alt_rounded,
                            color: networkColor,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _networkLabel(offer.network),
                            style: TextStyle(
                              color: networkColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(isActive: offer.isActive),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  offer.title,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _subtitle(offer),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prix',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCfa(offer.sellingPrice),
                            style: const TextStyle(
                              color: AppColors.onBackground,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: offer.isActive ? 'Suspendre' : 'Réactiver',
                      onPressed: isBusy ? null : onToggleStatus,
                      icon: isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              offer.isActive
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              color: offer.isActive
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                    ),
                    IconButton(
                      tooltip: 'Modifier',
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        isActive ? 'Active' : 'Suspendue',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.local_offer_outlined,
      title: 'Aucune offre',
      message: 'Aucune offre ne correspond aux filtres sélectionnés.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.cloud_off_rounded,
      title: 'Catalogue indisponible',
      message: message,
      action: TextButton(onPressed: onRetry, child: const Text('Réessayer')),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

String _initial(String value) {
  final String cleaned = value.trim();
  return cleaned.isEmpty ? '?' : cleaned.substring(0, 1).toUpperCase();
}

String _networkLabel(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'Orange';
    case MobileNetwork.mtn:
      return 'MTN';
    case MobileNetwork.moov:
      return 'Moov';
  }
}

Color _networkColor(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return AppColors.orange;
    case MobileNetwork.mtn:
      return AppColors.mtn;
    case MobileNetwork.moov:
      return AppColors.primaryContainer;
  }
}

String _subtitle(AdminOffer offer) {
  final List<String> parts = <String>[
    if (offer.volume != null) offer.volume!,
    if (offer.validity != null) 'Validité ${offer.validity}',
    if (offer.minutes != null) '${offer.minutes} appels',
  ];
  if (parts.isNotEmpty) return parts.join(' • ');
  return offer.service.label;
}
