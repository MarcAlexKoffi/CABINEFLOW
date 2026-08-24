import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/orders/data/mappers/firestore_order_mapper.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDashboardRepository implements DashboardRepository {
  FirestoreDashboardRepository({
    FirebaseFirestore? firestore,
    this.maximumLoadedOrders = 500,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final int maximumLoadedOrders;

  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _firestore.collection('orders');

  @override
  Future<DashboardData> fetchDashboardData() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _ordersCollection
        .orderBy('createdAt', descending: true)
        .limit(maximumLoadedOrders)
        .get();

    final List<QueueOrder> orders = snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              FirestoreOrderMapper.fromMap(
                id: document.id,
                data: document.data(),
              ),
        )
        .toList(growable: false);

    return _buildDashboardData(orders, now: DateTime.now());
  }

  DashboardData _buildDashboardData(
    List<QueueOrder> orders, {
    required DateTime now,
  }) {
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime tomorrowStart = todayStart.add(const Duration(days: 1));
    final DateTime yesterdayStart = todayStart.subtract(
      const Duration(days: 1),
    );

    final int todayRevenue = _confirmedRevenueBetween(
      orders,
      start: todayStart,
      end: tomorrowStart,
    );
    final int yesterdayRevenue = _confirmedRevenueBetween(
      orders,
      start: yesterdayStart,
      end: todayStart,
    );

    final int readyCount = orders
        .where((QueueOrder order) => order.status == QueueOrderStatus.paidReady)
        .length;
    final int paymentsToVerify = orders
        .where(
          (QueueOrder order) =>
              order.status == QueueOrderStatus.paymentToVerify ||
              order.hasPaymentToReviewAfterExpiration,
        )
        .length;
    final int inProgressCount = orders
        .where(
          (QueueOrder order) =>
              order.status == QueueOrderStatus.inProgress ||
              order.status == QueueOrderStatus.onHold ||
              order.status == QueueOrderStatus.awaitingCustomerConfirmation,
        )
        .length;
    final int completedToday = orders
        .where(
          (QueueOrder order) =>
              order.status == QueueOrderStatus.completed &&
              _isBetween(
                order.customerConfirmationCompletedAt ?? order.completedAt,
                todayStart,
                tomorrowStart,
              ),
        )
        .length;

    final List<QueueOrder> waitingOrders = orders
        .where((QueueOrder order) => order.status == QueueOrderStatus.paidReady)
        .toList(growable: false);

    final int averageWaitingMinutes = waitingOrders.isEmpty
        ? 0
        : waitingOrders
                  .map((QueueOrder order) {
                    final DateTime start =
                        order.paymentConfirmedAt ??
                        order.paidAt ??
                        order.createdAt;
                    return now
                        .difference(start)
                        .inMinutes
                        .clamp(0, 999999)
                        .toInt();
                  })
                  .reduce((int first, int second) => first + second) ~/
              waitingOrders.length;

    return DashboardData(
      ordersToProcess: readyCount + paymentsToVerify,
      averageWaitingMinutes: averageWaitingMinutes,
      todayRevenue: todayRevenue,
      revenueChangePercentage: _calculateRevenueChange(
        todayRevenue: todayRevenue,
        yesterdayRevenue: yesterdayRevenue,
      ),
      statistics: DashboardStatistics(
        newRequests: readyCount,
        paymentsToVerify: paymentsToVerify,
        inProgress: inProgressCount,
        completed: completedToday,
      ),
      balances: const <AccountBalance>[
        AccountBalance(channel: ServiceChannel.orange),
        AccountBalance(channel: ServiceChannel.mtn),
        AccountBalance(channel: ServiceChannel.moov),
        AccountBalance(channel: ServiceChannel.wave),
      ],
      priorityOrders: _buildPriorityOrders(orders, now: now),
    );
  }

  int _confirmedRevenueBetween(
    List<QueueOrder> orders, {
    required DateTime start,
    required DateTime end,
  }) {
    return orders.fold<int>(0, (int total, QueueOrder order) {
      if (order.paymentStatus != OrderPaymentStatus.confirmed) {
        return total;
      }

      final DateTime? confirmedAt = order.paymentConfirmedAt ?? order.paidAt;
      if (!_isBetween(confirmedAt, start, end)) {
        return total;
      }

      return total + order.amount;
    });
  }

  double? _calculateRevenueChange({
    required int todayRevenue,
    required int yesterdayRevenue,
  }) {
    if (yesterdayRevenue == 0) {
      return todayRevenue == 0 ? 0 : null;
    }

    return ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
  }

  List<PriorityOrder> _buildPriorityOrders(
    List<QueueOrder> orders, {
    required DateTime now,
  }) {
    final List<QueueOrder> activeOrders = orders.where((QueueOrder order) {
      return order.status == QueueOrderStatus.paymentToVerify ||
          order.status == QueueOrderStatus.paidReady ||
          order.status == QueueOrderStatus.inProgress ||
          order.hasPaymentToReviewAfterExpiration;
    }).toList();

    activeOrders.sort((QueueOrder first, QueueOrder second) {
      final int statusComparison = _priorityRank(
        first,
      ).compareTo(_priorityRank(second));
      if (statusComparison != 0) {
        return statusComparison;
      }

      return _priorityDate(first).compareTo(_priorityDate(second));
    });

    return activeOrders
        .take(5)
        .map((QueueOrder order) {
          return PriorityOrder(
            orderId: order.id,
            reference: order.reference,
            phoneNumber: order.beneficiaryPhone,
            operationLabel: _operationLabel(order),
            amount: order.amount,
            channel: _serviceChannel(order.network),
            status: _priorityStatus(order, now: now),
            actionLabel: _actionLabel(order),
          );
        })
        .toList(growable: false);
  }

  int _priorityRank(QueueOrder order) {
    if (order.hasPaymentToReviewAfterExpiration) {
      return 0;
    }

    switch (order.status) {
      case QueueOrderStatus.paymentToVerify:
        return 1;
      case QueueOrderStatus.paidReady:
        return 2;
      case QueueOrderStatus.inProgress:
        return 3;
      default:
        return 4;
    }
  }

  DateTime _priorityDate(QueueOrder order) {
    return order.paymentDeclaredAt ??
        order.paymentConfirmedAt ??
        order.paidAt ??
        order.takenAt ??
        order.createdAt;
  }

  PriorityOrderStatus _priorityStatus(
    QueueOrder order, {
    required DateTime now,
  }) {
    if (order.status == QueueOrderStatus.inProgress) {
      return PriorityOrderStatus.inProgress;
    }

    if (order.status == QueueOrderStatus.paymentToVerify ||
        order.hasPaymentToReviewAfterExpiration) {
      return PriorityOrderStatus.pendingVerification;
    }

    final DateTime waitingSince =
        order.paymentConfirmedAt ?? order.paidAt ?? order.createdAt;
    final int waitingMinutes = now.difference(waitingSince).inMinutes;

    return waitingMinutes >= 15
        ? PriorityOrderStatus.urgent
        : PriorityOrderStatus.ready;
  }

  String _actionLabel(QueueOrder order) {
    if (order.status == QueueOrderStatus.paymentToVerify ||
        order.hasPaymentToReviewAfterExpiration) {
      return 'Vérifier';
    }

    if (order.status == QueueOrderStatus.inProgress) {
      return 'Ouvrir';
    }

    return 'Traiter';
  }

  String _operationLabel(QueueOrder order) {
    final String offerLabel = order.offerLabel.trim();
    if (offerLabel.isNotEmpty) {
      return offerLabel;
    }

    switch (order.operationType) {
      case OrderOperationType.internetSubscription:
        return 'Souscription Internet';
      case OrderOperationType.unitTransfer:
        return 'Transfert d’unités';
      case OrderOperationType.callBundle:
        return 'Forfait d’appels';
      case OrderOperationType.mixedBundle:
        return 'Forfait mixte';
      case OrderOperationType.other:
        return 'Commande';
    }
  }

  ServiceChannel _serviceChannel(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return ServiceChannel.orange;
      case MobileNetwork.mtn:
        return ServiceChannel.mtn;
      case MobileNetwork.moov:
        return ServiceChannel.moov;
    }
  }

  bool _isBetween(DateTime? date, DateTime start, DateTime end) {
    if (date == null) {
      return false;
    }

    final DateTime localDate = date.toLocal();
    return !localDate.isBefore(start) && localDate.isBefore(end);
  }
}
