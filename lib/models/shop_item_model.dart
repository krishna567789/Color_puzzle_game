enum ShopItemType { tubeSkin, theme, powerUp, iap }

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price; // Coins price
  final String? iapPrice; // Real money string
  final ShopItemType type;
  final String? assetPath;
  bool isOwned;
  bool isSelected;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.iapPrice,
    required this.type,
    this.assetPath,
    this.isOwned = false,
    this.isSelected = false,
  });
}
