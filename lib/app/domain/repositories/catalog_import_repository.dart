import 'dart:typed_data';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';

abstract class CatalogImportRepository {
  Future<CatalogImportConfiguration> importConfiguration();
  Future<void> saveImportConfiguration(
    CatalogImportConfiguration config,
    int? days,
    List<Map<String, dynamic>> families,
  );
  Future<String> prepareImport({
    required Uint8List bytes,
    required String fileName,
    required String requestId,
  });
  Future<CatalogImportPage> importPage(
    String id, {
    int offset = 0,
    String filter = 'all',
  });
  Future<CatalogImportPage> confirmImport(
    String id, {
    required bool allowPartial,
  });
  Future<CatalogImportPage> applyImportBatch(String id);
  Future<String> prepareBulk({
    required String requestId,
    required String operation,
    String? value,
    required List<Map<String, dynamic>> items,
  });
  Future<CatalogImportPage> restoreImport(String id);
  Future<List<Map<String, dynamic>>> importHistory({int offset = 0});
  Future<List<Map<String, dynamic>>> offerHistory(String id);
  Future<void> saveStructuredOffer({
    String? id,
    int? version,
    required Map<String, dynamic> data,
    String? deliveryProof,
  });
}
