import '../../domain/entities/freighter_entity.dart';

class FreighterModel extends FreighterEntity {
  const FreighterModel({
    required super.id,
    required super.name,
    required super.vehicleModel,
    required super.maxWeightKg,
    required super.cargoVolumeM3,
  });

  factory FreighterModel.fromJson(Map<String, dynamic> json) {
    return FreighterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      vehicleModel: json['vehicleModel'] as String,
      maxWeightKg: (json['maxWeightKg'] as num).toDouble(),
      cargoVolumeM3: (json['cargoVolumeM3'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vehicleModel': vehicleModel,
    'maxWeightKg': maxWeightKg,
    'cargoVolumeM3': cargoVolumeM3,
  };
}
