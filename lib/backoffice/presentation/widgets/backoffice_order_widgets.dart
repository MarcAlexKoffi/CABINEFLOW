import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficePageIntro extends StatelessWidget {
  const BackofficePageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 780;
        final Widget copy = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BackofficePalette.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCE7FF)),
              ),
              child: Icon(
                icon,
                size: 25,
                color: BackofficePalette.primaryStrong,
                fill: 1,
                weight: 650,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    eyebrow.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BackofficePalette.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (trailing == null) return copy;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              copy,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: copy),
            const SizedBox(width: 20),
            trailing!,
          ],
        );
      },
    );
  }
}

class BackofficeMetricCard extends StatelessWidget {
  const BackofficeMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.emphasis = BackofficePalette.primary,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: emphasis.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: emphasis,
                  fill: 1,
                  weight: 620,
                ),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: emphasis,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: emphasis,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class BackofficeStatusBadge extends StatelessWidget {
  const BackofficeStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color, weight: 600),
            const SizedBox(width: 5),
          ] else ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackofficeNetworkBadge extends StatelessWidget {
  const BackofficeNetworkBadge({super.key, required this.network});

  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    final Color color = networkColor(network);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        networkLabel(network),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}


class BackofficeTableColumnSpec {
  const BackofficeTableColumnSpec({
    required this.label,
    required this.flex,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final int flex;
  final Alignment alignment;
}

class BackofficeTableCellSpec {
  const BackofficeTableCellSpec({
    required this.child,
    required this.flex,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final int flex;
  final Alignment alignment;
}

class BackofficeDesktopTable extends StatelessWidget {
  const BackofficeDesktopTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  final List<BackofficeTableColumnSpec> columns;
  final List<BackofficeDesktopTableRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: backofficePanelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: BackofficePalette.surfaceAlt,
            child: Row(
              children: columns.map((BackofficeTableColumnSpec column) {
                return Expanded(
                  flex: column.flex,
                  child: Align(
                    alignment: column.alignment,
                    child: Text(
                      column.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BackofficePalette.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          for (int index = 0; index < rows.length; index++)
            rows[index].copyWith(showDivider: index < rows.length - 1),
        ],
      ),
    );
  }
}

class BackofficeDesktopTableRow extends StatelessWidget {
  const BackofficeDesktopTableRow({
    super.key,
    required this.cells,
    this.onTap,
    this.backgroundColor,
    this.accentColor,
    this.showDivider = true,
  });

  final List<BackofficeTableCellSpec> cells;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? accentColor;
  final bool showDivider;

  BackofficeDesktopTableRow copyWith({bool? showDivider}) {
    return BackofficeDesktopTableRow(
      cells: cells,
      onTap: onTap,
      backgroundColor: backgroundColor,
      accentColor: accentColor,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget row = Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        border: showDivider
            ? const Border(bottom: BorderSide(color: BackofficePalette.line))
            : null,
      ),
      child: Row(
        children: cells.map((BackofficeTableCellSpec cell) {
          return Expanded(
            flex: cell.flex,
            child: Align(
              alignment: cell.alignment,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: cell.child,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );

    return Stack(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, child: row),
        ),
        if (accentColor != null)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: accentColor),
          ),
      ],
    );
  }
}

class BackofficeEmptyState extends StatelessWidget {
  const BackofficeEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: backofficePanelDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BackofficePalette.primarySoft,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              icon,
              color: BackofficePalette.primary,
              size: 28,
              fill: 1,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class BackofficeInlineError extends StatelessWidget {
  const BackofficeInlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BackofficePalette.danger.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: BackofficePalette.danger.withValues(alpha: .18),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Symbols.error_rounded,
            color: BackofficePalette.danger,
            fill: 1,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BackofficePalette.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

Future<void> showBackofficeOrderDetails(
  BuildContext context,
  QueueOrder order,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            decoration: backofficePanelDecoration(radius: 22, elevated: true),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BackofficePalette.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Symbols.receipt_long_rounded,
                          color: BackofficePalette.primaryStrong,
                          fill: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              order.reference,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.clientName} • ${formatOrderDateTime(order.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Symbols.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      BackofficeStatusBadge(
                        label: orderStatusLabel(order.status),
                        color: orderStatusColor(order.status),
                        icon: orderStatusIcon(order.status),
                      ),
                      BackofficeNetworkBadge(network: order.network),
                      BackofficeStatusBadge(
                        label: paymentStatusLabel(order.paymentStatus),
                        color: order.paymentStatus == OrderPaymentStatus.confirmed
                            ? BackofficePalette.success
                            : BackofficePalette.warning,
                        icon: Symbols.account_balance_wallet_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailSection(
                    title: 'Commande',
                    rows: <_DetailRow>[
                      _DetailRow('Montant', formatCfaFull(order.amount)),
                      _DetailRow('Service', operationTypeLabel(order.operationType)),
                      _DetailRow('Offre', order.offerLabel),
                      _DetailRow('Bénéficiaire', formatIvorianPhone(order.beneficiaryPhone)),
                      _DetailRow('Source', orderSourceLabel(order.source)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailSection(
                    title: 'Client & paiement',
                    rows: <_DetailRow>[
                      _DetailRow('Client', order.clientName),
                      _DetailRow('WhatsApp', formatIvorianPhone(order.clientWhatsappPhone)),
                      _DetailRow('Référence paiement', order.paymentReference?.trim().isNotEmpty == true ? order.paymentReference! : 'Non renseignée'),
                      _DetailRow('Déclaré le', order.paymentDeclaredAt == null ? 'Non déclaré' : formatOrderDateTime(order.paymentDeclaredAt!)),
                      _DetailRow('Confirmé le', order.paymentConfirmedAt == null ? 'Non confirmé' : formatOrderDateTime(order.paymentConfirmedAt!)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailSection(
                    title: 'Affectation',
                    rows: <_DetailRow>[
                      _DetailRow('Agent', order.assignedAgentName?.trim().isNotEmpty == true ? order.assignedAgentName! : 'Non affecté'),
                      _DetailRow('Statut', order.assignmentStatus.name),
                      _DetailRow('Mode', order.assignmentMode?.name ?? 'Non renseigné'),
                      _DetailRow('Affectée le', order.assignedAt == null ? 'Non renseigné' : formatOrderDateTime(order.assignedAt!)),
                    ],
                  ),
                  if (order.failureReason != null ||
                      order.observation?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 14),
                    _DetailSection(
                      title: 'Échec / observation',
                      rows: <_DetailRow>[
                        _DetailRow('Motif', failureReasonLabel(order.failureReason)),
                        _DetailRow('Observation', order.observation?.trim().isNotEmpty == true ? order.observation! : 'Aucune'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BackofficePalette.surfaceAlt,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BackofficePalette.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          for (final _DetailRow row in rows) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 148,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BackofficePalette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}
