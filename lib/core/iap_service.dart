import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'storage_service.dart';
import 'ad_manager.dart';

class IapService {
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static late StreamSubscription<List<PurchaseDetails>> _subscription;

  static const String removeAdsId = 'remove_ads_tier_1';
  static const String buyCoins1000Id = 'coins_pack_large';
  static const String buyCoins500Id = 'coins_pack_small';

  // State
  static bool _isAvailable = false;
  static List<ProductDetails> _products = [];
  static bool get isAvailable => _isAvailable;
  static List<ProductDetails> get products => _products;

  static Future<void> init() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (_isAvailable) {
      await _loadProducts();
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen(
        (purchaseDetailsList) {
          _listenToPurchaseUpdated(purchaseDetailsList);
        },
        onDone: () {
          _subscription.cancel();
        },
        onError: (error) {
          debugPrint('IAP stream error: $error');
        },
      );
    }
  }

  static Future<void> _loadProducts() async {
    const Set<String> _kIds = <String>{
      removeAdsId,
      buyCoins1000Id,
      buyCoins500Id,
    };
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(_kIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  static void dispose() {
    if (_isAvailable) {
      _subscription.cancel();
    }
  }

  static Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    if (product.id == removeAdsId) {
      // Non-consumable
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // Consumable (Coins, Gems)
      await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
    }
  }

  static Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  static void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if necessary
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _deliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final productId = purchaseDetails.productID;

    if (productId == removeAdsId) {
      await StorageService.setHasRemovedAds(true);

      AdManager.updateHasRemovedAds(true);

      debugPrint('Ads removed successfully.');
    } else if (productId == buyCoins1000Id) {
      int currentCoins = await StorageService.getCoins();
      await StorageService.saveCoins(currentCoins + 1000);
      debugPrint('1000 coins added.');
    } else if (productId == buyCoins500Id) {
      int currentCoins = await StorageService.getCoins();
      await StorageService.saveCoins(currentCoins + 500);
      debugPrint('500 coins added.');
    }
  }
}
