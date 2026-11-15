import 'dart:convert';

const catalogImportHeaders = <String>[
  'action',
  'code_offre',
  'operateur',
  'famille',
  'type_forfait',
  'nom_affiche',
  'prix_fcfa',
  'volume_data',
  'unite_data',
  'minutes_appels',
  'nombre_sms',
  'duree_valeur',
  'duree_unite',
  'statut',
  'mis_en_avant',
  'ordre_affichage',
  'activable_pour_tiers',
  'canal_activation',
  'reference_operateur',
  'verifie_le',
  'source_url',
  'commentaire',
];

Map<String, dynamic> catalogMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class CatalogImportConfiguration {
  CatalogImportConfiguration(Map<String, dynamic> value)
    : version =
          (catalogMap(value['settings'])['version'] as num?)?.toInt() ?? 1,
      verificationDays =
          (catalogMap(value['settings'])['verification_max_age_days'] as num?)
              ?.toInt(),
      families = (value['families'] as List? ?? const [])
          .map(catalogMap)
          .toList();
  final int version;
  final int? verificationDays;
  final List<Map<String, dynamic>> families;
  List<String> familiesFor(String? network) =>
      families
          .where(
            (f) =>
                f['enabled'] == true &&
                (network == null || f['network'] == network.toUpperCase()),
          )
          .map((f) => f['code'].toString())
          .toSet()
          .toList()
        ..sort();
}

class CatalogImportPage {
  CatalogImportPage(Map<String, dynamic> value)
    : job = catalogMap(value['job']),
      summary = catalogMap(value['summary']),
      lines = (value['lines'] as List? ?? const []).map(catalogMap).toList(),
      filteredTotal = (value['filteredTotal'] as num?)?.toInt() ?? 0;
  final Map<String, dynamic> job;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> lines;
  final int filteredTotal;
  String get id => job['id'] as String;
  String get status => job['status'] as String;
  int get total => (job['total'] as num).toInt();
  int get cursor => (job['cursor'] as num).toInt();
  int count(String key) => (summary[key] as num?)?.toInt() ?? 0;
  int get changes => count('create') + count('update') + count('deactivate');
}

String catalogImportError(Object error) {
  final text = error.toString();
  if (text.contains('CATALOG_VERIFICATION_REQUIRED')) {
    return 'Renseignez le code et les vérifications de l’offre avant de la publier.';
  }
  if (text.contains('23505') || text.contains('duplicate key')) {
    return 'Ce code appartient déjà à une autre offre. Choisissez un code distinct.';
  }
  if (text.contains('ADMIN_REQUIRED')) {
    return 'Seul un administrateur actif peut gérer les imports.';
  }
  if (text.contains('CATALOG_RESTORE_CONFLICT')) {
    return 'Restauration bloquée : une offre a été modifiée après cet import. Consultez son historique.';
  }
  if (text.contains('CATALOG_VERSION_CONFLICT')) {
    return 'Cette offre a changé. Fermez la fiche, actualisez le catalogue et recommencez.';
  }
  if (text.contains('CATALOG_CODE_IMMUTABLE')) {
    return 'Le code permanent de cette offre ne peut plus être modifié.';
  }
  if (text.contains('CATALOG_STRUCTURED_EDIT_REQUIRED')) {
    return 'Cette offre a été structurée depuis l’ouverture de la fiche. Actualisez le catalogue et ouvrez sa fiche de vérification.';
  }
  if (text.contains('CATALOG_PUBLICATION_BLOCKED') ||
      text.contains('CATALOG_VALIDATION')) {
    final start = text.indexOf('['), end = text.indexOf(']');
    if (start >= 0 && end > start) {
      try {
        final errors = jsonDecode(text.substring(start, end + 1));
        if (errors is List) return errors.whereType<String>().join('\n');
      } catch (_) {
        /* Keep the bounded generic explanation below. */
      }
    }
    return 'Vérifiez les champs, la date, le canal d’activation, l’éligibilité pour un tiers et la preuve de livraison. Les règles serveur doivent autoriser la publication.';
  }
  if (text.contains('FORMULA')) {
    return 'Une formule a été détectée dans OFFRES. Remplacez-la par une valeur avant l’import.';
  }
  if (text.contains('MACRO')) {
    return 'Les fichiers contenant des macros ne sont pas acceptés.';
  }
  if (text.contains('OFFRES_MISSING')) {
    return 'La feuille OFFRES est absente du classeur.';
  }
  if (text.contains('HEADERS')) {
    return 'Utilisez les 22 colonnes du modèle IzyTel, sans doublon.';
  }
  if (text.contains('TOO_LARGE') || text.contains('TOO_MANY')) {
    return 'Limites dépassées : 5 Mo, 20 Mo décompressés et 5 000 lignes maximum.';
  }
  if (text.contains('CATALOG_FILE') ||
      text.contains('CATALOG_XML') ||
      text.contains('CATALOG_ZIP')) {
    return 'Classeur XLSX invalide ou non pris en charge. Utilisez le modèle fourni.';
  }
  if (text.contains('PGRST202') || text.contains('404')) {
    return 'Le service d’import doit être installé sur le serveur. Le catalogue actuel reste disponible.';
  }
  return 'Opération interrompue. Vous pouvez retrouver et reprendre le lot depuis l’historique, sans double application.';
}

String catalogCsv(Iterable<Map<String, dynamic>> rows) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  return '\uFEFF${<List<Object?>>[catalogImportHeaders, ...rows.map((row) => catalogImportHeaders.map((h) => h == 'action' ? 'UPSERT' : row[h]).toList())].map((row) => row.map(cell).join(';')).join('\r\n')}';
}

String catalogReportJson(
  CatalogImportPage page,
  List<Map<String, dynamic>> lines,
) => const JsonEncoder.withIndent(
  '  ',
).convert({'job': page.job, 'summary': page.summary, 'lines': lines});
