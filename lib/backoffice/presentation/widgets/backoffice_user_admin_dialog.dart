import 'package:cabine_flow/backoffice/data/repositories/backoffice_user_administration_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:flutter/material.dart';

class BackofficeUserAdminDialog extends StatefulWidget {
  const BackofficeUserAdminDialog({
    super.key,
    required this.administration,
    this.user,
  });
  final BackofficeUserAdministration administration;
  final BackofficeUserAccount? user;
  @override
  State<BackofficeUserAdminDialog> createState() =>
      _BackofficeUserAdminDialogState();
}

class _BackofficeUserAdminDialogState extends State<BackofficeUserAdminDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _reason = TextEditingController();
  late final Future<List<UserAdminZone>> _loading;
  final _requestId = BackofficeUserAdministrationRepository.newRequestId();
  final Set<String> _zones = {};
  final Set<String> _networks = {};
  String? _role;
  late bool _active;
  bool _busy = false;
  bool _repair = false;
  Map<String, dynamic>? _attempt;
  String? _error;
  bool get _networkRole => _role == 'agent' || _role == 'cabiniste';

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phoneNumber ?? '');
    _role = switch (user?.role) {
      BackofficeAccountRole.administrator => 'admin',
      BackofficeAccountRole.manager => 'manager',
      BackofficeAccountRole.agent => 'agent',
      BackofficeAccountRole.cabiniste => 'cabiniste',
      _ => null,
    };
    _active = user?.isActive ?? true;
    _loading = _load();
  }

  Future<List<UserAdminZone>> _load() async {
    final zones = await widget.administration.loadZones();
    if (widget.user != null) {
      final details = await widget.administration.loadDetails(widget.user!);
      _zones.addAll(details.zoneIds);
      _networks.addAll(details.authorizedNetworks);
      if (details.email?.trim().isNotEmpty == true) {
        _email.text = details.email!;
      }
    }
    return zones;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _repair) return;
    if (_attempt == null) {
      if (_form.currentState == null || !_form.currentState!.validate()) return;
      if (_role != 'admin' && _zones.isEmpty) {
        setState(() => _error = 'Sélectionnez au moins une zone.');
        return;
      }
      if (_networkRole && _networks.isEmpty) {
        setState(() => _error = 'Sélectionnez au moins un réseau autorisé.');
        return;
      }
      _attempt = {
        'action': widget.user == null ? 'create' : 'update',
        'requestId': _requestId,
        'uid': ?widget.user?.id,
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'role': _role,
        'isActive': _active,
        'zoneIds': _role == 'admin' ? <String>[] : _zones.toList(),
        'authorizedNetworks': _networkRole ? _networks.toList() : <String>[],
        'reason': _reason.text.trim(),
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.administration.send(_attempt!);
      if (mounted) Navigator.of(context).pop(true);
    } on UserAdminException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _repair =
            error.requiresRepair || error.code == 'OPERATION_REQUIRES_REPAIR';
        if (_repair && error.operationId == null) {
          _error = '${error.message} Référence : $_requestId';
        }
        if (!_repair &&
            ![
              'INVALID_RESPONSE',
              'ADMIN_OPERATION_FAILED',
              'IDEMPOTENCY_CONFLICT',
            ].contains(error.code)) {
          _attempt = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Le résultat de la demande est incertain. Réessayez cette même demande ou faites vérifier la référence $_requestId.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.user == null ? 'Nouvel utilisateur' : 'Modifier le compte',
    ),
    content: SizedBox(
      width: 600,
      child: FutureBuilder<List<UserAdminZone>>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Impossible de charger les informations métier. ${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final zones = snapshot.data!;
          final unknown = _zones.difference(zones.map((z) => z.id).toSet());
          return SingleChildScrollView(
            child: Form(
              key: _form,
              child: AbsorbPointer(
                absorbing: _busy || _attempt != null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.user != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Après modification, l’utilisateur doit se reconnecter et réactiver sa disponibilité opérationnelle.',
                        ),
                      ),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      maxLength: 80,
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'Indiquez un nom.'
                          : null,
                    ),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail de connexion',
                        helperText:
                            'Utilisez l’adresse réelle du compte Firebase.',
                      ),
                      maxLength: 180,
                      validator: (v) =>
                          v == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(v.trim())
                          ? 'Indiquez un e-mail valide.'
                          : null,
                    ),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      maxLength: 30,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Rôle'),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Administrateur'),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(value: 'agent', child: Text('Agent')),
                        DropdownMenuItem(
                          value: 'cabiniste',
                          child: Text('Cabiniste'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _role = v),
                      validator: (v) =>
                          v == null ? 'Choisissez un rôle canonique.' : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Compte actif'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                    if (_role != null && _role != 'admin') ...[
                      const Text('Zones autorisées'),
                      for (final zone in zones)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(zone.name),
                          subtitle:
                              _role == 'manager' &&
                                  zone.managerUid != null &&
                                  zone.managerUid != widget.user?.id
                              ? const Text('Déjà affectée à un autre Manager')
                              : null,
                          value: _zones.contains(zone.id),
                          onChanged:
                              _role == 'manager' &&
                                  zone.managerUid != null &&
                                  zone.managerUid != widget.user?.id
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    _zones.add(zone.id);
                                  } else {
                                    _zones.remove(zone.id);
                                  }
                                }),
                        ),
                      for (final id in unknown)
                        CheckboxListTile(
                          title: Text('Zone indisponible : $id'),
                          value: true,
                          onChanged: (_) => setState(() => _zones.remove(id)),
                        ),
                    ],
                    if (_networkRole) ...[
                      const Text('Réseaux autorisés'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final n in ['orange', 'mtn', 'moov'])
                            FilterChip(
                              label: Text(n.toUpperCase()),
                              selected: _networks.contains(n),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _networks.add(n);
                                } else {
                                  _networks.remove(n);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    TextFormField(
                      controller: _reason,
                      decoration: const InputDecoration(
                        labelText: 'Motif de la modification (facultatif)',
                      ),
                      maxLength: 1200,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
    actions: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _busy || _repair ? null : _submit,
        child: Text(
          _busy
              ? 'En cours…'
              : _attempt == null
              ? 'Enregistrer'
              : 'Réessayer la même demande',
        ),
      ),
    ],
  );
}
