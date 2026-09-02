import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SupplierFinancePage extends StatefulWidget {
  const SupplierFinancePage({
    super.key,
    required this.user,
    required this.repository,
    required this.agentRepository,
  });

  final AppUser user;
  final FinanceOperationsRepository repository;
  final AgentRepository agentRepository;

  @override
  State<SupplierFinancePage> createState() => _SupplierFinancePageState();
}

class _SupplierFinancePageState extends State<SupplierFinancePage> {
  bool _busy = false;

  Future<void> _addSupplier() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController phone = TextEditingController();
    final TextEditingController note = TextEditingController();
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Nouveau fournisseur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (facultatif)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (submit != true) return;
    await _run(
      () => widget.repository.createSupplier(
        name: name.text,
        phoneNumber: phone.text,
        note: note.text,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
    );
  }

  int _suggestedBonus(AgentNetwork network, int principal) {
    if (principal <= 0) return 0;
    // Règles métier actuelles : Moov +4,5 %, Orange/MTN +4 %.
    return network == AgentNetwork.moov
        ? (principal * 45) ~/ 1000
        : (principal * 4) ~/ 100;
  }

  Future<void> _openHistory(FinanceSupplier supplier) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SupplierHistoryPage(
          supplier: supplier,
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _recharge(FinanceSupplier supplier) async {
    final List<AgentDirectoryEntry> agents =
        (await widget.agentRepository.watchAgents().first)
            .where(
              (AgentDirectoryEntry item) =>
                  item.isActive && item.profile != null,
            )
            .toList(growable: false);
    if (!mounted) return;
    if (agents.isEmpty) {
      _message('Aucun Agent actif avec un profil opérationnel.');
      return;
    }

    List<AgentDirectoryEntry> eligibleFor(AgentNetwork value) => agents
        .where(
          (AgentDirectoryEntry item) =>
              item.profile!.authorizedNetworks.contains(value),
        )
        .toList(growable: false);

    AgentNetwork? initialNetwork;
    for (final AgentNetwork candidate in AgentNetwork.values) {
      if (eligibleFor(candidate).isNotEmpty) {
        initialNetwork = candidate;
        break;
      }
    }
    if (initialNetwork == null) {
      _message('Aucun Agent actif n’est autorisé sur un réseau.');
      return;
    }

    AgentNetwork network = initialNetwork;
    AgentDirectoryEntry agent = eligibleFor(network).first;
    final TextEditingController principal = TextEditingController(
      text: '10000',
    );
    final TextEditingController bonus = TextEditingController(text: '400');
    final TextEditingController note = TextEditingController();

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text('Recharge · ${supplier.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AgentNetwork>(
                  initialValue: network,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Réseau'),
                  items: AgentNetwork.values
                      .map(
                        (AgentNetwork item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (AgentNetwork? value) {
                    final AgentNetwork next = value ?? network;
                    final List<AgentDirectoryEntry> nextEligible = eligibleFor(
                      next,
                    );
                    if (nextEligible.isEmpty) return;
                    setState(() {
                      network = next;
                      if (!nextEligible.any(
                        (AgentDirectoryEntry item) =>
                            item.userId == agent.userId,
                      )) {
                        agent = nextEligible.first;
                      }
                      final int p = int.tryParse(principal.text.trim()) ?? 0;
                      bonus.text = '${_suggestedBonus(network, p)}';
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AgentDirectoryEntry>(
                  initialValue: agent,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Agent destinataire',
                  ),
                  items: eligibleFor(network)
                      .map(
                        (AgentDirectoryEntry item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.name} · ${item.agentCode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (AgentDirectoryEntry? value) =>
                      setState(() => agent = value ?? agent),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: principal,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Principal (F CFA)',
                  ),
                  onChanged: (String value) {
                    final int p = int.tryParse(value.trim()) ?? 0;
                    setState(() {
                      bonus.text = '${_suggestedBonus(network, p)}';
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bonus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bonus reçu (F CFA)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Solde total obtenu : ${formatCfaFull((int.tryParse(principal.text.trim()) ?? 0) + (int.tryParse(bonus.text.trim()) ?? 0))}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IzyTelColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dette fournisseur créée : ${formatCfaFull(int.tryParse(principal.text.trim()) ?? 0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IzyTelColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Si le fournisseur est payé immédiatement, enregistre ensuite un règlement afin que la sortie de caisse reste traçable.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: IzyTelColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    final AgentProfile profile = agent.profile!;
    if (!profile.authorizedNetworks.contains(network)) {
      _message('Cet Agent n’est pas autorisé sur ${network.label}.');
      return;
    }
    final int p = int.tryParse(principal.text.trim()) ?? 0;
    final int b = int.tryParse(bonus.text.trim()) ?? 0;
    await _run(
      () => widget.repository.recordSupplierRecharge(
        draft: SupplierRechargeDraft(
          supplierId: supplier.id,
          supplierName: supplier.name,
          agentId: agent.userId,
          agentName: agent.name,
          network: network,
          principalAmount: p,
          bonusAmount: b,
          amountOwed: p,
          note: note.text,
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
    );
  }

  Future<void> _pay(FinanceSupplier supplier, SupplierAccount? account) async {
    final int balance = account?.balance ?? 0;
    if (balance <= 0) {
      _message('Aucun montant n’est dû à ce fournisseur.');
      return;
    }
    final TextEditingController amount = TextEditingController(
      text: '$balance',
    );
    final TextEditingController reference = TextEditingController();
    final TextEditingController note = TextEditingController();
    FinancePaymentChannel channel = FinancePaymentChannel.wave;
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text('Régler · ${supplier.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Reste dû : ${formatCfaFull(balance)}'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<FinancePaymentChannel>(
                  initialValue: channel,
                  decoration: const InputDecoration(labelText: 'Canal'),
                  items: FinancePaymentChannel.values
                      .map(
                        (FinancePaymentChannel item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (FinancePaymentChannel? value) =>
                      setState(() => channel = value ?? channel),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Référence du règlement',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Régler'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    await _run(
      () => widget.repository.recordSupplierPayment(
        draft: SupplierPaymentDraft(
          supplierId: supplier.id,
          supplierName: supplier.name,
          amount: int.tryParse(amount.text.trim()) ?? 0,
          channel: channel,
          reference: reference.text,
          note: note.text,
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
    );
  }

  Future<void> _editSupplier(FinanceSupplier supplier) async {
    final TextEditingController name = TextEditingController(text: supplier.name);
    final TextEditingController phone =
        TextEditingController(text: supplier.phoneNumber);
    final TextEditingController note = TextEditingController(text: supplier.note ?? '');
    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Modifier le fournisseur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (facultatif)'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (submit != true || !mounted) return;
    await _run(
      () => widget.repository.updateSupplier(
        supplierId: supplier.id,
        name: name.text,
        phoneNumber: phone.text,
        note: note.text,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
    );
  }

  Future<void> _deleteSupplier(FinanceSupplier supplier) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Supprimer ce fournisseur ?'),
        content: Text(
          'Le fournisseur « ${supplier.name} » sera supprimé uniquement s’il ne possède aucun historique financier. Sinon, désactive-le pour conserver la traçabilité.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IzyTelColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => widget.repository.deleteSupplier(supplierId: supplier.id));
  }

  Future<void> _handleSupplierMenu(
    FinanceSupplier supplier,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await _editSupplier(supplier);
        return;
      case 'toggle':
        await _toggle(supplier);
        return;
      case 'delete':
        await _deleteSupplier(supplier);
        return;
      default:
        return;
    }
  }

  Future<void> _toggle(FinanceSupplier supplier) async {
    await _run(
      () => widget.repository.setSupplierActive(
        supplierId: supplier.id,
        isActive: !supplier.isActive,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _message('Opération enregistrée.');
    } catch (error) {
      if (mounted) _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');
  void _message(String text) => IzyTelFeedback.show(context, text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text(
          'Fournisseurs',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _addSupplier,
            tooltip: 'Ajouter',
            icon: const Icon(Symbols.add_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<FinanceSupplier>>(
        stream: widget.repository.watchSuppliers(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<FinanceSupplier>> supplierSnapshot,
            ) {
              return StreamBuilder<List<SupplierAccount>>(
                stream: widget.repository.watchSupplierAccounts(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<SupplierAccount>> accountSnapshot,
                    ) {
                      if (!supplierSnapshot.hasData &&
                          supplierSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final List<FinanceSupplier> suppliers =
                          supplierSnapshot.data ?? const <FinanceSupplier>[];
                      final Map<String, SupplierAccount> accounts =
                          <String, SupplierAccount>{
                            for (final SupplierAccount item
                                in accountSnapshot.data ??
                                    const <SupplierAccount>[])
                              item.supplierId: item,
                          };
                      if (suppliers.isEmpty) {
                        return const FinanceEmptyState(
                          icon: Symbols.inventory_2_rounded,
                          title: 'Aucun fournisseur',
                          message:
                              'Ajoute ton premier fournisseur pour enregistrer les recharges réseaux.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: suppliers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final FinanceSupplier supplier = suppliers[index];
                          final SupplierAccount? account =
                              accounts[supplier.id];
                          return Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: IzyTelColors.surface,
                              borderRadius: BorderRadius.circular(
                                IzyTelRadii.card,
                              ),
                              border: Border.all(color: IzyTelColors.outline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: IzyTelColors.primarySoft,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Symbols.inventory_2_rounded,
                                        color: IzyTelColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            supplier.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: IzyTelColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            supplier.phoneNumber.isEmpty
                                                ? 'Téléphone non renseigné'
                                                : supplier.phoneNumber,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: IzyTelColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !_busy,
                                      onSelected: (String action) =>
                                          _handleSupplierMenu(supplier, action),
                                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Symbols.edit_rounded),
                                            title: Text('Modifier'),
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'toggle',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              supplier.isActive
                                                  ? Symbols.pause_circle_rounded
                                                  : Symbols.play_circle_rounded,
                                            ),
                                            title: Text(
                                              supplier.isActive
                                                  ? 'Désactiver'
                                                  : 'Réactiver',
                                            ),
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Symbols.delete_rounded,
                                              color: IzyTelColors.error,
                                            ),
                                            title: Text(
                                              'Supprimer',
                                              style: TextStyle(color: IzyTelColors.error),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Metric(
                                        label: 'Stock reçu',
                                        value: formatCfa(
                                          account?.totalRecharged ?? 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _Metric(
                                        label: 'Remboursé',
                                        value: formatCfa(
                                          account?.totalPaid ?? 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _Metric(
                                        label: 'Reste dû',
                                        value: formatCfa(account?.balance ?? 0),
                                        warning: (account?.balance ?? 0) > 0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: !_busy && supplier.isActive
                                            ? () => _recharge(supplier)
                                            : null,
                                        icon: const Icon(
                                          Symbols.add_card_rounded,
                                        ),
                                        label: const Text('Recharge'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed:
                                            !_busy &&
                                                (account?.balance ?? 0) > 0
                                            ? () => _pay(supplier, account)
                                            : null,
                                        icon: const Icon(
                                          Symbols.payments_rounded,
                                        ),
                                        label: const Text('Régler'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _openHistory(supplier),
                                    icon: const Icon(
                                      Symbols.history_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Historique'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
              );
            },
      ),
    );
  }
}

class _SupplierHistoryPage extends StatelessWidget {
  const _SupplierHistoryPage({
    required this.supplier,
    required this.repository,
  });

  final FinanceSupplier supplier;
  final FinanceOperationsRepository repository;

  String _date(DateTime value) {
    final DateTime d = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(title: Text('Historique · ${supplier.name}')),
      body: StreamBuilder<List<SupplierRecharge>>(
        stream: repository.watchSupplierRecharges(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<SupplierRecharge>> rechargeSnapshot,
            ) {
              return StreamBuilder<List<SupplierPayment>>(
                stream: repository.watchSupplierPayments(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<SupplierPayment>> paymentSnapshot,
                    ) {
                      final List<SupplierRecharge> recharges =
                          (rechargeSnapshot.data ?? const <SupplierRecharge>[])
                              .where(
                                (SupplierRecharge item) =>
                                    item.supplierId == supplier.id,
                              )
                              .toList(growable: false);
                      final List<SupplierPayment> payments =
                          (paymentSnapshot.data ?? const <SupplierPayment>[])
                              .where(
                                (SupplierPayment item) =>
                                    item.supplierId == supplier.id,
                              )
                              .toList(growable: false);

                      if (!rechargeSnapshot.hasData &&
                          !paymentSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (recharges.isEmpty && payments.isEmpty) {
                        return const FinanceEmptyState(
                          icon: Symbols.history_rounded,
                          title: 'Aucun mouvement',
                          message:
                              'Les recharges et règlements de ce fournisseur apparaîtront ici.',
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (recharges.isNotEmpty) ...[
                            const Text(
                              'Recharges',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...recharges.map(
                              (SupplierRecharge item) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: IzyTelColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      IzyTelRadii.card,
                                    ),
                                    border: Border.all(
                                      color: IzyTelColors.outline,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item.network.label} · ${item.agentName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _date(item.createdAt),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: IzyTelColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        'Principal ${formatCfaFull(item.principalAmount)} · bonus ${formatCfaFull(item.bonusAmount)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: IzyTelColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Reçu ${formatCfaFull(item.receivedAmount)} · dette ajoutée ${formatCfaFull(item.amountOwed)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if ((item.note ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.note!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: IzyTelColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (payments.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Règlements',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...payments.map(
                              (SupplierPayment item) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: IzyTelColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      IzyTelRadii.card,
                                    ),
                                    border: Border.all(
                                      color: IzyTelColors.outline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Symbols.payments_rounded,
                                        color: IzyTelColors.success,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              formatCfaFull(item.amount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '${item.channel.label} · ${item.reference}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    IzyTelColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _date(item.paidAt),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: IzyTelColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
              );
            },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.warning = false,
  });
  final String label;
  final String value;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IzyTelColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: IzyTelColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: warning ? IzyTelColors.warning : IzyTelColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
