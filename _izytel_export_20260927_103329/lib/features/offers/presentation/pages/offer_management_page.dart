import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/presentation/pages/offer_editor_page.dart';
import 'package:cabine_flow/features/offers/presentation/view_models/offer_management_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
          title: Text(target ? 'Réactiver l’offre ?' : 'Suspendre l’offre ?'),
          content: Text(
            target
                ? 'Cette offre redeviendra visible pour les nouvelles commandes.'
                : 'Cette offre disparaîtra des nouvelles commandes sans modifier l’historique existant.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: target
                    ? IzyTelColors.primary
                    : IzyTelColors.error,
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

    final String message = success
        ? (target ? 'Offre réactivée.' : 'Offre suspendue.')
        : _viewModel.errorMessage ?? 'Action impossible.';
    if (success) {
      IzyTelFeedback.success(context, message);
    } else {
      IzyTelFeedback.error(context, message);
    }
  }

  void _clearAll() {
    _searchController.clear();
    _viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: IzyTelColors.background,
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (BuildContext context, Widget? child) {
            final List<AdminOffer> offers = _viewModel.filteredOffers;
            final bool hasFilters =
                _viewModel.searchQuery.isNotEmpty ||
                _viewModel.networkFilter != null ||
                _viewModel.serviceFilter != null ||
                _viewModel.statusFilter != OfferStatusFilter.all;

            return RefreshIndicator(
              onRefresh: () async => _viewModel.start(),
              color: IzyTelColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  IzyTelPageHeader(
                    title: 'Offres',
                    subtitle:
                        'Gère le catalogue, les tarifs et la disponibilité côté client.',
                    actions: [IzyTelAvatar(name: widget.user.name, size: 42)],
                  ),
                  const SizedBox(height: IzyTelSpacing.lg),
                  _SummaryHeader(
                    total: _viewModel.offers.length,
                    active: _viewModel.activeCount,
                    suspended: _viewModel.suspendedCount,
                  ),
                  const SizedBox(height: IzyTelSpacing.md),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Symbols.add_rounded, size: 20),
                      label: const Text('Ajouter une offre'),
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.md),
                  IzyTelSearchField(
                    controller: _searchController,
                    hintText: 'Nom, volume, validité…',
                    onChanged: _viewModel.updateSearch,
                  ),
                  const SizedBox(height: IzyTelSpacing.sm),
                  _NetworkFilters(viewModel: _viewModel),
                  const SizedBox(height: 8),
                  _ServiceStatusFilters(viewModel: _viewModel),
                  const SizedBox(height: IzyTelSpacing.lg),
                  IzyTelSectionHeader(
                    title:
                        '${offers.length} offre${offers.length > 1 ? 's' : ''}',
                    actionLabel: hasFilters ? 'Réinitialiser' : null,
                    onAction: hasFilters ? _clearAll : null,
                  ),
                  const SizedBox(height: 8),
                  if (_viewModel.isLoading && _viewModel.offers.isEmpty)
                    const SizedBox(
                      height: 280,
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
                  else
                    ...offers.map(
                      (AdminOffer offer) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OfferCard(
                          offer: offer,
                          isBusy: _viewModel.isBusy(offer.id),
                          onEdit: () => _openEditor(offer),
                          onToggleStatus: () => _toggleStatus(offer),
                        ),
                      ),
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
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Total',
            value: total,
            color: IzyTelColors.primary,
            softColor: IzyTelColors.primarySoft,
            icon: Symbols.inventory_2_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'Actives',
            value: active,
            color: IzyTelColors.success,
            softColor: IzyTelColors.successSoft,
            icon: Symbols.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'Suspendues',
            value: suspended,
            color: IzyTelColors.error,
            softColor: IzyTelColors.errorSoft,
            icon: Symbols.pause_circle_rounded,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    required this.softColor,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final Color softColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: softColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: IzyTelColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkFilters extends StatelessWidget {
  const _NetworkFilters({required this.viewModel});

  final OfferManagementViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IzyTelFilterPill(
            label: 'Tous réseaux',
            selected: viewModel.networkFilter == null,
            onTap: () => viewModel.setNetworkFilter(null),
          ),
          const SizedBox(width: 8),
          for (final MobileNetwork network in MobileNetwork.values) ...[
            IzyTelFilterPill(
              label: _networkLabel(network),
              selected: viewModel.networkFilter == network,
              selectedColor: _networkColor(network),
              softColor: _networkSoftColor(network),
              tintedWhenIdle: true,
              onTap: () => viewModel.setNetworkFilter(network),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ServiceStatusFilters extends StatelessWidget {
  const _ServiceStatusFilters({required this.viewModel});

  final OfferManagementViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final OfferService service in OfferService.values) ...[
            IzyTelFilterPill(
              label: service.label,
              selected: viewModel.serviceFilter == service,
              onTap: () => viewModel.setServiceFilter(service),
            ),
            const SizedBox(width: 8),
          ],
          IzyTelFilterPill(
            label: 'Actives',
            selected: viewModel.statusFilter == OfferStatusFilter.active,
            selectedColor: IzyTelColors.success,
            softColor: IzyTelColors.successSoft,
            onTap: () => viewModel.setStatusFilter(
              viewModel.statusFilter == OfferStatusFilter.active
                  ? OfferStatusFilter.all
                  : OfferStatusFilter.active,
            ),
          ),
          const SizedBox(width: 8),
          IzyTelFilterPill(
            label: 'Suspendues',
            selected: viewModel.statusFilter == OfferStatusFilter.suspended,
            selectedColor: IzyTelColors.error,
            softColor: IzyTelColors.errorSoft,
            onTap: () => viewModel.setStatusFilter(
              viewModel.statusFilter == OfferStatusFilter.suspended
                  ? OfferStatusFilter.all
                  : OfferStatusFilter.suspended,
            ),
          ),
        ],
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
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: networkColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(IzyTelRadii.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _NetworkMark(network: offer.network),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _networkLabel(offer.network),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: networkColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        _StatusBadge(isActive: offer.isActive),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(offer),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            formatCfa(offer.sellingPrice),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: IzyTelColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: offer.isActive ? 'Suspendre' : 'Réactiver',
                          onPressed: isBusy ? null : onToggleStatus,
                          visualDensity: VisualDensity.compact,
                          icon: isBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  offer.isActive
                                      ? Symbols.pause_circle_rounded
                                      : Symbols.play_circle_rounded,
                                  color: offer.isActive
                                      ? IzyTelColors.warning
                                      : IzyTelColors.success,
                                ),
                        ),
                        IconButton(
                          tooltip: 'Modifier',
                          onPressed: onEdit,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Symbols.edit_rounded,
                            color: IzyTelColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkMark extends StatelessWidget {
  const _NetworkMark({required this.network});

  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _networkSoftColor(network),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Image.asset(_networkAsset(network), fit: BoxFit.contain),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IzyTelStatusPill(
      label: isActive ? 'Active' : 'Suspendue',
      color: isActive ? IzyTelColors.success : IzyTelColors.error,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const IzyTelSurface(
      child: IzyTelEmptyState(
        icon: Symbols.local_offer_rounded,
        title: 'Aucune offre',
        message: 'Aucune offre ne correspond aux filtres sélectionnés.',
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: IzyTelEmptyState(
        icon: Symbols.cloud_off_rounded,
        title: 'Catalogue indisponible',
        message: message,
        actionLabel: 'Réessayer',
        onAction: onRetry,
      ),
    );
  }
}

String _networkLabel(MobileNetwork network) => switch (network) {
  MobileNetwork.orange => 'Orange',
  MobileNetwork.mtn => 'MTN',
  MobileNetwork.moov => 'Moov',
};

String _networkAsset(MobileNetwork network) => switch (network) {
  MobileNetwork.orange => 'assets/brands/operators/orange_ci.png',
  MobileNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
  MobileNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
};

Color _networkColor(MobileNetwork network) => switch (network) {
  MobileNetwork.orange => IzyTelColors.orange,
  MobileNetwork.mtn => IzyTelColors.mtnText,
  MobileNetwork.moov => IzyTelColors.moov,
};

Color _networkSoftColor(MobileNetwork network) => switch (network) {
  MobileNetwork.orange => IzyTelColors.orangeSoft,
  MobileNetwork.mtn => IzyTelColors.mtnSoft,
  MobileNetwork.moov => IzyTelColors.moovSoft,
};

String _subtitle(AdminOffer offer) {
  final List<String> parts = <String>[
    if (offer.volume != null && offer.volume!.trim().isNotEmpty) offer.volume!,
    if (offer.validity != null && offer.validity!.trim().isNotEmpty)
      'Validité ${offer.validity}',
    if (offer.minutes != null && offer.minutes!.trim().isNotEmpty)
      '${offer.minutes} appels',
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  return offer.service.label;
}
