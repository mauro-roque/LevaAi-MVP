class FreighterEntity {
  final String id;
  final String name;
  final String vehicleModel;
  final double maxWeightKg;
  final double cargoVolumeM3;

  const FreighterEntity({
    required this.id,
    required this.name,
    required this.vehicleModel,
    required this.maxWeightKg,
    required this.cargoVolumeM3,
  });
}
