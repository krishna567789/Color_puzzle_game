import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'analytics_service.dart';
import '../content/content_repository.dart';
import '../content/content_types.dart';
import 'storage_service.dart';
import 'ad_manager.dart';

class IapService {
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static late StreamSubscription<List<PurchaseDetails>> _subscription;

  // State
  static bool _isAvailable = false;
  static List<ProductDetails> _products = [];
  static bool get isAvailable => _isAvailable;
  static List<ProductDetails> get products => _products;

  /// The catalogue row behind a store product id, which is where what a purchase
  /// *delivers* is written. A listing the game cannot describe pays out nothing,
  /// so the store and the wallet can never disagree about a product's worth.
  static ShopSpec? listing(String productId) =>
      ContentRepository.content.shopForProduct(productId);

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
    // The products this build sells are content, so a listing is added by
    // shipping a new `assets/content/shop.json`, never by a remote value.
    final Set<String> productIds = {
      for (final item in ContentRepository.content.shop)
        if (item.isIap && item.iapProductId.isNotEmpty) item.iapProductId,
    };
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(productIds);
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
    if (listing(product.id)?.isEntitlement ?? false) {
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
          AnalyticsService.logPurchaseFailed(
            purchaseDetails.error?.message ?? 'unknown',
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased) {
          _deliverProduct(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.restored) {
          // Only an entitlement may be re-granted on a restore; crediting a
          // consumable wallet again would mint free coins.
          if (listing(purchaseDetails.productID)?.isEntitlement ?? false) {
            _deliverProduct(purchaseDetails);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final productId = purchaseDetails.productID;
    final purchaseId = purchaseDetails.purchaseID ?? productId;
    if (!await StorageService.markPurchaseDelivered(purchaseId)) return;

    final item = listing(productId);
    if (item == null) {
      // The store took money for something this build's catalogue does not
      // describe. That is a listing mistake, and it has to be visible in a log
      // rather than paid for quietly by a player who gets nothing.
      debugPrint('Purchased product $productId has no shop listing');
      AnalyticsService.logPurchaseFailed('unlisted product $productId');
      return;
    }
    if (item.entitlement == ShopSpec.kRemoveAds) {
      await StorageService.setHasRemovedAds(true);

      AdManager.updateHasRemovedAds(true);
      AnalyticsService.logAdsRemoved();
      AnalyticsService.logPurchase(productId: productId, source: 'iap');

      debugPrint('Ads removed successfully.');
    }
    if (item.grantCoins > 0) {
      await _addCoins(item.grantCoins, productId);
    }
  }

  static Future<void> _addCoins(int amount, String productId) async {
    // Credited as a delta through the wallet queue: a win paying out at the
    // same moment used to have this purchase's coins written straight over it.
    await StorageService.addCoins(amount);
    AnalyticsService.logPurchase(productId: productId, source: 'iap');
    debugPrint('$amount coins added.');
  }
}
