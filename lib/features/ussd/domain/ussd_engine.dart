/// Pure USSD grammar. No operator shortcut is bundled with the application.
class UssdValidationException implements Exception {
  const UssdValidationException(this.code);
  final String code;
  @override
  String toString() => code;
}

class UssdPhoneNumber {
  const UssdPhoneNumber._(this.local, this.network);
  final String local;
  final String? network;

  static UssdPhoneNumber parse(String input) {
    // Never strip arbitrary input: letters, URI syntax and USSD tokens fail.
    if (input.length > 80 || !RegExp(r'^[+0-9 \-]+$').hasMatch(input)) {
      throw const UssdValidationException('invalid_beneficiary');
    }
    var digits = input.replaceAll(RegExp(r'[ \-]'), '');
    if (digits.startsWith('+225')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('00225')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('225')) {
      digits = digits.substring(3);
    }
    if (!RegExp(r'^(01|05|07)[0-9]{8}$').hasMatch(digits)) {
      throw const UssdValidationException('invalid_beneficiary');
    }
    return UssdPhoneNumber._(digits, switch (digits.substring(0, 2)) {
      '07' => 'orange',
      '05' => 'mtn',
      '01' => 'moov',
      _ => null,
    });
  }
}

class UssdValues {
  const UssdValues({
    this.beneficiary,
    this.amount,
    this.offerCode,
    this.quantity,
  });
  final String? beneficiary;
  final int? amount;
  final String? offerCode;
  final int? quantity;
}

class UssdEngine {
  const UssdEngine._();
  static const variables = {'msisdn_local', 'amount', 'offer_code', 'quantity'};
  static final _variable = RegExp(r'\{\{([a-z_]+)\}\}');
  static final _code = RegExp(r'^\*{1,2}[0-9]+(?:\*[0-9]+)*#$');
  static const manualMessage =
      'Raccourci indisponible. Vous pouvez poursuivre le traitement manuel.';
  static const mismatchMessage =
      'Le préfixe du bénéficiaire correspond à un autre opérateur. Vérifiez le réseau avant de lancer l’opération.';

  static Set<String> validateTemplate(String template) {
    if (template.isEmpty || template.length > 512) {
      throw const UssdValidationException('invalid_template');
    }
    final used = <String>{};
    final sample = template.replaceAllMapped(_variable, (match) {
      final name = match.group(1)!;
      if (!variables.contains(name)) {
        throw const UssdValidationException('unknown_variable');
      }
      used.add(name);
      return '1';
    });
    validateCode(sample);
    return used;
  }

  static void validateCode(String code) {
    if (code.length > 182 || !_code.hasMatch(code)) {
      throw const UssdValidationException('invalid_template');
    }
  }

  static String generate(String template, UssdValues values) {
    validateTemplate(template);
    final code = template.replaceAllMapped(_variable, (match) {
      return switch (match.group(1)!) {
        'msisdn_local' => UssdPhoneNumber.parse(values.beneficiary ?? '').local,
        'amount' => _positive(values.amount, 100000000, 'missing_amount'),
        'quantity' => _positive(values.quantity, 999999, 'missing_quantity'),
        'offer_code' => _offerCode(values.offerCode),
        _ => throw const UssdValidationException('unknown_variable'),
      };
    });
    validateCode(code);
    return code;
  }

  static String _positive(int? value, int max, String error) {
    if (value == null || value <= 0 || value > max) {
      throw UssdValidationException(error);
    }
    return value.toString();
  }

  static String _offerCode(String? value) {
    if (value == null || !RegExp(r'^[0-9]{1,20}$').hasMatch(value)) {
      throw const UssdValidationException('missing_offer_code');
    }
    return value;
  }

  static String message(String reason) => switch (reason) {
    'invalid_beneficiary' =>
      'Numéro bénéficiaire invalide. Vérifiez les informations de la commande.',
    'ambiguous_rule' =>
      'Plusieurs règles sont en conflit. Le Manager peut signaler cette anomalie.',
    'rule_changed' =>
      'Le raccourci a changé. Actualisez puis vérifiez à nouveau les informations.',
    'unknown_variable' => 'Variable inconnue dans le template.',
    'missing_offer_code' =>
      'Le code opérateur de cette offre n’est pas renseigné.',
    'missing_quantity' => 'La quantité autorisée n’est pas renseignée.',
    'missing_amount' => 'Le montant est absent ou invalide.',
    'invalid_template' => 'Syntaxe USSD invalide ou trop longue.',
    'order_not_processable' =>
      'Acceptez et démarrez le traitement de la commande avant de lancer le raccourci.',
    'dialer_unavailable' =>
      'Aucun composeur Android compatible n’est disponible.',
    _ => manualMessage,
  };
}

/// Mirrors server selection for previews and fixtures. The server is authoritative
/// for assignments, time, rule selection and every real launch.
class UssdRule {
  const UssdRule({
    required this.id,
    required this.version,
    required this.network,
    required this.service,
    required this.scope,
    required this.template,
    required this.priority,
    required this.status,
    this.familyId,
    this.offerId,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.note = '',
    this.updatedBy = '',
    this.updatedAt,
    this.validationSimType,
  });
  final String id, network, service, scope, template, status, note, updatedBy;
  final String? familyId, offerId, validationSimType;
  final int version, priority;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil, updatedAt;

  factory UssdRule.fromJson(Map<String, dynamic> row) => UssdRule(
    id: row['id'] as String,
    version: (row['version'] as num).toInt(),
    network: row['network'] as String,
    service: row['service'] as String,
    scope: row['actor_scope'] as String,
    template: row['ussd_template'] as String,
    priority: (row['priority'] as num).toInt(),
    status: row['status'] as String,
    familyId: row['family_id'] as String?,
    offerId: row['offer_id'] as String?,
    effectiveFrom: DateTime.parse(row['effective_from'] as String),
    effectiveUntil: DateTime.tryParse(row['effective_until'] as String? ?? ''),
    note: row['internal_note'] as String? ?? '',
    updatedBy: row['updated_by'] as String? ?? '',
    updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
    validationSimType: row['validation_sim_type'] as String?,
  );

  int get level => offerId != null
      ? 3
      : familyId != null
      ? 2
      : 1;

  static UssdRule? select(
    Iterable<UssdRule> rules, {
    required String network,
    required String service,
    required String actor,
    required DateTime now,
    String? offerId,
    String? familyId,
  }) {
    final matching =
        rules
            .where(
              (r) =>
                  r.network == network &&
                  r.service == service &&
                  (r.scope == 'both' || r.scope == actor) &&
                  r.status == 'active' &&
                  !now.isBefore(r.effectiveFrom) &&
                  (r.effectiveUntil == null ||
                      now.isBefore(r.effectiveUntil!)) &&
                  (r.offerId == null || r.offerId == offerId) &&
                  (r.familyId == null || r.familyId == familyId),
            )
            .toList()
          ..sort((a, b) {
            final level = b.level.compareTo(a.level);
            return level != 0 ? level : b.priority.compareTo(a.priority);
          });
    if (matching.isEmpty) return null;
    if (matching.length > 1 &&
        matching[0].level == matching[1].level &&
        matching[0].priority == matching[1].priority) {
      throw const UssdValidationException('ambiguous_rule');
    }
    return matching.first;
  }
}
