import 'package:flutter/foundation.dart';

/// Session-level saved products used by both the list and product details.
/// A backend repository can replace this controller without changing the UI.
class SavedProductsController extends ChangeNotifier {
  final Set<String> _ids = {};

  bool contains(String productId) => _ids.contains(productId);

  void toggle(String productId) {
    _ids.contains(productId) ? _ids.remove(productId) : _ids.add(productId);
    notifyListeners();
  }
}

final savedProductsController = SavedProductsController();
