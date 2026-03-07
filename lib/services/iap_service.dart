import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'entitlements_service.dart';
import 'auth_service.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs - Use placeholders as requested
  static const String premiumSubscriptionId = 'premium_monthly';
  static const String scrolls3Id = 'scrolls_3';
  static const String scrolls10Id = 'scrolls_10';
  static const String scrolls30Id = 'scrolls_30';

  final List<ProductDetails> _products = [];
  bool _available = false;

  final StreamController<PurchaseDetails> _purchaseController =
      StreamController<PurchaseDetails>.broadcast();
  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  Future<void> initialize() async {
    _available = await _inAppPurchase.isAvailable();
    if (!_available) {
      debugPrint('🛒 IAP: Not available on this device');
      return;
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('🛒 IAP Error: $error');
    });

    await loadProducts();
  }

  Future<void> loadProducts() async {
    final Set<String> ids = {
      premiumSubscriptionId,
      scrolls3Id,
      scrolls10Id,
      scrolls30Id
    };
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('🛒 IAP: Products not found: ${response.notFoundIDs}');
    }

    _products.clear();
    _products.addAll(response.productDetails);
    debugPrint('🛒 IAP: Loaded ${_products.length} products');
  }

  List<ProductDetails> get products => _products;

  Future<void> buyPremium() async {
    final product = _products.firstWhere(
      (p) => p.id == premiumSubscriptionId,
      orElse: () => throw Exception('Premium product not found'),
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> buyScrolls(String productId) async {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Scrolls product not found: $productId'),
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('🛒 IAP Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final success = await _verifyAndGrant(purchaseDetails);
          if (success) {
            if (purchaseDetails.pendingCompletePurchase) {
              await _inAppPurchase.completePurchase(purchaseDetails);
            }
          }
        }

        _purchaseController.add(purchaseDetails);
      }
    }
  }

  Future<bool> _verifyAndGrant(PurchaseDetails purchaseDetails) async {
    final userId = AuthService().currentUser?.id;
    if (userId == null) return false;

    debugPrint('🛒 IAP: Granting entitlement for ${purchaseDetails.productID}');

    final entitlements = EntitlementsService();

    if (purchaseDetails.productID == premiumSubscriptionId) {
      await entitlements.grantEntitlement(
          userId, 'premium', purchaseDetails.purchaseID);
      return true;
    } else if (purchaseDetails.productID == scrolls3Id ||
        purchaseDetails.productID == scrolls10Id ||
        purchaseDetails.productID == scrolls30Id) {
      // Logic for adding scrolls would go here (requires DB update)
      // For now, just return true as placeholder
      return true;
    }

    return false;
  }

  void dispose() {
    _subscription.cancel();
    _purchaseController.close();
  }
}
