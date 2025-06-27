class Animal {
  final String id;
  final String name;
  final String ownerId;
  final String? ownerName;
  final String? ownerContact;
  final String? ownerAddress;
  final List<String>? vaccines;
  final List<String>? medicalHistory;
  final String? nfcTag;
  final double? latitude;
  final double? longitude;
  final bool isForSale;
  final double? price;

  Animal({
    this.isForSale = false,
    this.price,
    required this.id,
    required this.name,
    required this.ownerId,
    this.ownerName,
    this.ownerContact,
    this.ownerAddress,
    this.vaccines,
    this.medicalHistory,
    this.nfcTag,
    this.latitude,
    this.longitude,
  });

  // Méthode pour créer une copie de l'animal avec des valeurs mises à jour
  Animal copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? ownerName,
    String? ownerContact,
    String? ownerAddress,
    List<String>? vaccines,
    List<String>? medicalHistory,
    String? nfcTag,
    double? latitude,
    double? longitude,
    bool? isForSale,
    double? price,
  }) {
    return Animal(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerContact: ownerContact ?? this.ownerContact,
      ownerAddress: ownerAddress ?? this.ownerAddress,
      vaccines: vaccines ?? this.vaccines,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      nfcTag: nfcTag ?? this.nfcTag,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isForSale: isForSale ?? this.isForSale,
      price: price ?? this.price,
    );
  }
}
