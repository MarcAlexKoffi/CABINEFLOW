enum OrderAuditSource { orderEvent, supportRequest, refund }

extension OrderAuditSourceX on OrderAuditSource {
  String get label {
    switch (this) {
      case OrderAuditSource.orderEvent:
        return 'Commande';
      case OrderAuditSource.supportRequest:
        return 'Demande client';
      case OrderAuditSource.refund:
        return 'Remboursement';
    }
  }
}

class OrderAuditEntry {
  const OrderAuditEntry({
    required this.id,
    required this.orderId,
    required this.occurredAt,
    required this.title,
    required this.source,
    required this.actorRole,
    this.actorId,
    this.actorName,
    this.details = const <String>[],
    this.technicalType,
  });

  final String id;
  final String orderId;
  final DateTime occurredAt;
  final String title;
  final OrderAuditSource source;
  final String actorRole;
  final String? actorId;
  final String? actorName;
  final List<String> details;
  final String? technicalType;

  String get actorDisplayName {
    final String name = actorName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    switch (actorRole) {
      case 'customer':
        return 'Client';
      case 'agent':
        return 'Agent';
      case 'operator':
        return 'Opérateur';
      case 'supervisor':
        return 'Superviseur';
      case 'admin':
        return 'Administrateur';
      case 'system':
        return 'Système';
      default:
        return 'Auteur non enregistré';
    }
  }

  String get actorRoleLabel {
    switch (actorRole) {
      case 'customer':
        return 'Client';
      case 'agent':
        return 'Agent';
      case 'operator':
        return 'Opérateur';
      case 'supervisor':
        return 'Superviseur';
      case 'admin':
        return 'Administrateur';
      case 'system':
        return 'Système';
      default:
        return 'Rôle non enregistré';
    }
  }
}
