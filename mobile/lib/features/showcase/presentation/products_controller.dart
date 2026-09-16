import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../data/products_api.dart';
import '../domain/showcase_product.dart';

class ProductsController extends ChangeNotifier {
  ProductsController(this.auth, this.api);

  final AuthController auth;
  final ProductsApi api;

  List<ShowcaseProduct> items = const [];
  String? error;
  bool loading = false;
  bool loaded = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await auth.authorized(api.list);
      loaded = true;
    } on AuthFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'โหลดสินค้าไม่ได้ กรุณาลองใหม่';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  ShowcaseProduct? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
