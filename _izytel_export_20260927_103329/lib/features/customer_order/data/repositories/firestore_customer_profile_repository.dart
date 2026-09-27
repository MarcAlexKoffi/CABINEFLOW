import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_profile.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreCustomerProfileRepository implements CustomerProfileRepository {
  FirestoreCustomerProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _profilesCollection {
    return _firestore.collection('customerProfiles');
  }

  @override
  Stream<CustomerProfile?> watchCurrentProfile() async* {
    final User customer = await _waitForAuthenticatedCustomer();

    yield* _profilesCollection.doc(customer.uid).snapshots().map((snapshot) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      if (data['customerAuthUid'] != customer.uid) {
        throw StateError('Le profil client ne correspond pas à cette session.');
      }

      return _profileFromData(data);
    });
  }

  @override
  Future<void> saveDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiaryPhone,
  }) async {
    final User customer = await _waitForAuthenticatedCustomer();
    final DocumentReference<Map<String, dynamic>> document = _profilesCollection
        .doc(customer.uid);

    await _firestore.runTransaction<void>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(document);

      final Map<String, dynamic> data = <String, dynamic>{
        'schemaVersion': 1,
        'customerAuthUid': customer.uid,
        'name': identity.name.trim(),
        'whatsappPhone': identity.whatsappNumber.normalized,
        'defaultBeneficiaryPhone': beneficiaryPhone.normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (snapshot.exists) {
        transaction.update(document, data);
      } else {
        transaction.set(document, <String, dynamic>{
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<User> _waitForAuthenticatedCustomer() async {
    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser != null) {
      return currentUser;
    }

    // La création/restauration de la session anonyme reste volontairement la
    // responsabilité du repository de commandes. Ce repository attend cette
    // même session afin d'éviter deux signInAnonymously concurrents au démarrage.
    final User? authenticatedUser = await _firebaseAuth
        .authStateChanges()
        .firstWhere((User? user) => user != null);

    return authenticatedUser!;
  }

  CustomerProfile _profileFromData(Map<String, dynamic> data) {
    final Object? rawName = data['name'];
    final Object? rawWhatsappPhone = data['whatsappPhone'];
    final Object? rawDefaultBeneficiary = data['defaultBeneficiaryPhone'];

    if (rawName is! String || rawName.trim().length < 2) {
      throw StateError('Le profil client contient un nom invalide.');
    }

    if (rawWhatsappPhone is! String || rawDefaultBeneficiary is! String) {
      throw StateError('Le profil client contient un numéro invalide.');
    }

    return CustomerProfile(
      name: rawName.trim(),
      whatsappPhone: WhatsappPhoneNumber.parse(rawWhatsappPhone),
      defaultBeneficiaryPhone: BeneficiaryPhoneNumber.parse(
        rawDefaultBeneficiary,
      ),
    );
  }
}
