class HawalaTransaction {
  final String id;
  final int? companyId;
  final String companyName;
  final String companyType;
  final double amount;
  final String currency;
  final DateTime date;
  final String? notes;
  final DateTime? createdAt;

  HawalaTransaction({
    required this.id,
    this.companyId,
    required this.companyName,
    required this.companyType,
    required this.amount,
    required this.currency,
    required this.date,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'company_name': companyName,
      'company_type': companyType,
      'amount': amount,
      'currency': currency,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory HawalaTransaction.fromMap(Map<String, dynamic> map) {
    return HawalaTransaction(
      id: map['id'],
      companyId: map['company_id'],
      companyName: map['company_name'],
      companyType: map['company_type'],
      amount: map['amount'],
      currency: map['currency'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      notes: map['notes'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}
