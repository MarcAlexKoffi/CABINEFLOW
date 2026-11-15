import 'dart:typed_data';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:cabine_flow/app/domain/repositories/catalog_import_repository.dart';

class CatalogImportFixture implements CatalogImportRepository {
  String status = 'preview';
  bool loseReply = false;
  int cursor = 0;
  final calls = <String>[];
  Map<String, dynamic> get document => {
    'job': {
      'id': '00000000-0000-4000-8000-000000000001',
      'file_name': 'Offres.xlsx',
      'status': status,
      'total': 3,
      'cursor': cursor,
    },
    'summary': {
      'create': 1,
      'update': 0,
      'deactivate': 0,
      'unchanged': 0,
      'error': 2,
      'applied': cursor > 0 ? 1 : 0,
      'conflict': 0,
    },
    'filteredTotal': 3,
    'lines': [
      {
        'line_number': 2,
        'code': 'OR-NEW',
        'kind': 'create',
        'data': {
          'nom_affiche': '1,5 GO',
          'prix_fcfa': '1000',
          'statut': 'ACTIF',
        },
        'changes': {},
        'errors': [],
      },
      {
        'line_number': 3,
        'code': 'DUP',
        'kind': 'error',
        'data': {},
        'changes': {},
        'errors': ['Code répété aux lignes 3, 4.'],
      },
      {
        'line_number': 4,
        'code': 'DUP',
        'kind': 'error',
        'data': {},
        'changes': {},
        'errors': ['Code répété aux lignes 3, 4.'],
      },
    ],
  };
  @override
  Future<CatalogImportPage> importPage(
    String id, {
    int offset = 0,
    String filter = 'all',
  }) async {
    calls.add('read:$id:$offset:$filter');
    return CatalogImportPage(document);
  }

  @override
  Future<CatalogImportPage> confirmImport(
    String id, {
    required bool allowPartial,
  }) async {
    if (!allowPartial) throw StateError('Explicit consent required');
    calls.add('confirm:$id');
    status = 'running';
    return CatalogImportPage(document);
  }

  @override
  Future<CatalogImportPage> applyImportBatch(String id) async {
    calls.add('apply:$id');
    if (loseReply) {
      loseReply = false;
      cursor = 1;
      throw StateError('response lost');
    }
    status = 'completed';
    cursor = 3;
    return CatalogImportPage(document);
  }

  @override
  Future<CatalogImportPage> restoreImport(String id) async {
    calls.add('restore:$id');
    status = 'restored';
    return CatalogImportPage(document);
  }

  @override
  Future<CatalogImportConfiguration> importConfiguration() async =>
      CatalogImportConfiguration({
        'settings': {'version': 1, 'verification_max_age_days': null},
        'families': [
          for (final network in ['ORANGE', 'MTN', 'MOOV'])
            {
              'network': network,
              'code': 'INTERNET',
              'enabled': true,
              'conditional': false,
            },
        ],
      });
  @override
  Future<void> saveImportConfiguration(
    CatalogImportConfiguration config,
    int? days,
    List<Map<String, dynamic>> families,
  ) async {
    calls.add('configuration');
  }

  @override
  Future<String> prepareImport({
    required Uint8List bytes,
    required String fileName,
    required String requestId,
  }) async => requestId;
  @override
  Future<String> prepareBulk({
    required String requestId,
    required String operation,
    String? value,
    required List<Map<String, dynamic>> items,
  }) async => requestId;
  @override
  Future<List<Map<String, dynamic>>> importHistory({int offset = 0}) async => [
    document['job'] as Map<String, dynamic>,
  ];
  @override
  Future<List<Map<String, dynamic>>> offerHistory(String id) async => [];
  @override
  Future<void> saveStructuredOffer({
    String? id,
    int? version,
    required Map<String, dynamic> data,
    String? deliveryProof,
  }) async {
    calls.add('save:${data['code_offre']}');
  }
}
