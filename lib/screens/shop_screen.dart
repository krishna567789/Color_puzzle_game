import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/ad_manager.dart';
import '../core/analytics_service.dart';
import '../core/app_colors.dart';
import '../core/progress_service.dart';
import '../core/storage_service.dart';
import '../models/shop_item_model.dart';
import '../core/audio_service.dart';
import '../widgets/custom_bottle.dart';
import '../core/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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
  String _selectedThemeId = 'default_theme';
  int _activeTabIndex = 0;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restorePurchases() async {
    AnalyticsService.logEvent('iap_restore_tapped');
    await IapService.restorePurchases();
    await _loadData();
    _showSnack('Purchases restored.');
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.logShopOpened();
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();
    final ownedIds = await StorageService.getOwnedItems();
    final selectedSkin = await StorageService.getSelectedSkin();
    final selectedTheme = await StorageService.getSelectedTheme();

    setState(() {
      _coins = coins;
      _gems = gems;
      _selectedSkinId = selectedSkin;
      _selectedThemeId = selectedTheme;
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
          gemPrice: 40,
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
        ShopItem(
          id: 'default_theme',
          name: 'Wizard Room',
          description: 'Magical dark theme.',
          price: 0,
          type: ShopItemType.theme,
          isOwned: true,
        ),
        ShopItem(
          id: 'forest_theme',
          name: 'Enchanted Forest',
          description: 'Lush green magical woods.',
          price: 2000,
          type: ShopItemType.theme,
          isOwned: ownedIds.contains('forest_theme'),
        ),
        ShopItem(
          id: 'space_theme',
          name: 'Cosmic Void',
          description: 'Deep space puzzles.',
          gemPrice: 60,
          type: ShopItemType.theme,
          isOwned: ownedIds.contains('space_theme'),
        ),
      ];

      _loadIapItems();
    });
  }

  Future<void> _loadIapItems() async {
    bool hasRemovedAds = await StorageService.getHasRemovedAds();
    List<ShopItem> iapItems = [];

    if (IapService.isAvailable && IapService.products.isNotEmpty) {
      for (var product in IapService.products) {
        iapItems.add(
          ShopItem(
            id: product.id,
            name: product.title
                .split(' (')
                .first, // Clean up "(App Name)" suffix
            description: product.description,
            price: 0,
            iapPrice: product.price,
            type: ShopItemType.iap,
            isOwned: (product.id == IapService.removeAdsId)
                ? hasRemovedAds
                : false,
          ),
        );
      }
    } else {
      // Fallback for debug/emulators
      iapItems.addAll([
        ShopItem(
          id: IapService.removeAdsId,
          name: 'Remove Ads',
          description: 'No more interruptions!',
          price: 0,
          iapPrice: '\$2.99',
          type: ShopItemType.iap,
          isOwned: hasRemovedAds,
        ),
        ShopItem(
          id: IapService.buyCoins1000Id,
          name: '1000 Coins',
          description: 'A large purse of coins.',
          price: 0,
          iapPrice: '\$4.99',
          type: ShopItemType.iap,
        ),
        ShopItem(
          id: IapService.buyCoins500Id,
          name: '500 Coins',
          description: 'A small pouch of coins.',
          price: 0,
          iapPrice: '\$1.99',
          type: ShopItemType.iap,
        ),
      ]);
    }

    if (mounted) {
      setState(() {
        _items.addAll(iapItems);
      });
    }
  }

  Future<void> _buyItem(ShopItem item) async {
    if (item.type == ShopItemType.iap) {
      if (item.isOwned) return;
      ProductDetails? product;
      for (final p in IapService.products) {
        if (p.id == item.id) product = p;
      }
      if (IapService.isAvailable && product != null) {
        await IapService.buyProduct(product);
      } else if (kDebugMode) {
        // Local sandbox only: lets the economy be tested without a Play
        // Console listing. Never reachable in a release build.
        if (item.id == IapService.removeAdsId) {
          await StorageService.setHasRemovedAds(true);
          AdManager.updateHasRemovedAds(true);
        } else if (item.id == IapService.buyCoins1000Id) {
          await ProgressService.grant(coins: 1000);
        } else if (item.id == IapService.buyCoins500Id) {
          await ProgressService.grant(coins: 500);
        }
        await _loadData();
      } else {
        AudioService.playErrorSfx();
        _showSnack(
          'Store is currently unavailable. Please check your connection '
          'and try again.',
        );
      }
      return;
    }

    // Gems are the premium local currency: the flagship cosmetics can only be
    // bought with them, which is what keeps a gem scarce after a while.
    final paid = item.costsGems
        ? await ProgressService.spend(gems: item.gemPrice)
        : await ProgressService.spend(coins: item.price);
    if (!paid) {
      AudioService.playClickSfx();
      _showSnack('Not enough ${item.costsGems ? 'gems' : 'coins'}!');
      return;
    }

    item.isOwned = true;
    await StorageService.saveOwnedItems([
      for (final owned in _items)
        if (owned.isOwned && owned.type != ShopItemType.iap) owned.id,
    ]);
    await _loadData();
    AudioService.playWinSfx();
    _showSnack('Purchased ${item.name}!');
  }

  Future<void> _selectItem(ShopItem item) async {
    if (!item.isOwned) return;
    if (item.type == ShopItemType.tubeSkin) {
      _selectedSkinId = item.id;
      await StorageService.setSelectedSkin(item.id);
    } else if (item.type == ShopItemType.theme) {
      _selectedThemeId = item.id;
      await StorageService.setSelectedTheme(item.id);
    }
    AudioService.playClickSfx();
    setState(() {});
  }

  /// The catalogue cut down to the tab on screen.
  List<ShopItem> get _visibleItems {
    final type = switch (_activeTabIndex) {
      1 => ShopItemType.theme,
      2 => ShopItemType.iap,
      _ => ShopItemType.tubeSkin,
    };
    return [for (final item in _items) if (item.type == type) item];
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
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
            letterSpacing: 4,
            shadows: [Shadow(color: AppColors.primaryButton, blurRadius: 20)],
          ),
        ),
        centerTitle: true,
        actions: [
          _buildCurrencyDisplay(
            Icons.monetization_on,
            AppColors.goldCoin,
            _coins.toString(),
          ),
          const SizedBox(width: 8),
          _buildCurrencyDisplay(
            Icons.diamond,
            Colors.cyanAccent,
            _gems.toString(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Magical Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.7)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Category Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 14,
                  ),
                  child: Row(
                    children: [
                      for (final tab in const ['BOTTLES', 'THEMES', 'PREMIUM']
                          .asMap()
                          .entries) ...[
                        if (tab.key > 0) const SizedBox(width: 10),
                        Expanded(child: _buildCategoryTab(tab.value, tab.key)),
                      ],
                    ],
                  ),
                ),

                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final isSelected = item.type == ShopItemType.tubeSkin
                          ? _selectedSkinId == item.id
                          : _selectedThemeId == item.id;
                      return _buildShopItemCard(item, isSelected);
                    },
                  ),
                ),

                if (_activeTabIndex == 2)
                  TextButton.icon(
                    onPressed: _restorePurchases,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text(
                      'RESTORE PURCHASES',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, int index) {
    final active = _activeTabIndex == index;
    return GestureDetector(
      onTap: () {
        AudioService.playClickSfx();
        setState(() => _activeTabIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Colors.cyan, AppColors.primaryButton],
                )
              : const LinearGradient(colors: [Colors.white10, Colors.black26]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.white54 : Colors.white12,
            width: 1.5,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: AppColors.primaryButton.withValues(alpha: 0.5),
                blurRadius: 15,
              ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black87 : Colors.white60,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopItemCard(ShopItem item, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (item.isOwned) {
          _selectItem(item);
        } else {
          _buyItem(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primaryButton : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryButton.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                const Spacer(),
                Builder(
                  builder: (context) {
                    if (item.type == ShopItemType.theme) {
                      IconData icon = Icons.wallpaper;
                      Color color = Colors.purpleAccent;
                      if (item.name.contains('Forest')) {
                        icon = Icons.forest;
                        color = Colors.green;
                      } else if (item.name.contains('Space') ||
                          item.name.contains('Cosmic')) {
                        icon = Icons.rocket_launch;
                        color = Colors.blueAccent;
                      }

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: -5,
                              ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          size: 70,
                          color: isSelected ? color : Colors.white54,
                          shadows: [
                            if (isSelected)
                              Shadow(color: color, blurRadius: 15),
                          ],
                        ),
                      );
                    }
                    if (item.type == ShopItemType.iap) {
                      String imagePath = 'assets/icon/premium_coins.png';
                      Color color = Colors.orangeAccent;
                      if (item.id == IapService.removeAdsId) {
                        imagePath = 'assets/icon/premium_no_ads.png';
                        color = Colors.purpleAccent;
                      } else if (item.name.contains('Coins')) {
                        imagePath = 'assets/icon/premium_coins.png';
                        color = AppColors.goldCoin;
                      }

                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(imagePath, fit: BoxFit.cover),
                        ),
                      );
                    }

                    BottleType bType = BottleType.flask;
                    Color bColor = Colors.blue;
                    if (item.name.contains('Neon')) {
                      bType = BottleType.beaker;
                      bColor = Colors.greenAccent;
                    } else if (item.name.contains('Crystal')) {
                      bType = BottleType.potion;
                      bColor = Colors.purpleAccent;
                    } else if (item.name.contains('Nature') ||
                        item.name.contains('Tube')) {
                      bType = BottleType.tube;
                      bColor = Colors.lightGreenAccent;
                    }

                    return CustomBottleWidget(
                      type: bType,
                      liquidColor: isSelected ? bColor : Colors.grey.shade400,
                      isGlowing: isSelected,
                      fillLevel: 0.7,
                      width: 50,
                      height: 70,
                    );
                  },
                ),
                const Spacer(),
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (!item.isOwned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item.type != ShopItemType.iap)
                          Icon(
                            item.costsGems ? Icons.diamond : Icons.monetization_on,
                            color: item.costsGems ? Colors.cyanAccent : AppColors.goldCoin,
                            size: 16,
                          ),
                        if (item.type != ShopItemType.iap) const SizedBox(width: 6),
                        Text(
                          item.type == ShopItemType.iap
                              ? (item.iapPrice ?? '\$0.00')
                              : item.cost.toString(),
                          style: TextStyle(
                            color: item.costsGems
                                ? Colors.cyanAccent
                                : AppColors.goldCoin,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    isSelected ? 'SELECTED' : 'OWNED',
                    style: TextStyle(
                      color: isSelected ? Colors.cyanAccent : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [
                        if (isSelected)
                          Shadow(
                            color: AppColors.primaryButton,
                            blurRadius: 10,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyDisplay(IconData icon, Color color, String amount) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
