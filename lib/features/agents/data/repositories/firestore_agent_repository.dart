import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreAgentRepository implements AgentRepository {
  FirestoreAgentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('agentProfiles');
  CollectionReference<Map<String, dynamic>> get _zones =>
      _firestore.collection('zones');
  CollectionReference<Map<String, dynamic>> get _issues =>
      _firestore.collection('agentIssues');
  CollectionReference<Map<String, dynamic>> get _networkTransactions =>
      _firestore.collection('networkTransactions');

  @override
  Stream<List<AgentDirectoryEntry>> watchAgents() {
    late final StreamController<List<AgentDirectoryEntry>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? profilesSub;
    QuerySnapshot<Map<String, dynamic>>? latestUsers;
    QuerySnapshot<Map<String, dynamic>>? latestProfiles;

    void emit() {
      final QuerySnapshot<Map<String, dynamic>>? users = latestUsers;
      final QuerySnapshot<Map<String, dynamic>>? profiles = latestProfiles;
      if (users == null || profiles == null || controller.isClosed) return;

      final Map<String, AgentProfile> profileByUserId =
          <String, AgentProfile>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in profiles.docs) {
        final AgentProfile? profile = _profileFromDocument(doc);
        if (profile != null) {
          profileByUserId[profile.userId] = profile;
        }
      }

      final List<AgentDirectoryEntry> entries =
          users.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data = doc.data();
                return AgentDirectoryEntry(
                  userId: doc.id,
                  name: _string(data['name'], fallback: 'Agent'),
                  email: _string(data['email']),
                  phoneNumber: _string(data['phoneNumber']),
                  isActive: data['isActive'] == true,
                  profile: profileByUserId[doc.id],
                );
              })
              .toList(growable: false)
            ..sort((AgentDirectoryEntry a, AgentDirectoryEntry b) {
              final int active = b.isActive.toString().compareTo(
                a.isActive.toString(),
              );
              if (active != 0) return active;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

      controller.add(List<AgentDirectoryEntry>.unmodifiable(entries));
    }

    controller = StreamController<List<AgentDirectoryEntry>>(
      onListen: () {
        usersSub = _users.where('role', isEqualTo: 'agent').snapshots().listen((
          snapshot,
        ) {
          latestUsers = snapshot;
          emit();
        }, onError: controller.addError);
        profilesSub = _profiles.snapshots().listen((snapshot) {
          latestProfiles = snapshot;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await usersSub?.cancel();
        await profilesSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Stream<AgentProfile?> watchAgentProfile(String agentId) {
    return _profiles.doc(agentId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return _profileFromSnapshot(snapshot);
    });
  }

  @override
  Stream<List<AgentZone>> watchZones() {
    return _zones.snapshots().map((snapshot) {
      final List<AgentZone> zones =
          snapshot.docs
              .map(_zoneFromDocument)
              .whereType<AgentZone>()
              .toList(growable: false)
            ..sort((a, b) {
              final int city = a.city.toLowerCase().compareTo(
                b.city.toLowerCase(),
              );
              if (city != 0) return city;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
      return List<AgentZone>.unmodifiable(zones);
    });
  }

  @override
  Stream<List<AgentIssue>> watchAgentIssues(String agentId) {
    return _issues.where('agentId', isEqualTo: agentId).snapshots().map((
      snapshot,
    ) {
      final List<AgentIssue> issues =
          snapshot.docs
              .map(_issueFromDocument)
              .whereType<AgentIssue>()
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List<AgentIssue>.unmodifiable(issues);
    });
  }

  @override
  Stream<List<AgentIssue>> watchAllAgentIssues() {
    return _issues.snapshots().map((snapshot) {
      final List<AgentIssue> issues =
          snapshot.docs
              .map(_issueFromDocument)
              .whereType<AgentIssue>()
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List<AgentIssue>.unmodifiable(issues);
    });
  }

  @override
  Future<List<StaffAccountSummary>> loadPendingAccounts() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _users
        .where('role', isEqualTo: 'pending')
        .get();
    final List<StaffAccountSummary> accounts =
        snapshot.docs
            .map((doc) => _accountFromDocument(doc))
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return List<StaffAccountSummary>.unmodifiable(accounts);
  }

  @override
  Future<void> activatePendingAccountAsAgent({
    required StaffAccountSummary account,
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef = _users.doc(
      account.userId,
    );
    final DocumentReference<Map<String, dynamic>> profileRef = _profiles.doc(
      account.userId,
    );

    final WriteBatch batch = _firestore.batch();
    batch.update(userRef, <String, dynamic>{
      'role': 'agent',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(profileRef, <String, dynamic>{
      'schemaVersion': 1,
      'userId': account.userId,
      'agentCode': _agentCode(account.userId),
      'availability': 'unavailable',
      'zoneIds': <String>[],
      'authorizedNetworks': <String>[],
      'activeNetworks': <String>[],
      'orangeCapacity': 0,
      'mtnCapacity': 0,
      'moovCapacity': 0,
      'dailyTransactionLimit': 500000,
      'maxTransactionsPerDay': 150,
      'lastCapacityUpdateAt': null,
      'lastOrangeMovementId': null,
      'lastMtnMovementId': null,
      'lastMoovMovementId': null,
      'lastSeenAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<void> saveAgentAdmin({
    required AgentDirectoryEntry agent,
    required AgentAdminUpdate update,
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef = _users.doc(
      agent.userId,
    );
    final DocumentReference<Map<String, dynamic>> profileRef = _profiles.doc(
      agent.userId,
    );
    final String actorId = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (actorId.isEmpty) {
      throw StateError('Session administrateur introuvable.');
    }

    final Map<AgentNetwork, DocumentReference<Map<String, dynamic>>>
    adjustmentRefs = <AgentNetwork, DocumentReference<Map<String, dynamic>>>{
      for (final AgentNetwork network in AgentNetwork.values)
        network: _networkTransactions.doc(),
    };

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> currentProfile =
          await transaction.get(profileRef);
      if (!currentProfile.exists || currentProfile.data() == null) {
        throw StateError(
          'Le profil opérationnel doit être créé avant de définir des capacités.',
        );
      }

      final Map<String, dynamic> current = currentProfile.data()!;
      final AgentProfile profile =
          agent.profile ?? _defaultProfile(agent.userId);
      final List<AgentNetwork> activeNetworks = profile.activeNetworks
          .where(update.authorizedNetworks.contains)
          .toList(growable: false);

      final Map<AgentNetwork, int> before = <AgentNetwork, int>{
        AgentNetwork.orange: _int(current['orangeCapacity']),
        AgentNetwork.mtn: _int(current['mtnCapacity']),
        AgentNetwork.moov: _int(current['moovCapacity']),
      };
      final Map<AgentNetwork, int> after = <AgentNetwork, int>{
        AgentNetwork.orange: update.orangeCapacity,
        AgentNetwork.mtn: update.mtnCapacity,
        AgentNetwork.moov: update.moovCapacity,
      };
      final List<AgentNetwork> changed = AgentNetwork.values
          .where((AgentNetwork network) => before[network] != after[network])
          .toList(growable: false);

      final Map<String, dynamic> profileData = <String, dynamic>{
        'schemaVersion': 1,
        'userId': agent.userId,
        'agentCode': profile.agentCode,
        'availability': update.isActive
            ? profile.availability.firestoreValue
            : AgentAvailability.unavailable.firestoreValue,
        'zoneIds': update.zoneIds,
        'authorizedNetworks': update.authorizedNetworks
            .map((AgentNetwork network) => network.firestoreValue)
            .toList(growable: false),
        'activeNetworks': update.isActive
            ? activeNetworks
                  .map((AgentNetwork network) => network.firestoreValue)
                  .toList(growable: false)
            : <String>[],
        'orangeCapacity': update.orangeCapacity,
        'mtnCapacity': update.mtnCapacity,
        'moovCapacity': update.moovCapacity,
        'dailyTransactionLimit': update.dailyTransactionLimit,
        'maxTransactionsPerDay': update.maxTransactionsPerDay,
        'lastCapacityUpdateAt': changed.isEmpty
            ? current['lastCapacityUpdateAt']
            : FieldValue.serverTimestamp(),
        'lastOrangeMovementId': current['lastOrangeMovementId'],
        'lastMtnMovementId': current['lastMtnMovementId'],
        'lastMoovMovementId': current['lastMoovMovementId'],
        'lastSeenAt': current['lastSeenAt'],
        'createdAt': current['createdAt'],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final AgentNetwork network in changed) {
        final DocumentReference<Map<String, dynamic>> movementRef =
            adjustmentRefs[network]!;
        profileData[_movementMarkerField(network)] = movementRef.id;
        final int capacityBefore = before[network]!;
        final int capacityAfter = after[network]!;
        transaction.set(
          movementRef,
          _manualCapacityMovementData(
            network: network,
            capacityBefore: capacityBefore,
            capacityAfter: capacityAfter,
            agentId: agent.userId,
            agentName: update.name.trim(),
            createdBy: actorId,
            createdByRole: 'admin',
          ),
        );
      }

      transaction.update(userRef, <String, dynamic>{
        'name': update.name.trim(),
        'phoneNumber': update.phoneNumber.trim(),
        'isActive': update.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(profileRef, profileData);
    });
  }

  @override
  Future<void> updateOwnOperations({
    required String agentId,
    required AgentOperationalUpdate update,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(agentId);
    final Map<AgentNetwork, DocumentReference<Map<String, dynamic>>>
    adjustmentRefs = <AgentNetwork, DocumentReference<Map<String, dynamic>>>{
      for (final AgentNetwork network in AgentNetwork.values)
        network: _networkTransactions.doc(),
    };

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await transaction.get(ref);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Ton profil agent n’est pas encore configuré.');
      }
      final AgentProfile? profile = _profileFromSnapshot(snapshot);
      if (profile == null) {
        throw StateError('Le profil agent est invalide.');
      }
      final Map<String, dynamic> current = snapshot.data()!;
      final List<AgentNetwork> active = update.activeNetworks
          .where(profile.authorizedNetworks.contains)
          .toList(growable: false);
      final Map<AgentNetwork, int> before = <AgentNetwork, int>{
        AgentNetwork.orange: profile.orangeCapacity,
        AgentNetwork.mtn: profile.mtnCapacity,
        AgentNetwork.moov: profile.moovCapacity,
      };
      final Map<AgentNetwork, int> after = <AgentNetwork, int>{
        AgentNetwork.orange: update.orangeCapacity,
        AgentNetwork.mtn: update.mtnCapacity,
        AgentNetwork.moov: update.moovCapacity,
      };
      final List<AgentNetwork> changed = AgentNetwork.values
          .where((AgentNetwork network) => before[network] != after[network])
          .toList(growable: false);

      final Map<String, dynamic> updates = <String, dynamic>{
        'availability': update.availability.firestoreValue,
        'activeNetworks': active
            .map((AgentNetwork network) => network.firestoreValue)
            .toList(growable: false),
        'orangeCapacity': update.orangeCapacity,
        'mtnCapacity': update.mtnCapacity,
        'moovCapacity': update.moovCapacity,
        'lastCapacityUpdateAt': changed.isEmpty
            ? current['lastCapacityUpdateAt']
            : FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final AgentNetwork network in changed) {
        final DocumentReference<Map<String, dynamic>> movementRef =
            adjustmentRefs[network]!;
        updates[_movementMarkerField(network)] = movementRef.id;
        transaction.set(
          movementRef,
          _manualCapacityMovementData(
            network: network,
            capacityBefore: before[network]!,
            capacityAfter: after[network]!,
            agentId: agentId,
            agentName: null,
            createdBy: agentId,
            createdByRole: 'agent',
          ),
        );
      }
      transaction.update(ref, updates);
    });
  }

  @override
  Future<String> createZone({
    required String name,
    required String city,
    required String region,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _zones.doc();
    await ref.set(<String, dynamic>{
      'schemaVersion': 1,
      'name': name.trim(),
      'city': city.trim(),
      'region': region.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> createIssue({
    required String agentId,
    required AgentIssueDraft issue,
  }) async {
    await _issues.add(<String, dynamic>{
      'schemaVersion': 1,
      'agentId': agentId,
      'type': issue.type,
      'network': issue.network?.firestoreValue,
      'description': issue.description.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'resolvedBy': null,
    });
  }

  @override
  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
    String? resolvedBy,
  }) async {
    final bool marksAsResolved = status == 'resolved' || status == 'cancelled';
    await _issues.doc(issueId).update(<String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': marksAsResolved ? FieldValue.serverTimestamp() : null,
      'resolvedBy': marksAsResolved ? resolvedBy : null,
    });
  }

  String _movementMarkerField(AgentNetwork network) {
    switch (network) {
      case AgentNetwork.orange:
        return 'lastOrangeMovementId';
      case AgentNetwork.mtn:
        return 'lastMtnMovementId';
      case AgentNetwork.moov:
        return 'lastMoovMovementId';
    }
  }

  Map<String, dynamic> _manualCapacityMovementData({
    required AgentNetwork network,
    required int capacityBefore,
    required int capacityAfter,
    required String agentId,
    required String? agentName,
    required String createdBy,
    required String createdByRole,
  }) {
    final int delta = capacityAfter - capacityBefore;
    if (delta == 0) {
      throw StateError('Un ajustement réseau doit modifier la capacité.');
    }
    return <String, dynamic>{
      'schemaVersion': 1,
      'network': network.firestoreValue,
      'direction': delta > 0 ? 'incoming' : 'outgoing',
      'type': 'manualAdjustment',
      'amount': delta.abs(),
      'capacityBefore': capacityBefore,
      'capacityAfter': capacityAfter,
      'agentId': agentId,
      'agentName': agentName?.trim().isEmpty == true ? null : agentName?.trim(),
      'orderId': null,
      'orderReference': null,
      'supplierId': null,
      'supplierName': null,
      'supplierRechargeId': null,
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  AgentProfile? _profileFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _profileFromMap(doc.id, doc.data());
  }

  AgentProfile? _profileFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic>? data = doc.data();
    if (data == null) return null;
    return _profileFromMap(doc.id, data);
  }

  AgentProfile? _profileFromMap(String docId, Map<String, dynamic> data) {
    final String userId = _string(data['userId'], fallback: docId);
    final String code = _string(data['agentCode']);
    if (userId.isEmpty || code.isEmpty) return null;
    return AgentProfile(
      userId: userId,
      agentCode: code,
      availability: _availability(data['availability']),
      zoneIds: _stringList(data['zoneIds']),
      authorizedNetworks: _networkList(data['authorizedNetworks']),
      activeNetworks: _networkList(data['activeNetworks']),
      orangeCapacity: _int(data['orangeCapacity']),
      mtnCapacity: _int(data['mtnCapacity']),
      moovCapacity: _int(data['moovCapacity']),
      dailyTransactionLimit: _int(data['dailyTransactionLimit']),
      maxTransactionsPerDay: _int(data['maxTransactionsPerDay']),
      lastCapacityUpdateAt: _date(data['lastCapacityUpdateAt']),
      lastSeenAt: _date(data['lastSeenAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  AgentZone? _zoneFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String name = _string(data['name']);
    final String city = _string(data['city']);
    final String region = _string(data['region']);
    if (name.isEmpty || city.isEmpty || region.isEmpty) return null;
    return AgentZone(
      id: doc.id,
      name: name,
      city: city,
      region: region,
      isActive: data['isActive'] == true,
    );
  }

  AgentIssue? _issueFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? createdAt = _date(data['createdAt']);
    if (createdAt == null) return null;
    return AgentIssue(
      id: doc.id,
      agentId: _string(data['agentId']),
      type: _string(data['type']),
      network: _network(data['network']),
      description: _string(data['description']),
      status: _string(data['status']),
      createdAt: createdAt,
      updatedAt: _date(data['updatedAt']),
      resolvedAt: _date(data['resolvedAt']),
      resolvedBy: _nullableString(data['resolvedBy']),
    );
  }

  StaffAccountSummary _accountFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return StaffAccountSummary(
      userId: doc.id,
      name: _string(data['name'], fallback: 'Nouvel utilisateur'),
      email: _string(data['email']),
      phoneNumber: _string(data['phoneNumber']),
      role: _string(data['role'], fallback: 'pending'),
      isActive: data['isActive'] == true,
    );
  }

  AgentProfile _defaultProfile(String userId) {
    return AgentProfile(
      userId: userId,
      agentCode: _agentCode(userId),
      availability: AgentAvailability.unavailable,
      zoneIds: const <String>[],
      authorizedNetworks: const <AgentNetwork>[],
      activeNetworks: const <AgentNetwork>[],
      orangeCapacity: 0,
      mtnCapacity: 0,
      moovCapacity: 0,
      dailyTransactionLimit: 500000,
      maxTransactionsPerDay: 150,
    );
  }

  String _agentCode(String uid) {
    final String compact = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final String suffix = compact.length <= 6
        ? compact.toUpperCase()
        : compact.substring(0, 6).toUpperCase();
    return 'AG-$suffix';
  }

  AgentAvailability _availability(Object? value) {
    return value == 'available'
        ? AgentAvailability.available
        : AgentAvailability.unavailable;
  }

  List<AgentNetwork> _networkList(Object? value) {
    if (value is! List) return const <AgentNetwork>[];
    return value
        .map(_network)
        .whereType<AgentNetwork>()
        .toSet()
        .toList(growable: false);
  }

  AgentNetwork? _network(Object? value) {
    if (value is! String) return null;
    for (final AgentNetwork network in AgentNetwork.values) {
      if (network.firestoreValue == value) return network;
    }
    return null;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  String? _nullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
