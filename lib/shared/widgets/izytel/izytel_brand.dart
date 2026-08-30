import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:flutter/material.dart';

/// Marque IzyTel utilisée par les écrans professionnels.
///
/// La maquette validée utilise le véritable logo fourni dans `assets/images`
/// plutôt qu'une approximation dessinée en code. Le painter reste uniquement
/// un fallback de sécurité si l'asset n'est pas disponible.
class IzyTelBrandMark extends StatelessWidget {
  const IzyTelBrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/images/izyTel_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => CustomPaint(painter: _IzyTelMarkPainter()),
      ),
    );
  }
}

class IzyTelWordmark extends StatelessWidget {
  const IzyTelWordmark({
    super.key,
    this.fontSize = 34,
    this.showTagline = false,
    this.centered = false,
  });

  final double fontSize;
  final bool showTagline;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = Theme.of(context).textTheme.headlineLarge!
        .copyWith(
          color: IzyTelColors.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.15,
          height: 1.05,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text('IzyTel', style: titleStyle),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            'Simple. Rapide. Fiable.',
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.text,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ],
      ],
    );
  }
}

class IzyTelGoogleMark extends StatelessWidget {
  const IzyTelGoogleMark({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/images/google_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const Center(
          child: Text(
            'G',
            style: TextStyle(
              color: IzyTelColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _IzyTelMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect shaderRect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF60A5FA), IzyTelColors.primary, Color(0xFF1D4ED8)],
      ).createShader(shaderRect)
      ..style = PaintingStyle.fill;

    final Path top = Path()
      ..moveTo(w * .24, h * .18)
      ..lineTo(w * .72, h * .18)
      ..lineTo(w * .58, h * .39)
      ..lineTo(w * .38, h * .39)
      ..lineTo(w * .28, h * .55)
      ..lineTo(w * .09, h * .55)
      ..close();

    final Path bottom = Path()
      ..moveTo(w * .42, h * .45)
      ..lineTo(w * .82, h * .45)
      ..lineTo(w * .69, h * .64)
      ..lineTo(w * .52, h * .64)
      ..lineTo(w * .39, h * .84)
      ..lineTo(w * .17, h * .84)
      ..close();

    canvas.drawPath(top, paint);
    canvas.drawPath(bottom, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
