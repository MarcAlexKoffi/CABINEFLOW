import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

String formatIvorianPhone(String value) {
  final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  final String localDigits = digits.startsWith('225')
      ? digits.substring(3)
      : digits;
  if (localDigits.length != 10) return value;
  return '+225 ${<String>[localDigits.substring(0, 2), localDigits.substring(2, 4), localDigits.substring(4, 6), localDigits.substring(6, 8), localDigits.substring(8, 10)].join(' ')}';
}

String financeRelativeTime(DateTime value, {DateTime? now}) {
  final Duration difference = (now ?? DateTime.now()).difference(value);
  if (difference.isNegative || difference.inMinutes <= 0) return 'À l’instant';
  if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
  if (difference.inHours < 24) {
    final int minutes = difference.inMinutes.remainder(60);
    return minutes == 0
        ? 'Il y a ${difference.inHours} h'
        : 'Il y a ${difference.inHours} h $minutes min';
  }
  if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String financeDateTime(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} · $hour:$minute';
}

class FinancialMetricCard extends StatelessWidget {
  const FinancialMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        border: Border.all(color: IzyTelColors.outline),
        boxShadow: const [
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: IzyTelIconSize.info, color: accent),
              ),
              const SizedBox(width: IzyTelSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: IzyTelSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: IzyTelColors.textPrimary,
                fontSize: IzyTelTypeScale.title3,
                fontWeight: FontWeight.w800,
                letterSpacing: -.25,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IzyTelColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FinanceActionTile extends StatelessWidget {
  const FinanceActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = IzyTelColors.primary,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(IzyTelRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: IzyTelSpacing.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(IzyTelRadii.card),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: IzyTelIconSize.action),
              ),
              const SizedBox(width: IzyTelSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: IzyTelColors.textPrimary,
                                  fontSize: IzyTelTypeScale.text,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 7),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 104),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.micro,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 22,
                color: IzyTelColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceFilterPill extends StatelessWidget {
  const FinanceFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.accent = IzyTelColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : IzyTelColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? accent : IzyTelColors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? IzyTelColors.surface
                        : IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? IzyTelColors.surface.withAlpha(38)
                          : accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? IzyTelColors.surface : accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IzyTelColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: IzyTelColors.primary, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.cardTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.label,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
