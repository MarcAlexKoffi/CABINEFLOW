import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_recovery_key.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_bottom_actions.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerOrderRecoveryPage extends StatefulWidget {
  const CustomerOrderRecoveryPage({
    super.key,
    required this.viewModel,
    required this.onBack,
    required this.onRecovered,
    required this.onOpenHome,
    required this.onOpenOffers,
    required this.onOpenHistory,
    required this.onOpenHelp,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback onBack;
  final VoidCallback onRecovered;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenHelp;

  @override
  State<CustomerOrderRecoveryPage> createState() =>
      _CustomerOrderRecoveryPageState();
}

class _CustomerOrderRecoveryPageState extends State<CustomerOrderRecoveryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _referenceController;
  late final TextEditingController _codeController;
  bool _showCode = false;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _clearServerError() => widget.viewModel.clearRecoveryError();

  Future<void> _recover() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bool recovered = await widget.viewModel.recoverOrderByCode(
      reference: _referenceController.text,
      recoveryCodeInput: _codeController.text,
    );
    if (mounted && recovered) widget.onRecovered();
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;

    return IzyTelShell(
      title: 'IzyTel',
      onBack: widget.onBack,
      maxContentWidth: 760,
      actions: desktop
          ? <Widget>[
              TextButton(onPressed: widget.onOpenHome, child: const Text('Accueil')),
              TextButton(onPressed: widget.onOpenOffers, child: const Text('Offres')),
              TextButton(onPressed: widget.onOpenHistory, child: const Text('Historique')),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: TextButton(onPressed: widget.onOpenHelp, child: const Text('Aide')),
              ),
            ]
          : null,
      bottomNavigationBar: desktop
          ? null
          : IzyTelBottomNavigation(
              current: IzyTelCustomerDestination.history,
              onHome: widget.onOpenHome,
              onOffers: widget.onOpenOffers,
              onHistory: widget.onOpenHistory,
              onHelp: widget.onOpenHelp,
            ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Retrouver ma commande',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saisissez votre référence et votre code de récupération pour retrouver votre suivi sur cet appareil.',
                      style: TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _RecoveryCodeHelpCard(),
                    const SizedBox(height: 26),
                    const _FieldLabel(text: 'Référence de commande'),
                    TextFormField(
                      controller: _referenceController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                        LengthLimitingTextInputFormatter(40),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'CF-20260915-0JU0CH',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                      validator: CustomerOrderRecoveryKey.validateReference,
                      onChanged: (_) => _clearServerError(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Exemple : CF-20260915-0JU0CH',
                      style: TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _FieldLabel(text: 'Code de récupération'),
                    TextFormField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      obscureText: !_showCode,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: InputDecoration(
                        hintText: 'IZY-ABCD-782K',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showCode ? 'Masquer le code' : 'Afficher le code',
                          onPressed: () => setState(() => _showCode = !_showCode),
                          icon: Icon(
                            _showCode
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: CustomerOrderRecoveryKey.validateCode,
                      onChanged: (_) => _clearServerError(),
                      onFieldSubmitted: (_) => _recover(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Exemple : IZY-ABCD-782K',
                      style: TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (widget.viewModel.recoveryErrorMessage != null) ...<Widget>[
                      const SizedBox(height: 18),
                      _RecoveryErrorBanner(
                        message: widget.viewModel.recoveryErrorMessage!,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const _SecurityCard(),
                  ],
                ),
              ),
            ),
          ),
          CustomerBottomActions(
            onBack: widget.viewModel.isRecoveringOrder ? null : widget.onBack,
            onContinue: _recover,
            continueLabel: 'Retrouver ma commande',
            isContinueEnabled: !widget.viewModel.isRecoveringOrder,
            isLoading: widget.viewModel.isRecoveringOrder,
          ),
        ],
      ),
    );
  }
}

class _RecoveryCodeHelpCard extends StatelessWidget {
  const _RecoveryCodeHelpCard();

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      padding: const EdgeInsets.all(18),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: CustomerAppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(
                Icons.description_outlined,
                color: CustomerAppColors.primary,
                size: 28,
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Où trouver mon code de récupération ?',
                  style: TextStyle(
                    color: CustomerAppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'IzyTel l’affiche avec la référence de votre commande. Conservez ces deux informations pour retrouver le suivi depuis un autre appareil.',
                  style: TextStyle(
                    color: CustomerAppColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerAppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined, color: CustomerAppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Vos informations sont en sécurité',
                  style: TextStyle(
                    color: CustomerAppColors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Seule la bonne combinaison référence + code donne accès à la commande concernée.',
                  style: TextStyle(
                    color: CustomerAppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecoveryErrorBanner extends StatelessWidget {
  const _RecoveryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerAppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: CustomerAppColors.onErrorContainer,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: CustomerAppColors.onErrorContainer,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
