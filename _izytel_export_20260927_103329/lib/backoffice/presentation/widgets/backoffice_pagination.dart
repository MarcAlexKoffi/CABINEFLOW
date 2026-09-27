import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficePaginationBar extends StatelessWidget {
  const BackofficePaginationBar({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
    this.loading = false,
  });

  final int page;
  final int pageSize;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;
  final bool loading;

  int get _first => total == 0 ? 0 : ((page - 1) * pageSize) + 1;
  int get _last => total == 0 ? 0 : (((page - 1) * pageSize) + pageSize).clamp(0, total).toInt();
  int get _pageCount => total == 0 ? 1 : ((total + pageSize - 1) ~/ pageSize);

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 720;
    final Widget resultLabel = Text(
      total == 0 ? '0 résultat' : '$_first–$_last sur $total',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: BackofficePalette.muted,
            fontWeight: FontWeight.w700,
          ),
    );
    final Widget sizeControl = DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: pageSize,
        borderRadius: BorderRadius.circular(12),
        items: const <DropdownMenuItem<int>>[
          DropdownMenuItem<int>(value: 25, child: Text('25 / page')),
          DropdownMenuItem<int>(value: 50, child: Text('50 / page')),
          DropdownMenuItem<int>(value: 100, child: Text('100 / page')),
        ],
        onChanged: loading
            ? null
            : (int? value) {
                if (value != null && value != pageSize) onPageSizeChanged(value);
              },
      ),
    );
    final Widget nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: loading ? null : onPrevious,
          icon: const Icon(Symbols.chevron_left_rounded, size: 18),
          label: const Text('Précédent'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Page $page / $_pageCount',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        FilledButton.icon(
          onPressed: loading ? null : onNext,
          icon: const Icon(Symbols.chevron_right_rounded, size: 18),
          label: const Text('Suivant'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: resultLabel),
                    sizeControl,
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: nav),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: resultLabel),
                sizeControl,
                const SizedBox(width: 18),
                nav,
              ],
            ),
    );
  }
}
