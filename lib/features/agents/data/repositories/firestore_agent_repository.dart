import 'dart:async';

import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final DocumentSnapshot<Map<String, dynamic>> currentProfile =
        await profileRef.get();

    final AgentProfile profile = agent.profile ?? _defaultProfile(agent.userId);
    final List<AgentNetwork> activeNetworks = profile.activeNetworks
        .where(update.authorizedNetworks.contains)
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
          .map((network) => network.firestoreValue)
          .toList(growable: false),
      'activeNetworks': update.isActive
          ? activeNetworks
                .map((network) => network.firestoreValue)
                .toList(growable: false)
          : <String>[],
      'orangeCapacity': update.orangeCapacity,
      'mtnCapacity': update.mtnCapacity,
      'moovCapacity': update.moovCapacity,
      'dailyTransactionLimit': update.dailyTransactionLimit,
      'maxTransactionsPerDay': update.maxTransactionsPerDay,
      'lastCapacityUpdateAt': profile.lastCapacityUpdateAt,
      'lastSeenAt': profile.lastSeenAt,
      'createdAt': currentProfile.exists
          ? (currentProfile.data()?['createdAt'] ??
                FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final WriteBatch batch = _firestore.batch();
    batch.update(userRef, <String, dynamic>{
      'name': update.name.trim(),
      'phoneNumber': update.phoneNumber.trim(),
      'isActive': update.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(profileRef, profileData);
    await batch.commit();
  }

  @override
  Future<void> updateOwnOperations({
    required String agentId,
    required AgentOperationalUpdate update,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(agentId);
    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(ref);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Ton profil agent n’est pas encore configuré.');
      }
      final AgentProfile? profile = _profileFromSnapshot(snapshot);
      if (profile == null) {
        throw StateError('Le profil agent est invalide.');
      }
      final List<AgentNetwork> active = update.activeNetworks
          .where(profile.authorizedNetworks.contains)
          .toList(growable: false);
      transaction.update(ref, <String, dynamic>{
        'availability': update.availability.firestoreValue,
        'activeNetworks': active
            .map((network) => network.firestoreValue)
            .toList(growable: false),
        'orangeCapacity': update.orangeCapacity,
        'mtnCapacity': update.mtnCapacity,
        'moovCapacity': update.moovCapacity,
        'lastCapacityUpdateAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
