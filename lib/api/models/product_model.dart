class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? picture;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
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
    );
  }
}
