// lib/models/card_model.dart
class CardModel {
  /// shape is a short id string matching your asset file names:
  /// e.g. 'circle', 'triangle', 'star', 'rectangle', 'cross', 'whot'
  final String shape;

  /// number for the card: 1..14 (normal) or 20 for WHOT (special)
  final int number;

  CardModel({required this.shape, required this.number});

  /// Convert card to compact string for Firestore storage: "shape|number"
  /// Example: "circle|5" or "whot|20"
  String serialize() => '$shape|$number';

  /// Create CardModel from serialized string. Throws FormatException if invalid.
  static CardModel deserialize(String s) {
    final parts = s.split('|');
    if (parts.length != 2) {
      throw FormatException('Invalid card string: $s');
    }
    final shape = parts[0];
    final number = int.tryParse(parts[1]);
    if (number == null) {
      throw FormatException('Invalid card number in string: $s');
    }
    return CardModel(shape: shape, number: number);
  }

  /// Helpful for debugging
  @override
  String toString() => 'CardModel($shape, $number)';
}
