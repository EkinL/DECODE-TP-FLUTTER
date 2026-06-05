class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? picture;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.picture,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      // L'API renvoie le prix sous forme de String (ex: "230.99")
      price: double.parse(json['price'].toString()),
      picture: json['picture'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
