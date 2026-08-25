import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/offers/domain/models/admin_offer.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/presentation/view_models/offer_editor_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OfferEditorPage extends StatefulWidget {
  const OfferEditorPage({
    super.key,
    required this.repository,
    this.offer,
  });

  final AdminOfferRepository repository;
  final AdminOffer? offer;

  @override
  State<OfferEditorPage> createState() => _OfferEditorPageState();
}

class _OfferEditorPageState extends State<OfferEditorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final OfferEditorViewModel _viewModel;
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _displayOrderController;
  late final TextEditingController _volumeController;
  late final TextEditingController _validityController;
  late final TextEditingController _minutesController;
  late final TextEditingController _smsController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final AdminOffer? offer = widget.offer;
    _viewModel = OfferEditorViewModel(
      repository: widget.repository,
      existingOffer: offer,
    );
    _titleController = TextEditingController(text: offer?.title ?? '');
    _priceController = TextEditingController(
      text: offer?.sellingPrice.toString() ?? '',
    );
    _displayOrderController = TextEditingController(
      text: offer?.displayOrder.toString() ?? '0',
    );
    _volumeController = TextEditingController(text: offer?.volume ?? '');
    _validityController = TextEditingController(text: offer?.validity ?? '');
    _minutesController = TextEditingController(text: offer?.minutes ?? '');
    _smsController = TextEditingController(text: offer?.sms ?? '');
    _descriptionController = TextEditingController(
      text: offer?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _displayOrderController.dispose();
    _volumeController.dispose();
    _validityController.dispose();
    _minutesController.dispose();
    _smsController.dispose();
    _descriptionController.dispose();
    _viewModel.dispose();
    super.dispose();
  }


  InputDecoration _inputDecoration({String? hintText}) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.outlineVariant.withAlpha(80)),
    );

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AppColors.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final int price = int.parse(_priceController.text.trim());
    final int displayOrder = int.parse(_displayOrderController.text.trim());
    final bool saved = await _viewModel.save(
      title: _titleController.text,
      sellingPrice: price,
      displayOrder: displayOrder,
      volume: _volumeController.text,
      validity: _validityController.text,
      minutes: _minutesController.text,
      sms: _smsController.text,
      description: _descriptionController.text,
    );

    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _viewModel.errorMessage ?? 'Impossible d’enregistrer cette offre.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text(widget.offer == null ? 'Ajouter une offre' : 'Modifier l’offre'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (BuildContext context, Widget? child) {
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                children: [
                  _SectionCard(
                    title: 'Informations principales',
                    children: [
                      _FieldLabel('Réseau'),
                      DropdownButtonFormField<MobileNetwork>(
                        initialValue: _viewModel.network,
                        decoration: _inputDecoration(),
                        dropdownColor: AppColors.surfaceContainerHigh,
                        items: MobileNetwork.values
                            .map(
                              (MobileNetwork network) => DropdownMenuItem(
                                value: network,
                                child: Text(_networkLabel(network)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _viewModel.isSaving
                            ? null
                            : (MobileNetwork? value) {
                                if (value != null) _viewModel.setNetwork(value);
                              },
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Service'),
                      DropdownButtonFormField<OfferService>(
                        initialValue: _viewModel.service,
                        decoration: _inputDecoration(),
                        dropdownColor: AppColors.surfaceContainerHigh,
                        items: OfferService.values
                            .map(
                              (OfferService service) => DropdownMenuItem(
                                value: service,
                                child: Text(service.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _viewModel.isSaving
                            ? null
                            : (OfferService? value) {
                                if (value != null) _viewModel.setService(value);
                              },
                      ),
                      if (_viewModel.service == OfferService.calls) ...[
                        const SizedBox(height: 14),
                        _FieldLabel('Type de forfait'),
                        DropdownButtonFormField<OrderOperationType>(
                          initialValue: _viewModel.operationType ==
                                  OrderOperationType.mixedBundle
                              ? OrderOperationType.mixedBundle
                              : OrderOperationType.callBundle,
                          decoration: _inputDecoration(),
                          dropdownColor: AppColors.surfaceContainerHigh,
                          items: const [
                            DropdownMenuItem(
                              value: OrderOperationType.callBundle,
                              child: Text('Appels'),
                            ),
                            DropdownMenuItem(
                              value: OrderOperationType.mixedBundle,
                              child: Text('Mixte (appels + data)'),
                            ),
                          ],
                          onChanged: _viewModel.isSaving
                              ? null
                              : (OrderOperationType? value) {
                                  if (value != null) {
                                    _viewModel.setOperationType(value);
                                  }
                                },
                        ),
                      ],
                      const SizedBox(height: 14),
                      _FieldLabel('Nom de l’offre'),
                      TextFormField(
                        controller: _titleController,
                        enabled: !_viewModel.isSaving,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration(hintText: 'Ex. Pass Internet 5 Go - 30J'),
                        validator: (String? value) {
                          final String cleaned = value?.trim() ?? '';
                          if (cleaned.length < 2) {
                            return 'Saisis un nom d’au moins 2 caractères.';
                          }
                          if (cleaned.length > 100) {
                            return 'Le nom ne doit pas dépasser 100 caractères.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Prix (FCFA)'),
                      TextFormField(
                        controller: _priceController,
                        enabled: !_viewModel.isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDecoration(hintText: '5000'),
                        validator: (String? value) {
                          final int? amount = int.tryParse(value?.trim() ?? '');
                          if (amount == null || amount <= 0) {
                            return 'Saisis un prix valide.';
                          }
                          if (amount > 1000000) {
                            return 'Le prix maximum est 1 000 000 FCFA.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Ordre d’affichage'),
                      TextFormField(
                        controller: _displayOrderController,
                        enabled: !_viewModel.isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _inputDecoration(hintText: '0'),
                        validator: (String? value) {
                          final int? order = int.tryParse(value?.trim() ?? '');
                          if (order == null || order < 0) {
                            return 'Saisis un nombre supérieur ou égal à 0.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Caractéristiques',
                    children: [
                      _FieldLabel('Volume (Data)'),
                      TextFormField(
                        controller: _volumeController,
                        enabled: !_viewModel.isSaving,
                        decoration: _inputDecoration(hintText: 'Ex. 5 Go'),
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Validité'),
                      TextFormField(
                        controller: _validityController,
                        enabled: !_viewModel.isSaving,
                        decoration: _inputDecoration(hintText: 'Ex. 30 jours'),
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Minutes (Voix)'),
                      TextFormField(
                        controller: _minutesController,
                        enabled: !_viewModel.isSaving,
                        decoration: _inputDecoration(hintText: 'Ex. 120 min / Illimité'),
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('SMS'),
                      TextFormField(
                        controller: _smsController,
                        enabled: !_viewModel.isSaving,
                        decoration: _inputDecoration(hintText: 'Ex. 100 / Illimité'),
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Description (optionnelle)'),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_viewModel.isSaving,
                        minLines: 3,
                        maxLines: 5,
                        decoration: _inputDecoration(hintText: 'Informations utiles pour cette offre…'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Statut',
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _viewModel.isActive,
                        activeThumbColor: AppColors.success,
                        title: Text(
                          _viewModel.isActive ? 'Offre active' : 'Offre suspendue',
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          _viewModel.isActive
                              ? 'Visible pour les nouvelles commandes.'
                              : 'Masquée pour les nouvelles commandes.',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        onChanged: _viewModel.isSaving
                            ? null
                            : _viewModel.setActive,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _viewModel.isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _viewModel.isSaving ? null : _save,
                  child: _viewModel.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.outlineVariant.withAlpha(90)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _networkLabel(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'Orange';
    case MobileNetwork.mtn:
      return 'MTN';
    case MobileNetwork.moov:
      return 'Moov Africa';
  }
}
