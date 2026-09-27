import 'dart:async';

import 'package:cabine_flow/backoffice/data/repositories/supabase_territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/models/territory_models.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';

class SupabaseAgentZoneRepository {
  SupabaseAgentZoneRepository({SupabaseTerritoryRepository? territoryRepository})
    : _territoryRepository =
          territoryRepository ?? SupabaseTerritoryRepository();

  final SupabaseTerritoryRepository _territoryRepository;

  Stream<List<AgentZone>> watchZones() {
    return _territoryRepository.watchZones().map(_mapZones);
  }

  Future<String> createZone({
    required String name,
    required String city,
    required String region,
  }) async {
    final TerritoryZone zone = await _territoryRepository.createZone(
      TerritoryZoneDraft(
        name: name,
        city: city,
        region: region,
        isActive: true,
      ),
    );
    return zone.id;
  }

  List<AgentZone> _mapZones(List<TerritoryZone> zones) {
    return List<AgentZone>.unmodifiable(
      zones
          .map(
            (TerritoryZone zone) => AgentZone(
              id: zone.id,
              name: zone.name,
              city: zone.city,
              region: zone.region,
              isActive: zone.isActive,
            ),
          )
          .toList(growable: false),
    );
  }
}
