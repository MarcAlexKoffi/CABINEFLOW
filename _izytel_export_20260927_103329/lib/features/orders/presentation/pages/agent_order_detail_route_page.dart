import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_order_detail_view.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:flutter/material.dart';

/// Route wrapper used by both Agent Orders and Agent History.
/// The detail stays live while preserving the real Navigator back stack.
class AgentOrderDetailRoutePage extends StatelessWidget {
  const AgentOrderDetailRoutePage({
    super.key,
    required this.user,
    required this.initialOrder,
    required this.viewModel,
  });

  final AppUser user;
  final QueueOrder initialOrder;
  final AgentOrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (BuildContext context, Widget? child) {
            final QueueOrder order =
                viewModel.orderById(initialOrder.id) ?? initialOrder;
            return AgentOrderDetailView(
              user: user,
              order: order,
              viewModel: viewModel,
              onBack: () {
                Navigator.of(context).maybePop();
              },
            );
          },
        ),
      ),
    );
  }
}
