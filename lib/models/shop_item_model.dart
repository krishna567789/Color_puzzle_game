import 'dart:ui' show Color;

enum ShopItemType { tubeSkin, theme, powerUp, iap }

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price; // Coins price

  /// Price in gems, which is how the flagship cosmetics are sold: gems only
  /// arrive on a level's first three-star, so this is the economy's sink.
  final int gemPrice;
  final String? iapPrice; // Real money string, from the store and nowhere else

  /// The store product behind a paid row. A card's own id names it to the
  /// player; this is what the till answers to.
  final String iapProductId;

  /// What a paid row unlocks forever, carried through from the catalogue so a
  /// card can show an entitlement as owned without naming a product id.
  final String entitlement;

  /// A theme's backdrop art, carried through for the same reason as the
  /// entitlement: the card previews exactly what the room will wear.
  final String image;

  /// A theme's colours, top down. The preview paints with these, so a listing
  /// cannot advertise one gradient and play another.
  final List<Color> gradient;
  final ShopItemType type;
  final String? assetPath;
  bool isOwned;
  bool isSelected;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    this.price = 0,
    this.gemPrice = 0,
    this.iapPrice,
    this.iapProductId = '',
    this.entitlement = '',
    this.image = '',
    this.gradient = const [],
    required this.type,
    this.assetPath,
    this.isOwned = false,
    this.isSelected = false,
  });

  bool get costsGems => gemPrice > 0;

  int get cost => costsGems ? gemPrice : price;
}
