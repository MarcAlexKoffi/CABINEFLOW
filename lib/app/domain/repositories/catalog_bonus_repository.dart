abstract interface class CatalogBonusRepository {
  Future<List<Map<String, dynamic>>> campaigns();
  Future<void> saveCampaign(
    Map<String, dynamic> payload, {
    String? id,
    int? version,
  });
  Future<void> campaignStatus(
    Map<String, dynamic> campaign,
    String status, {
    String? reference,
  });
  Future<List<Map<String, dynamic>>> routes();
  Future<void> validateRoute(
    Map<String, dynamic> route, {
    String? operatorReference,
  });
}
