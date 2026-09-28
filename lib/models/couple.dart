/// Two people sharing one space. Mirrors a row in the `couples` table.
class Couple {
  const Couple({
    required this.id,
    required this.pairingCode,
    this.anniversaryDate,
  });

  final String id;
  final String pairingCode;
  final DateTime? anniversaryDate;

  factory Couple.fromMap(Map<String, dynamic> row) {
    final date = row['anniversary_date'] as String?;
    return Couple(
      id: row['id'] as String,
      pairingCode: row['pairing_code'] as String,
      anniversaryDate: date == null ? null : DateTime.parse(date),
    );
  }
}
