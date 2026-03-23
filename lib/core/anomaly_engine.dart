class AnomalyEngine {
  static const double _voltageFluctuationThreshold = 8.0;
  static const double alertTemperatureThreshold = 40.0;
  static const double cutoffTemperatureThreshold = 50.0;
  static const double overheatThreshold = cutoffTemperatureThreshold;

  static bool isTempWarning(double temperature) {
    return temperature > alertTemperatureThreshold;
  }

  static bool isTempHigh(double temperature) {
    return temperature > cutoffTemperatureThreshold;
  }

  static bool isVibrationHigh(double vibration) {

    return vibration >= 1;

  }

  static bool isVoltageFluctuating(List<double> voltageHistory) {
    if (voltageHistory.length < 2) {
      return false;
    }

    final latest = voltageHistory.last;
    final previous = voltageHistory[voltageHistory.length - 2];
    return (latest - previous).abs() >= _voltageFluctuationThreshold;
  }

  static String status({
    required List<double> voltageHistory,
    required double temperature,
    required double vibration
  }) {

    if (isTempHigh(temperature)) {
      return "Motor Overheating";
    }

    if (isTempWarning(temperature)) {
      return "Temperature Warning";
    }

    if(isVibrationHigh(vibration)){
      return "Motor Vibration Abnormal";
    }

    if(isVoltageFluctuating(voltageHistory)){
      return "Voltage Fluctuating";
    }

    return "Voltage Stable";
  }

}
