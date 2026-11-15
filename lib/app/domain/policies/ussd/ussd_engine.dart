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
    this.secretCode,
  });
  final String? beneficiary;
  final int? amount;
  final String? offerCode;
  final int? quantity;
  // Preview input only. Real launches use the code resolved by the server.
  final String? secretCode;
}

class UssdEngine {
  const UssdEngine._();
  static const defaultSecretCode = '0000';
  static const variables = {
    'msisdn_local',
    'amount',
    'offer_code',
    'quantity',
    'secret_code',
  };
  static final _variable = RegExp(r'\{\{([^{}]+)\}\}');
  static final _code = RegExp(r'^(?:\*{1,2}|#)[0-9]+(?:\*[0-9]+)*#$');
  static const _aliases = {
    'numero_du_destinataire': 'msisdn_local',
    'numero': 'msisdn_local',
    'beneficiaire': 'msisdn_local',
    'montant': 'amount',
    'code_secret': 'secret_code',
    'code secret': 'secret_code',
    'code_offre': 'offer_code',
    'code offre': 'offer_code',
    'quantite': 'quantity',
  };

  static String _fold(String value) {
    var result = value.toLowerCase();
    const groups = {
      'a': 'àáâãäå',
      'c': 'ç',
      'e': 'èéêë',
      'i': 'ìíîï',
      'n': 'ñ',
      'o': 'òóôõö',
      'u': 'ùúûü',
      'y': 'ýÿ',
    };
    for (final group in groups.entries) {
      for (final accent in group.value.split('')) {
        result = result.replaceAll(accent, group.key);
      }
    }
    return result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }

  /// Only complete known tokens are replaced; numeric codes and punctuation
  /// are preserved. Unknown/malformed placeholders still fail validation.
  static String normalizeTemplate(String template) {
    // Validation reports oversized input; normalization must stay bounded even
    // before the editor has validated a pasted value.
    if (template.length > 512) return template;
    String? canonical(String raw) {
      final token = _fold(raw);
      return variables.contains(token) ? token : _aliases[token];
    }

    final placeholders = template.replaceAllMapped(_variable, (match) {
      final name = canonical(match.group(1)!);
      return name == null ? match.group(0)! : '{{$name}}';
    });
    return placeholders.replaceAllMapped(RegExp(r'[^*#{}]+'), (match) {
      // Tokens inside canonical braces must not be wrapped a second time.
      if (match.start > 0 && placeholders[match.start - 1] == '{') {
        return match.group(0)!;
      }
      final name = canonical(match.group(0)!);
      return name == null ? match.group(0)! : '{{$name}}';
    });
  }

  static const manualMessage =
      'Raccourci indisponible. Vous pouvez poursuivre le traitement manuel.';
  static const mismatchMessage =
      'Le préfixe du bénéficiaire correspond à un autre opérateur. Vérifiez le réseau avant de lancer l’opération.';

  static Set<String> validateTemplate(String template) {
    template = normalizeTemplate(template);
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
    template = normalizeTemplate(template);
    validateTemplate(template);
    final code = template.replaceAllMapped(_variable, (match) {
      return switch (match.group(1)!) {
        'msisdn_local' => UssdPhoneNumber.parse(values.beneficiary ?? '').local,
        'amount' => _positive(values.amount, 100000000, 'missing_amount'),
        'quantity' => _positive(values.quantity, 999999, 'missing_quantity'),
        'offer_code' => _offerCode(values.offerCode),
        'secret_code' => _secretCode(values.secretCode),
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

  static String _secretCode(String? value) {
    final secret = value ?? defaultSecretCode;
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(secret)) {
      throw const UssdValidationException('invalid_secret_code');
    }
    return secret;
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
    'invalid_secret_code' => 'Le code secret configuré est invalide.',
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
    this.purpose = 'order',
  });
  final String id, network, service, scope, template, status, note, updatedBy;
  final String purpose;
  final String? familyId, offerId, validationSimType;
  final int version, priority;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil, updatedAt;

  factory UssdRule.fromJson(Map<String, dynamic> row) => UssdRule(
    id: row['id'] as String,
    version: (row['version'] as num).toInt(),
    network: row['network'] as String,
    service: row['service'] as String? ?? '',
    purpose: row['purpose'] as String? ?? 'order',
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
                  r.purpose == 'order' &&
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
