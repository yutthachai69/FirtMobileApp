import '../../../core/network/api_client.dart';
import '../domain/showcase_product.dart';

abstract interface class ProductsApi {
  Future<List<ShowcaseProduct>> list(String access);
  Future<ShowcaseProduct> get(String access, String id);
}

class HttpProductsApi implements ProductsApi {
  const HttpProductsApi(this.client);
  final ApiClient client;

  @override
  Future<List<ShowcaseProduct>> list(String access) async {
    final data = await client.get(
      '/v1/products',
      access: access,
      query: {'limit': 100},
    );
    final raw = data['products'] as List? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ShowcaseProduct.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ShowcaseProduct> get(String access, String id) async {
    final data = await client.get('/v1/products/$id', access: access);
    final raw = data['product'];
    if (raw is! Map<String, dynamic>) {
      throw StateError('Product response did not include a product');
    }
    return ShowcaseProduct.fromJson(raw);
  }
}
