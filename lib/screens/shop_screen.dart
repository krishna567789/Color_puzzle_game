import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../models/shop_item_model.dart';
import '../core/audio_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _coins = 0;
  int _gems = 0;
  List<ShopItem> _items = [];
  String _selectedSkinId = 'default_tube';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();
    final ownedIds = await StorageService.getOwnedItems();
    final selectedSkin = await StorageService.getSelectedSkin();

    setState(() {
      _coins = coins;
      _gems = gems;
      _selectedSkinId = selectedSkin;
      _items = [
        ShopItem(
          id: 'default_tube',
          name: 'Classic Bottle',
          description: 'Standard lab bottle.',
          price: 0,
          type: ShopItemType.tubeSkin,
          isOwned: true,
        ),
        ShopItem(
          id: 'neon_tube',
          name: 'Neon Glow',
          description: 'Vibrant neon outlines.',
          price: 1000,
          type: ShopItemType.tubeSkin,
          isOwned: ownedIds.contains('neon_tube'),
        ),
        ShopItem(
          id: 'crystal_bottle',
          name: 'Crystal Vase',
          description: 'Elegant crystal shape.',
          price: 2500,
          type: ShopItemType.tubeSkin,
          isOwned: ownedIds.contains('crystal_bottle'),
        ),
        ShopItem(
          id: 'wooden_tube',
          name: 'Nature Tube',
          description: 'Rustic wooden texture.',
          price: 1500,
          type: ShopItemType.tubeSkin,
          isOwned: ownedIds.contains('wooden_tube'),
        ),
      ];
    });
  }

  Future<void> _buyItem(ShopItem item) async {
    if (_coins >= item.price) {
      _coins -= item.price;
      item.isOwned = true;

      List<String> owned = _items
          .where((i) => i.isOwned)
          .map((i) => i.id)
          .toList();
      await StorageService.saveCoins(_coins);
      await StorageService.saveOwnedItems(owned);
      AudioService.playWinSfx();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased ${item.name}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      AudioService.playClickSfx();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins!'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _selectSkin(ShopItem item) async {
    if (!item.isOwned) return;
    _selectedSkinId = item.id;
    await StorageService.setSelectedSkin(item.id);
    AudioService.playClickSfx();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SHOP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          _buildCurrencyDisplay(
            Icons.monetization_on,
            AppColors.goldCoin,
            _coins.toString(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Category Tabs
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCategoryTab('BOTTLES', true),
                const SizedBox(width: 20),
                _buildCategoryTab('THEMES', false),
              ],
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = _selectedSkinId == item.id;
                return _buildShopItemCard(item, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryButton : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white60,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildShopItemCard(ShopItem item, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (item.isOwned) {
          _selectSkin(item);
        } else {
          _buyItem(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primaryButton : AppColors.cardBorder,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryButton.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            const Spacer(),
            // Mock icon for bottle skins
            Icon(
              Icons.science,
              size: 60,
              color: isSelected ? AppColors.primaryButton : Colors.white38,
            ),
            const Spacer(),
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (!item.isOwned)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: AppColors.goldCoin,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.price.toString(),
                    style: const TextStyle(
                      color: AppColors.goldCoin,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Text(
                isSelected ? 'SELECTED' : 'OWNED',
                style: TextStyle(
                  color: isSelected ? AppColors.primaryButton : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyDisplay(IconData icon, Color color, String amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

Widget _buildCurrencyDisplay(IconData icon, Color color, String amount) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
