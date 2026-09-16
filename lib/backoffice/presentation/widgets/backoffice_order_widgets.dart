import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white,
            Color(0xFFF7FAFF),
            Color(0xFFF1F7FF),
          ],
          stops: <double>[0, .58, 1],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE7F7)),
        boxShadow: BackofficeShadows.panel,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -64,
            top: -72,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BackofficePalette.primary.withValues(alpha: .055),
              ),
            ),
          ),
          Positioned(
            right: 95,
            bottom: -76,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BackofficePalette.cyan.withValues(alpha: .045),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 800;
                final Widget copy = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: BackofficeGradients.brand,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: BackofficeShadows.glow,
                      ),
                      child: Icon(
                        icon,
                        size: 26,
                        color: Colors.white,
                        fill: 1,
                        weight: 650,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: BackofficePalette.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: BackofficePalette.primary.withValues(
                                  alpha: .14,
                                ),
                              ),
                            ),
                            child: Text(
                              eyebrow.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: BackofficePalette.primaryStrong,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .75,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontSize: compact ? 24 : 28,
                                  letterSpacing: -.6,
                                ),
                          ),
                          const SizedBox(height: 7),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Text(
                              description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    height: 1.55,
                                    color: BackofficePalette.muted,
                                  ),
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
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerLeft, child: trailing!),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: copy),
                    const SizedBox(width: 24),
                    trailing!,
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
      constraints: const BoxConstraints(minWidth: 160, minHeight: 142),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white,
            emphasis.withValues(alpha: .035),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emphasis.withValues(alpha: .13)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A102A56),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: emphasis.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: emphasis,
                  fill: 1,
                  weight: 640,
                ),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: emphasis.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: emphasis,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
              color: BackofficePalette.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BackofficePalette.muted,
            ),
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
  const BackofficeNetworkBadge({
    super.key,
    required this.network,
    this.compact = false,
  });

  final MobileNetwork network;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = network.brandColor;
    final double logoSize = compact ? 20 : 24;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 7,
        compact ? 4 : 5,
        compact ? 8 : 10,
        compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .22)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08102A56),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              network.brandLogoAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Logo ${network.brandLabel}',
              errorBuilder: (_, _, _) => Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  network.brandLabel.substring(0, 1),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 5 : 7),
          Text(
            network.brandLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BackofficePalette.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class BackofficeWaveBadge extends StatelessWidget {
  const BackofficeWaveBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const Color waveBlue = Color(0xFF1BB6EA);
    final double logoSize = compact ? 20 : 25;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 7 : 8,
        compact ? 5 : 6,
        compact ? 9 : 11,
        compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: waveBlue.withValues(alpha: .22)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08102A56),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              'assets/images/wave_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Logo Wave',
              errorBuilder: (_, _, _) => const Icon(
                Symbols.waves_rounded,
                size: 20,
                color: waveBlue,
              ),
            ),
          ),
          SizedBox(width: compact ? 5 : 7),
          Text(
            'Wave',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BackofficePalette.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class BackofficeToolbarPanel extends StatelessWidget {
  const BackofficeToolbarPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: BackofficePalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BackofficePalette.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08102A56),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[Color(0xFFF6F9FF), Color(0xFFFAFCFF)],
              ),
              border: Border(
                bottom: BorderSide(color: BackofficePalette.line),
              ),
            ),
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
            rows[index].copyWith(
              showDivider: index < rows.length - 1,
              backgroundColor: rows[index].backgroundColor ??
                  (index.isEven ? Colors.white : const Color(0xFFFBFCFF)),
            ),
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

  BackofficeDesktopTableRow copyWith({
    bool? showDivider,
    Color? backgroundColor,
  }) {
    return BackofficeDesktopTableRow(
      cells: cells,
      onTap: onTap,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      accentColor: accentColor,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget row = Material(
      color: backgroundColor ?? Colors.white,
      child: InkWell(
        onTap: onTap,
        hoverColor: BackofficePalette.primarySoft.withValues(alpha: .55),
        splashColor: BackofficePalette.primarySoft,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: BackofficePalette.line),
                  )
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
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        row,
        if (accentColor != null)
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
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
