class MotorData {

  final double voltage;
  final double current;
  final double rpm;
  final double temperature;
  final double vibration;

  const MotorData({
    required this.voltage,
    required this.current,
    required this.rpm,
    required this.temperature,
    required this.vibration,
  });

  factory MotorData.fromJson(Map<String,dynamic> json){
    final rawVoltage = json['voltage'].toDouble();
    final normalizedVoltage = _normalizeTo110V(rawVoltage);

    return MotorData(
      voltage: normalizedVoltage,
      current: json['current'].toDouble(),
      rpm: json['rpm'].toDouble(),
      temperature: json['temperature'].toDouble(),
      vibration: json['vibration'].toDouble(),
    );

  }

  static double _normalizeTo110V(double rawVoltage) {
    if (rawVoltage >= 180) {
      return rawVoltage * (110.0 / 230.0);
    }
    return rawVoltage;
  }

}
