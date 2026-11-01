import 'package:flutter/material.dart';

import '../l10n/i18n.dart';
import '../utils/constants.dart';

/// Logo de StockPyme. [withBackground] usa el ícono completo con fondo.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.withBackground = true});

  final double size;
  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      withBackground ? AppConstants.logoPath : AppConstants.logoForegroundPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Logo de Rivera Systems (escudo).
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.companyLogoPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Firma "Hecho por Rivera Systems" con el logo de la empresa.
/// Usa [onBrand] cuando va sobre el fondo verde de la marca.
class MadeByRivera extends StatelessWidget {
  const MadeByRivera({super.key, this.onBrand = false, this.color});

  final bool onBrand;

  /// Color del texto (por compatibilidad con versiones anteriores).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = color ??
        (onBrand ? const Color(0xFFCCEDE7) : scheme.onSurfaceVariant);
    final strong = onBrand || color != null ? Colors.white : scheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CompanyLogo(size: 30),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Hecho por'),
              style: TextStyle(fontSize: 11, color: muted, letterSpacing: 0.3),
            ),
            Text(
              AppConstants.company,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: strong,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
