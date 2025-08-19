class Company {
  final int? id; // nullable for new records
  final String name;
  final String companyType;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String country;
  final String taxNumber;
  final String registrationNumber;
  final String notes;

  const Company({
    this.id,
    required this.name,
    required this.companyType,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.country,
    required this.taxNumber,
    required this.registrationNumber,
    required this.notes,
  });

  // Creates a new Company object copying this one but with some updated fields
  Company copyWith({
    int? id,
    String? name,
    String? companyType,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? country,
    String? taxNumber,
    String? registrationNumber,
    String? notes,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      companyType: companyType ?? this.companyType,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      taxNumber: taxNumber ?? this.taxNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      notes: notes ?? this.notes,
    );
  }

  // Convert Company instance to Map for DB insertion/update
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'company_name': name,
      'company_type': companyType,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'country': country,
      'tax_number': taxNumber,
      'registration_number': registrationNumber,
      'notes': notes,
      // Optional fields can be added here such as updated_at
    };
    if (id != null) {
      map['id'] = id;
      // If you want to track updates:
      // map['updated_at'] = DateTime.now().toIso8601String();
    } else {
      // For new records, optionally add created_at:
      map['created_at'] = DateTime.now().toIso8601String();
    }
    return map;
  }

  // Factory constructor to create Company instance from DB map
  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as int?,
      name: map['company_name'] ?? '',
      companyType: map['company_type'] ?? '',
      contactPerson: map['contact_person'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      taxNumber: map['tax_number'] ?? '',
      registrationNumber: map['registration_number'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  @override
  String toString() {
    return 'Company{id: $id, name: $name, type: $companyType}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Company &&
        other.id == id &&
        other.name == name &&
        other.companyType == companyType &&
        other.contactPerson == contactPerson &&
        other.phone == phone &&
        other.email == email &&
        other.address == address &&
        other.city == city &&
        other.country == country &&
        other.taxNumber == taxNumber &&
        other.registrationNumber == registrationNumber &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        companyType.hashCode ^
        contactPerson.hashCode ^
        phone.hashCode ^
        email.hashCode ^
        address.hashCode ^
        city.hashCode ^
        country.hashCode ^
        taxNumber.hashCode ^
        registrationNumber.hashCode ^
        notes.hashCode;
  }
}
