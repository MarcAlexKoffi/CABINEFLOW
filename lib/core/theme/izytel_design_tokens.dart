/// Tokens officiels du design system IzyTel V1.
///
/// Ils reprennent la maquette validée : grille d'espacement 8/12/16/20/24/32,
/// typographie Manrope et iconographie Material Symbols Rounded.
class IzyTelSpacing {
  const IzyTelSpacing._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class IzyTelTypeScale {
  const IzyTelTypeScale._();

  static const double title1 = 28;
  static const double title2 = 22;
  static const double title3 = 18;
  static const double cardTitle = 16;
  static const double text = 15;
  static const double label = 13;
  static const double micro = 12;

  // Informations transactionnelles : elles restent dans la grille typographique
  // mais reçoivent un poids plus fort dans les composants métier.
  static const double transactionNumber = text;
  static const double money = title3;
}

class IzyTelIconSize {
  const IzyTelIconSize._();

  static const double info = 18;
  static const double action = 22;
  static const double navigation = 24;
  static const double state = 32;
}

class IzyTelRadii {
  const IzyTelRadii._();

  static const double input = 8;
  static const double button = 8;
  static const double card = 14;
  static const double largeCard = 20;
  static const double sheet = 28;
}
