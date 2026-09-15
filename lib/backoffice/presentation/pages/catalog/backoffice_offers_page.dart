import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/migrations/legacy_catalog_backfill_service.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _OfferStatusScope { all, active, suspended }

class BackofficeOffersPage extends StatefulWidget {
  const BackofficeOffersPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AdminOfferRepository repository;

  @override
  State<BackofficeOffersPage> createState() => _BackofficeOffersPageState();
}

class _BackofficeOffersPageState extends State<BackofficeOffersPage> {
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<AdminOffer>> _stream;
  String _query = '';
  MobileNetwork? _networkFilter;
  OfferService? _serviceFilter;
  _OfferStatusScope _statusScope = _OfferStatusScope.all;
  bool _busy = false;

  bool get _canManage => widget.user.role == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    _reloadStream(notify: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadStream({bool notify = true}) {
    final Stream<List<AdminOffer>> next = widget.repository.watchOffers();
    if (!notify) {
      _stream = next;
      return;
    }
    setState(() => _stream = next);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminOffer>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<AdminOffer>> snapshot) {
        if (snapshot.hasError) {
          return BackofficeEmptyState(
            icon: Symbols.cloud_off_rounded,
            title: 'Catalogue indisponible',
            message:
                'Les offres IzyTel ne peuvent pas être chargées pour le moment.',
            action: FilledButton.icon(
              onPressed: _reloadStream,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<AdminOffer> all = snapshot.data!;
        final List<AdminOffer> visible = _filtered(all);
        final int active = all.where((AdminOffer offer) => offer.isActive).length;
        final int suspended = all.length - active;
        final int internet = all
            .where((AdminOffer offer) => offer.service == OfferService.internet)
            .length;
        final int calls = all.length - internet;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BackofficePageIntro(
              eyebrow: 'Catalogue / Offres & tarifs',
              title: 'Catalogue commercial IzyTel',
              description:
                  'Administre les offres visibles côté client et côté staff depuis une source Supabase unique : réseau, service, tarif, contenu, ordre d’affichage et disponibilité.',
              icon: Symbols.local_offer_rounded,
              trailing: _canManage
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _synchronizeLegacyCatalog,
                          icon: const Icon(Symbols.sync_rounded),
                          label: const Text('Synchroniser historique'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _openEditor(),
                          icon: const Icon(Symbols.add_rounded),
                          label: const Text('Nouvelle offre'),
                        ),
                      ],
                    )
                  : null,
            ),
            const SizedBox(height: 18),
            _metrics(
              total: all.length,
              active: active,
              suspended: suspended,
              internet: internet,
              calls: calls,
            ),
            const SizedBox(height: 14),
            _catalogNotice(),
            const SizedBox(height: 14),
            _filters(all: all, visibleCount: visible.length),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              BackofficeEmptyState(
                icon: Symbols.inventory_2_rounded,
                title: all.isEmpty
                    ? 'Catalogue vide'
                    : 'Aucune offre dans cette vue',
                message: all.isEmpty
                    ? 'Synchronise le catalogue historique ou crée la première offre IzyTel.'
                    : 'Modifie la recherche ou les filtres pour afficher d’autres offres.',
                action: all.isEmpty && _canManage
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : _synchronizeLegacyCatalog,
                        icon: const Icon(Symbols.sync_rounded),
                        label: const Text('Synchroniser les offres existantes'),
                      )
                    : null,
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth >= 1040) {
                    return _desktopTable(visible);
                  }
                  return Column(
                    children: visible
                        .map(
                          (AdminOffer offer) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _mobileCard(offer),
                          ),
                        )
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
    required int total,
    required int active,
    required int suspended,
    required int internet,
    required int calls,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
            ? 3
            : 2;
        const double gap = 10;
        final double width =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(
            label: 'Offres',
            value: '$total',
            caption: 'catalogue complet',
            icon: Symbols.inventory_2_rounded,
          ),
          BackofficeMetricCard(
            label: 'Actives',
            value: '$active',
            caption: 'visibles à la commande',
            icon: Symbols.check_circle_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Suspendues',
            value: '$suspended',
            caption: 'masquées du catalogue',
            icon: Symbols.pause_circle_rounded,
            emphasis: suspended > 0
                ? BackofficePalette.warning
                : BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Internet',
            value: '$internet',
            caption: 'offres data',
            icon: Symbols.language_rounded,
            emphasis: BackofficePalette.cyan,
          ),
          BackofficeMetricCard(
            label: 'Appels',
            value: '$calls',
            caption: 'voix et mixtes',
            icon: Symbols.call_rounded,
            emphasis: BackofficePalette.primaryStrong,
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

  Widget _catalogNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BackofficePalette.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BackofficePalette.primary.withValues(alpha: .16),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Symbols.sync_alt_rounded,
            color: BackofficePalette.primary,
            fill: 1,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Une offre active enregistrée ici devient la référence du catalogue Supabase pour le Web client et l’application staff. Suspendre une offre masque seulement les nouvelles commandes : l’historique des anciennes commandes reste intact.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters({required List<AdminOffer> all, required int visibleCount}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Nom, libellé, volume, validité ou prix',
              prefixIcon: const Icon(Symbols.search_rounded),
              suffixIcon: _query.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Symbols.close_rounded),
                    ),
            ),
          );
          final Widget network = DropdownButtonFormField<MobileNetwork?>(
            initialValue: _networkFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Réseau'),
            items: <DropdownMenuItem<MobileNetwork?>>[
              const DropdownMenuItem<MobileNetwork?>(
                value: null,
                child: Text('Tous les réseaux'),
              ),
              for (final MobileNetwork item in MobileNetwork.values)
                DropdownMenuItem<MobileNetwork?>(
                  value: item,
                  child: Text(_networkLabel(item)),
                ),
            ],
            onChanged: (MobileNetwork? value) {
              setState(() => _networkFilter = value);
            },
          );
          final Widget service = DropdownButtonFormField<OfferService?>(
            initialValue: _serviceFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Service'),
            items: <DropdownMenuItem<OfferService?>>[
              const DropdownMenuItem<OfferService?>(
                value: null,
                child: Text('Tous les services'),
              ),
              for (final OfferService item in OfferService.values)
                DropdownMenuItem<OfferService?>(
                  value: item,
                  child: Text(item.label),
                ),
            ],
            onChanged: (OfferService? value) {
              setState(() => _serviceFilter = value);
            },
          );
          final Widget status = DropdownButtonFormField<_OfferStatusScope>(
            initialValue: _statusScope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: <DropdownMenuItem<_OfferStatusScope>>[
              DropdownMenuItem<_OfferStatusScope>(
                value: _OfferStatusScope.all,
                child: Text('Tous (${all.length})'),
              ),
              DropdownMenuItem<_OfferStatusScope>(
                value: _OfferStatusScope.active,
                child: Text(
                  'Actives (${all.where((AdminOffer item) => item.isActive).length})',
                ),
              ),
              DropdownMenuItem<_OfferStatusScope>(
                value: _OfferStatusScope.suspended,
                child: Text(
                  'Suspendues (${all.where((AdminOffer item) => !item.isActive).length})',
                ),
              ),
            ],
            onChanged: (_OfferStatusScope? value) {
              if (value != null) {
                setState(() => _statusScope = value);
              }
            },
          );
          final Widget indicator = Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$visibleCount offre${visibleCount > 1 ? 's' : ''} affichée${visibleCount > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BackofficePalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              children: <Widget>[
                search,
                const SizedBox(height: 10),
                network,
                const SizedBox(height: 10),
                service,
                const SizedBox(height: 10),
                status,
                indicator,
              ],
            );
          }
          return Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(flex: 4, child: search),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: network),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: service),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: status),
                ],
              ),
              indicator,
            ],
          );
        },
      ),
    );
  }

  List<AdminOffer> _filtered(List<AdminOffer> all) {
    final String query = _query.trim().toLowerCase();
    final List<AdminOffer> result = all.where((AdminOffer offer) {
      if (_networkFilter != null && offer.network != _networkFilter) {
        return false;
      }
      if (_serviceFilter != null && offer.service != _serviceFilter) {
        return false;
      }
      if (_statusScope == _OfferStatusScope.active && !offer.isActive) {
        return false;
      }
      if (_statusScope == _OfferStatusScope.suspended && offer.isActive) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final String searchable = <String>[
        offer.title,
        offer.catalogLabel,
        offer.description ?? '',
        offer.volume ?? '',
        offer.validity ?? '',
        offer.minutes ?? '',
        offer.sms ?? '',
        offer.sellingPrice.toString(),
        _networkLabel(offer.network),
        offer.service.label,
        ...offer.details,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: true);
    result.sort(_compareOffers);
    return result;
  }

  int _compareOffers(AdminOffer a, AdminOffer b) {
    final int network = a.network.index.compareTo(b.network.index);
    if (network != 0) {
      return network;
    }
    final int service = a.service.index.compareTo(b.service.index);
    if (service != 0) {
      return service;
    }
    final int display = a.displayOrder.compareTo(b.displayOrder);
    if (display != 0) {
      return display;
    }
    return a.sellingPrice.compareTo(b.sellingPrice);
  }

  Widget _desktopTable(List<AdminOffer> offers) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'OFFRE', flex: 5),
        BackofficeTableColumnSpec(label: 'RÉSEAU', flex: 2),
        BackofficeTableColumnSpec(label: 'SERVICE', flex: 2),
        BackofficeTableColumnSpec(label: 'TARIF', flex: 2),
        BackofficeTableColumnSpec(label: 'ORDRE', flex: 1),
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(
          label: 'ACTION',
          flex: 2,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: offers
          .map(
            (AdminOffer offer) => BackofficeDesktopTableRow(
              accentColor: offer.isActive
                  ? BackofficePalette.success
                  : BackofficePalette.warning,
              onTap: _canManage ? () => _openEditor(offer) : null,
              cells: <BackofficeTableCellSpec>[
                BackofficeTableCellSpec(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        offer.catalogLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_characteristics(offer).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          _characteristics(offer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: BackofficePalette.faint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeNetworkBadge(network: offer.network),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Text(
                    offer.service.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Text(
                    formatCfa(offer.sellingPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 1,
                  child: Text('#${offer.displayOrder}'),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeStatusBadge(
                    label: offer.isActive ? 'Active' : 'Suspendue',
                    color: offer.isActive
                        ? BackofficePalette.success
                        : BackofficePalette.warning,
                    icon: offer.isActive
                        ? Symbols.check_circle_rounded
                        : Symbols.pause_circle_rounded,
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  alignment: Alignment.centerRight,
                  child: _canManage
                      ? PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (String value) {
                            if (value == 'edit') {
                              _openEditor(offer);
                            } else if (value == 'status') {
                              _toggleStatus(offer);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Symbols.edit_rounded),
                                title: Text('Modifier'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'status',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  offer.isActive
                                      ? Symbols.pause_circle_rounded
                                      : Symbols.play_circle_rounded,
                                ),
                                title: Text(
                                  offer.isActive ? 'Suspendre' : 'Réactiver',
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _mobileCard(AdminOffer offer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      offer.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(offer.catalogLabel),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              BackofficeStatusBadge(
                label: offer.isActive ? 'Active' : 'Suspendue',
                color: offer.isActive
                    ? BackofficePalette.success
                    : BackofficePalette.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              BackofficeNetworkBadge(network: offer.network),
              BackofficeStatusBadge(
                label: offer.service.label,
                color: BackofficePalette.primary,
                icon: offer.service == OfferService.internet
                    ? Symbols.language_rounded
                    : Symbols.call_rounded,
              ),
              BackofficeStatusBadge(
                label: formatCfa(offer.sellingPrice),
                color: BackofficePalette.primaryStrong,
                icon: Symbols.payments_rounded,
              ),
              BackofficeStatusBadge(
                label: 'Ordre ${offer.displayOrder}',
                color: BackofficePalette.muted,
                icon: Symbols.format_list_numbered_rounded,
              ),
            ],
          ),
          if (_characteristics(offer).isNotEmpty) ...<Widget>[
            const SizedBox(height: 11),
            Text(
              _characteristics(offer),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_canManage) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _openEditor(offer),
                    icon: const Icon(Symbols.edit_rounded),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy ? null : () => _toggleStatus(offer),
                    icon: Icon(
                      offer.isActive
                          ? Symbols.pause_circle_rounded
                          : Symbols.play_circle_rounded,
                    ),
                    label: Text(offer.isActive ? 'Suspendre' : 'Réactiver'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _characteristics(AdminOffer offer) {
    final List<String> values = <String>[
      if ((offer.volume ?? '').trim().isNotEmpty) offer.volume!.trim(),
      if ((offer.minutes ?? '').trim().isNotEmpty) offer.minutes!.trim(),
      if ((offer.sms ?? '').trim().isNotEmpty) offer.sms!.trim(),
      if ((offer.validity ?? '').trim().isNotEmpty)
        'Validité ${offer.validity!.trim()}',
    ];
    return values.join(' • ');
  }

  Future<void> _openEditor([AdminOffer? offer]) async {
    if (!_canManage || _busy) {
      return;
    }
    final bool? changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _CatalogOfferEditorDialog(
          repository: widget.repository,
          offer: offer,
        );
      },
    );
    if (!mounted || changed != true) {
      return;
    }
    _reloadStream();
    IzyTelFeedback.success(
      context,
      offer == null ? 'Offre créée.' : 'Offre mise à jour.',
    );
  }

  Future<void> _toggleStatus(AdminOffer offer) async {
    if (!_canManage || _busy) {
      return;
    }
    final bool target = !offer.isActive;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(target ? 'Réactiver cette offre ?' : 'Suspendre cette offre ?'),
          content: Text(
            target
                ? 'Elle redeviendra immédiatement disponible pour les nouvelles commandes.'
                : 'Elle sera masquée du catalogue des nouvelles commandes, sans supprimer l’historique existant.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(target ? 'Réactiver' : 'Suspendre'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.repository.setOfferActive(
        offerId: offer.id,
        isActive: target,
      );
      if (!mounted) {
        return;
      }
      _reloadStream();
      IzyTelFeedback.success(
        context,
        target ? 'Offre réactivée.' : 'Offre suspendue.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      IzyTelFeedback.error(
        context,
        'Impossible de modifier le statut de cette offre.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _synchronizeLegacyCatalog() async {
    if (!_canManage || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final int imported = await LegacyCatalogBackfillService().synchronizeNow();
      if (!mounted) {
        return;
      }
      _reloadStream();
      IzyTelFeedback.success(
        context,
        imported == 0
            ? 'Catalogue déjà synchronisé : aucune nouvelle offre historique.'
            : '$imported offre${imported > 1 ? 's' : ''} historique${imported > 1 ? 's' : ''} importée${imported > 1 ? 's' : ''}.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      IzyTelFeedback.error(
        context,
        'La synchronisation des offres historiques a échoué.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _CatalogOfferEditorDialog extends StatefulWidget {
  const _CatalogOfferEditorDialog({
    required this.repository,
    this.offer,
  });

  final AdminOfferRepository repository;
  final AdminOffer? offer;

  @override
  State<_CatalogOfferEditorDialog> createState() =>
      _CatalogOfferEditorDialogState();
}

class _CatalogOfferEditorDialogState extends State<_CatalogOfferEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _catalogLabelController;
  late final TextEditingController _priceController;
  late final TextEditingController _orderController;
  late final TextEditingController _volumeController;
  late final TextEditingController _validityController;
  late final TextEditingController _minutesController;
  late final TextEditingController _smsController;
  late final TextEditingController _badgeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _eligibilityController;
  late final TextEditingController _detailsController;
  late MobileNetwork _network;
  late OfferService _service;
  late OrderOperationType _operationType;
  late bool _active;
  bool _saving = false;

  bool get _editing => widget.offer != null;

  @override
  void initState() {
    super.initState();
    final AdminOffer? offer = widget.offer;
    _network = offer?.network ?? MobileNetwork.orange;
    _service = offer?.service ?? OfferService.internet;
    _operationType = offer?.operationType ?? OrderOperationType.internetSubscription;
    _active = offer?.isActive ?? true;
    _titleController = TextEditingController(text: offer?.title ?? '');
    _catalogLabelController = TextEditingController(text: offer?.catalogLabel ?? '');
    _priceController = TextEditingController(
      text: offer == null ? '' : offer.sellingPrice.toString(),
    );
    _orderController = TextEditingController(
      text: (offer?.displayOrder ?? 9999).toString(),
    );
    _volumeController = TextEditingController(text: offer?.volume ?? '');
    _validityController = TextEditingController(text: offer?.validity ?? '');
    _minutesController = TextEditingController(text: offer?.minutes ?? '');
    _smsController = TextEditingController(text: offer?.sms ?? '');
    _badgeController = TextEditingController(text: offer?.badgeLabel ?? '');
    _descriptionController = TextEditingController(text: offer?.description ?? '');
    _eligibilityController = TextEditingController(text: offer?.eligibility ?? '');
    _detailsController = TextEditingController(text: offer?.details.join('\n') ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _catalogLabelController.dispose();
    _priceController.dispose();
    _orderController.dispose();
    _volumeController.dispose();
    _validityController.dispose();
    _minutesController.dispose();
    _smsController.dispose();
    _badgeController.dispose();
    _descriptionController.dispose();
    _eligibilityController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 820),
        child: Container(
          decoration: backofficePanelDecoration(radius: 22, elevated: true),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BackofficePalette.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Symbols.local_offer_rounded,
                        color: BackofficePalette.primaryStrong,
                        fill: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _editing ? 'Modifier l’offre' : 'Nouvelle offre',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _editing
                                ? 'Mets à jour le catalogue sans altérer les commandes déjà enregistrées.'
                                : 'Ajoute une offre au catalogue Supabase IzyTel.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _section(
                          title: 'Identification commerciale',
                          description:
                              'Le réseau et le service déterminent où l’offre apparaît.',
                          children: <Widget>[
                            _responsiveFields(<Widget>[
                              _labeledField(
                                label: 'Réseau',
                                child: DropdownButtonFormField<MobileNetwork>(
                                  initialValue: _network,
                                  isExpanded: true,
                                  items: MobileNetwork.values
                                      .map(
                                        (MobileNetwork item) => DropdownMenuItem<MobileNetwork>(
                                          value: item,
                                          child: Text(_networkLabel(item)),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: _saving
                                      ? null
                                      : (MobileNetwork? value) {
                                          if (value != null) {
                                            setState(() => _network = value);
                                          }
                                        },
                                ),
                              ),
                              _labeledField(
                                label: 'Service',
                                child: DropdownButtonFormField<OfferService>(
                                  initialValue: _service,
                                  isExpanded: true,
                                  items: OfferService.values
                                      .map(
                                        (OfferService item) => DropdownMenuItem<OfferService>(
                                          value: item,
                                          child: Text(item.label),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: _saving
                                      ? null
                                      : (OfferService? value) {
                                          if (value == null) {
                                            return;
                                          }
                                          setState(() {
                                            _service = value;
                                            _operationType = value == OfferService.internet
                                                ? OrderOperationType.internetSubscription
                                                : _operationType ==
                                                      OrderOperationType.internetSubscription
                                                ? OrderOperationType.callBundle
                                                : _operationType;
                                          });
                                        },
                                ),
                              ),
                              _labeledField(
                                label: 'Type d’opération',
                                child: DropdownButtonFormField<OrderOperationType>(
                                  key: ValueKey<String>(
                                    '${_service.name}-${_operationType.name}',
                                  ),
                                  initialValue: _validOperationTypes.contains(_operationType)
                                      ? _operationType
                                      : _validOperationTypes.first,
                                  isExpanded: true,
                                  items: _validOperationTypes
                                      .map(
                                        (OrderOperationType item) => DropdownMenuItem<OrderOperationType>(
                                          value: item,
                                          child: Text(_operationTypeLabel(item)),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: _saving
                                      ? null
                                      : (OrderOperationType? value) {
                                          if (value != null) {
                                            setState(() => _operationType = value);
                                          }
                                        },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            _responsiveFields(<Widget>[
                              _labeledField(
                                label: 'Nom de l’offre',
                                child: TextFormField(
                                  controller: _titleController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. Pass 5 Go',
                                  ),
                                  validator: _requiredText,
                                ),
                              ),
                              _labeledField(
                                label: 'Libellé affiché dans la commande',
                                child: TextFormField(
                                  controller: _catalogLabelController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. Internet Orange 5 Go - 30 jours',
                                  ),
                                  validator: _requiredText,
                                ),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _section(
                          title: 'Tarification & affichage',
                          description:
                              'Le prix est le montant payé par le client. L’ordre pilote la priorité d’affichage.',
                          children: <Widget>[
                            _responsiveFields(<Widget>[
                              _labeledField(
                                label: 'Prix de vente (FCFA)',
                                child: TextFormField(
                                  controller: _priceController,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. 5000',
                                  ),
                                  validator: _positiveNumber,
                                ),
                              ),
                              _labeledField(
                                label: 'Ordre d’affichage',
                                child: TextFormField(
                                  controller: _orderController,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. 10',
                                  ),
                                  validator: _nonNegativeNumber,
                                ),
                              ),
                              _labeledField(
                                label: 'Badge (optionnel)',
                                child: TextFormField(
                                  controller: _badgeController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. Populaire',
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _section(
                          title: 'Contenu de l’offre',
                          description:
                              'Ces informations sont utilisées pour présenter clairement l’offre côté client.',
                          children: <Widget>[
                            _responsiveFields(<Widget>[
                              _labeledField(
                                label: 'Volume Internet',
                                child: TextFormField(
                                  controller: _volumeController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. 5 Go',
                                  ),
                                ),
                              ),
                              _labeledField(
                                label: 'Validité',
                                child: TextFormField(
                                  controller: _validityController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. 30 jours',
                                  ),
                                ),
                              ),
                              _labeledField(
                                label: 'Minutes',
                                child: TextFormField(
                                  controller: _minutesController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. 120 min',
                                  ),
                                ),
                              ),
                              _labeledField(
                                label: 'SMS',
                                child: TextFormField(
                                  controller: _smsController,
                                  enabled: !_saving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex. 100 SMS',
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            _labeledField(
                              label: 'Détails affichés (un élément par ligne)',
                              child: TextFormField(
                                controller: _detailsController,
                                enabled: !_saving,
                                minLines: 3,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                  hintText:
                                      '5 Go\nValidité : 30 jours\nWhatsApp inclus',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _responsiveFields(<Widget>[
                              _labeledField(
                                label: 'Description (optionnelle)',
                                child: TextFormField(
                                  controller: _descriptionController,
                                  enabled: !_saving,
                                  minLines: 3,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    hintText: 'Informations commerciales utiles…',
                                  ),
                                ),
                              ),
                              _labeledField(
                                label: 'Éligibilité (optionnelle)',
                                child: TextFormField(
                                  controller: _eligibilityController,
                                  enabled: !_saving,
                                  minLines: 3,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    hintText: 'Conditions particulières…',
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _section(
                          title: 'Disponibilité',
                          description:
                              'Une offre suspendue reste dans l’historique mais n’est plus proposée aux nouvelles commandes.',
                          children: <Widget>[
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _active,
                              title: Text(
                                _active ? 'Offre active' : 'Offre suspendue',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                _active
                                    ? 'Visible dans les catalogues client et staff.'
                                    : 'Masquée pour les nouvelles commandes.',
                              ),
                              onChanged: _saving
                                  ? null
                                  : (bool value) => setState(() => _active = value),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Symbols.save_rounded),
                      label: Text(_editing ? 'Enregistrer' : 'Créer l’offre'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<OrderOperationType> get _validOperationTypes {
    if (_service == OfferService.internet) {
      return const <OrderOperationType>[OrderOperationType.internetSubscription];
    }
    return const <OrderOperationType>[
      OrderOperationType.callBundle,
      OrderOperationType.mixedBundle,
      OrderOperationType.other,
    ];
  }

  Widget _section({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: <Widget>[
              for (int index = 0; index < fields.length; index++) ...<Widget>[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < fields.length; index++) ...<Widget>[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: BackofficePalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  String? _requiredText(String? value) {
    final String cleaned = value?.trim() ?? '';
    if (cleaned.length < 2) {
      return 'Champ obligatoire.';
    }
    return null;
  }

  String? _positiveNumber(String? value) {
    final int? parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Montant invalide.';
    }
    return null;
  }

  String? _nonNegativeNumber(String? value) {
    final int? parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return 'Ordre invalide.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final OrderOperationType operationType =
        _validOperationTypes.contains(_operationType)
        ? _operationType
        : _validOperationTypes.first;
    final AdminOfferDraft draft = AdminOfferDraft(
      network: _network,
      service: _service,
      operationType: operationType,
      title: _titleController.text.trim(),
      catalogLabel: _catalogLabelController.text.trim(),
      sellingPrice: int.parse(_priceController.text),
      details: _detailsController.text
          .split(RegExp(r'\r?\n'))
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList(growable: false),
      category: operationType == OrderOperationType.mixedBundle
          ? 'mixed'
          : _service == OfferService.calls
          ? 'calls'
          : 'internet',
      isActive: _active,
      displayOrder: int.parse(_orderController.text),
      volume: _clean(_volumeController.text),
      validity: _clean(_validityController.text),
      minutes: _clean(_minutesController.text),
      sms: _clean(_smsController.text),
      description: _clean(_descriptionController.text),
      badgeLabel: _clean(_badgeController.text),
      eligibility: _clean(_eligibilityController.text),
    );

    setState(() => _saving = true);
    try {
      final AdminOffer? existing = widget.offer;
      if (existing == null) {
        await widget.repository.createOffer(draft);
      } else {
        await widget.repository.updateOffer(offerId: existing.id, draft: draft);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      IzyTelFeedback.error(
        context,
        _editing
            ? 'Impossible d’enregistrer les modifications.'
            : 'Impossible de créer cette offre.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _clean(String value) {
    final String cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
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

String _operationTypeLabel(OrderOperationType type) {
  switch (type) {
    case OrderOperationType.internetSubscription:
      return 'Souscription Internet';
    case OrderOperationType.unitTransfer:
      return 'Transfert d’unités';
    case OrderOperationType.callBundle:
      return 'Forfait appels';
    case OrderOperationType.mixedBundle:
      return 'Forfait mixte';
    case OrderOperationType.other:
      return 'Autre';
  }
}
