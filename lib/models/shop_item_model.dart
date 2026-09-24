enum ShopItemType { tubeSkin, theme, powerUp, iap }

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price; // Coins price

  /// Price in gems, which is how the flagship cosmetics are sold: gems only
  /// arrive on a level's first three-star, so this is the economy's sink.
  final int gemPrice;
  final String? iapPrice; // Real money string
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
    required this.type,
    this.assetPath,
    this.isOwned = false,
    this.isSelected = false,
  });

  bool get costsGems => gemPrice > 0;

  int get cost => costsGems ? gemPrice : price;
}
