import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_motion_background.dart';
import '../app_theme.dart';
import '../core/anomaly_engine.dart';
import '../core/mqtt_service.dart';
import '../models/motor_data.dart';
import 'connect_screen.dart';
import '../widgets/anomaly_banner.dart';
import '../widgets/motor_visualization.dart';
import '../widgets/telemetry_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(this.mqtt, {super.key});

  final MQTTService mqtt;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _historyLimit = 24;

  late final TabController _tabController = TabController(length: 4, vsync: this);
  final List<MotorData> _history = [];

  MotorData? _latest;
  bool _motorEnabled = false;
  bool _publishingRelay = false;
  bool _disconnecting = false;
  bool _hapticConditionActive = false;
  bool _processingAutoCutoff = false;
  String? _dashboardAlert;

  @override
  void initState() {
    super.initState();
    widget.mqtt.onData = (data) {
      final motor = MotorData.fromJson(data);
      final hasTemperatureWarning = AnomalyEngine.isTempWarning(motor.temperature);
      final isOverheated = AnomalyEngine.isTempHigh(motor.temperature);
      _handleHapticFeedback(
        motorEnabled: _motorEnabled,
        vibrationDetected: motor.vibration >= 1,
      );
      setState(() {
        _latest = motor;
        _history.add(motor);
        if (_history.length > _historyLimit) {
          _history.removeAt(0);
        }
        _dashboardAlert = isOverheated
            ? 'Overheat alert: Temperature is ${motor.temperature.toStringAsFixed(1)}°C. Relay cut-off engaged.'
            : null;
      });
      setState(() {
        _dashboardAlert = _temperatureAlertMessage(
          temperature: motor.temperature,
          hasTemperatureWarning: hasTemperatureWarning,
          relayCutOff: isOverheated,
        );
      });
      if (isOverheated) {
        _handleOverheatCutoff(motor.temperature);
      }
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleMotor(bool value) async {
    if (_publishingRelay || _processingAutoCutoff) {
      return;
    }

    if (value && AnomalyEngine.isTempHigh(_latest?.temperature ?? 0)) {
      setState(() {
        _dashboardAlert =
            'Motor start blocked: Temperature is ${( _latest?.temperature ?? 0).toStringAsFixed(1)}°C. Wait until it drops below ${AnomalyEngine.overheatThreshold.toStringAsFixed(0)}°C.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Motor start blocked. Temperature is above ${AnomalyEngine.overheatThreshold.toStringAsFixed(0)}°C.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _publishingRelay = true;
      _motorEnabled = value;
    });
    _handleHapticFeedback(
      motorEnabled: value,
      vibrationDetected: (_latest?.vibration ?? 0) >= 1,
    );

    try {
      widget.mqtt.publishRelayState(value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _motorEnabled = !value;
      });
      _handleHapticFeedback(
        motorEnabled: !value,
        vibrationDetected: (_latest?.vibration ?? 0) >= 1,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update motor state: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishingRelay = false;
        });
      }
    }
  }

  Future<void> _handleOverheatCutoff(double temperature) async {
    if (!_motorEnabled || _processingAutoCutoff) {
      return;
    }

    setState(() {
      _processingAutoCutoff = true;
      _publishingRelay = true;
      _motorEnabled = false;
      _dashboardAlert =
          'Overheat alert: Temperature is ${temperature.toStringAsFixed(1)}°C. Relay cut-off engaged.';
    });
    setState(() {
      _dashboardAlert = _temperatureAlertMessage(
        temperature: temperature,
        hasTemperatureWarning: true,
        relayCutOff: true,
      );
    });
    _handleHapticFeedback(
      motorEnabled: false,
      vibrationDetected: (_latest?.vibration ?? 0) >= 1,
    );

    try {
      widget.mqtt.publishRelayState(false);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Overheat detected at ${temperature.toStringAsFixed(1)}°C. Relay turned OFF automatically.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Automatic relay cut-off failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingAutoCutoff = false;
          _publishingRelay = false;
        });
      }
    }
  }

  void _handleHapticFeedback({
    required bool motorEnabled,
    required bool vibrationDetected,
  }) {
    final shouldVibrate = motorEnabled && vibrationDetected;
    if (shouldVibrate && !_hapticConditionActive) {
      HapticFeedback.heavyImpact();
    }
    _hapticConditionActive = shouldVibrate;
  }

  String? _temperatureAlertMessage({
    required double temperature,
    required bool hasTemperatureWarning,
    required bool relayCutOff,
  }) {
    if (relayCutOff) {
      return 'Overheat alert: Temperature is ${temperature.toStringAsFixed(1)} C. Relay cut-off engaged automatically.';
    }
    if (hasTemperatureWarning) {
      return 'Temperature alert: Temperature is ${temperature.toStringAsFixed(1)} C. Monitor the motor closely.';
    }
    return null;
  }

  Future<bool> _handleExitGuard() async {
    if (!_motorEnabled) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Turn off the motor before disconnecting or leaving this screen.'),
      ),
    );
    return false;
  }

  Future<void> _requestDisconnect() async {
    if (_disconnecting) {
      return;
    }

    if (_motorEnabled) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn Off Motor First'),
          content: const Text(
            'Disconnect is blocked while the motor is ON. Turn off the motor, then try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disconnect'),
            content: const Text('Do you want to disconnect from Motor Guardian?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _disconnecting = true;
    });

    try {
      widget.mqtt.onData = null;
      widget.mqtt.disconnect();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ConnectScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $error')),
      );
      setState(() {
        _disconnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final hasData = latest != null;
    final showLiveTelemetry = hasData && _motorEnabled;
    final effectiveLatest = showLiveTelemetry ? latest : null;
    final previous = showLiveTelemetry && _history.length > 1 ? _history[_history.length - 2] : null;
    final voltageValues = showLiveTelemetry ? _history.map((e) => e.voltage).toList() : <double>[];
    final status = showLiveTelemetry
        ? AnomalyEngine.status(
            voltageHistory: voltageValues,
            temperature: latest.temperature,
            vibration: latest.vibration,
          )
        : 'Turn on the motor to receive values';
    final isHealthy = status == 'Voltage Stable';
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 760;
    final horizontalPadding = width < 420 ? 14.0 : 20.0;

    return WillPopScope(
      onWillPop: _handleExitGuard,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppMotionBackground(progress: 0.88),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 12),
                    child: Column(
                      children: [
                        if (isNarrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    padding: const EdgeInsets.all(10),
                                    decoration: _panelBox(18),
                                    child: Image.asset(AppBrand.logoAsset),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(AppBrand.appName, style: Theme.of(context).textTheme.titleLarge),
                                        const SizedBox(height: 4),
                                        Text(
                                          status,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: isHealthy ? AppBrand.cyan : const Color(0xFFFFB69A),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: _panelBox(18).copyWith(
                                        color: AppBrand.cyan.withValues(alpha: 0.12),
                                      ),
                                      child: Text(
                                        hasData ? '${_history.length} samples' : '-',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: _disconnecting ? null : _requestDisconnect,
                                      icon: _disconnecting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.logout_rounded),
                                      label: const Text('Disconnect'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                padding: const EdgeInsets.all(10),
                                decoration: _panelBox(18),
                                child: Image.asset(AppBrand.logoAsset),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppBrand.appName, style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 4),
                                    Text(
                                      status,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: isHealthy ? AppBrand.cyan : const Color(0xFFFFB69A),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: _panelBox(18).copyWith(
                                  color: AppBrand.cyan.withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  hasData ? '${_history.length} samples' : '-',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.tonalIcon(
                                onPressed: _disconnecting ? null : _requestDisconnect,
                                icon: _disconnecting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.logout_rounded),
                                label: const Text('Disconnect'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: _panelBox(18).copyWith(
                            gradient: LinearGradient(
                              colors: [
                                AppBrand.amber.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.04),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.precision_manufacturing_rounded, color: AppBrand.amber, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  hasData
                                      ? 'Motor telemetry has been received and stored for monitoring.'
                                      : 'Turn on the motor to receive values.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_dashboardAlert != null) ...[
                          const SizedBox(height: 12),
                          AnomalyBanner(message: _dashboardAlert!),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          decoration: _panelBox(22),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: width < 560,
                            tabAlignment: width < 560 ? TabAlignment.start : TabAlignment.fill,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: AppBrand.cyan.withValues(alpha: 0.16),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppBrand.slate,
                            tabs: const [
                              Tab(text: 'Overview'),
                              Tab(text: 'Analysis'),
                              Tab(text: 'History'),
                              Tab(text: 'Insights'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(context, effectiveLatest, previous, width),
                        _buildAnalysisTab(context),
                        _buildHistoryTab(context),
                        _buildInsightsTab(context, effectiveLatest, previous, status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    MotorData? latest,
    MotorData? previous,
    double width,
  ) {
    final efficiencyPercent = latest == null ? null : _estimateEfficiencyPercent(latest.rpm);
    final powerWatts = latest == null ? null : (latest.voltage * latest.current);

    final heroContent = width > 920
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: MotorVisualization(
                  rpm: latest?.rpm ?? 0,
                  vibration: latest?.vibration ?? 0,
                  temperature: latest?.temperature ?? 0,
                  current: latest?.current ?? 0,
                  voltage: latest?.voltage ?? 0,
                  isActive: latest != null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _VibrationStatusCard(
                  vibration: latest?.vibration,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MotorVisualization(
                rpm: latest?.rpm ?? 0,
                vibration: latest?.vibration ?? 0,
                temperature: latest?.temperature ?? 0,
                current: latest?.current ?? 0,
                voltage: latest?.voltage ?? 0,
                isActive: latest != null,
              ),
              const SizedBox(height: 18),
              _VibrationStatusCard(
                vibration: latest?.vibration,
              ),
            ],
          );

    return ListView(
      padding: EdgeInsets.fromLTRB(width < 420 ? 14 : 20, 8, width < 420 ? 14 : 20, 28),
      children: [
        _MotorControlCard(
          motorEnabled: _motorEnabled,
          publishingRelay: _publishingRelay,
          onChanged: _toggleMotor,
          compact: true,
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: width < 520 ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: width < 520 ? 2.35 : 2.2,
          children: [
            _overviewStatCard(
              context: context,
              title: 'Efficiency',
              value: efficiencyPercent == null ? '-' : '${efficiencyPercent.toStringAsFixed(1)}%',
              subtitle: latest == null ? 'Turn on the motor to receive values' : 'Estimated from live RPM',
              icon: Icons.percent_rounded,
              accent: const Color(0xFF74F0C8),
            ),
            _overviewStatCard(
              context: context,
              title: 'Power Consumption',
              value: _powerValue(powerWatts),
              subtitle: latest == null ? 'Turn on the motor to receive values' : 'Calculated using Voltage x Current',
              icon: Icons.energy_savings_leaf_rounded,
              accent: const Color(0xFF77D5FF),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _glassPanel(
          child: heroContent,
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: width < 520 ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: width < 520 ? 1.7 : width > 980 ? 1.2 : 0.92,
          children: [
            _metricCard(context, 'Voltage', _value(latest?.voltage, suffix: ' V'),
                _deltaOrNull(latest?.voltage, previous?.voltage), Icons.bolt_rounded, const Color(0xFF77D5FF)),
            _metricCard(context, 'Temperature', _value(latest?.temperature, suffix: ' deg C'),
                _deltaOrNull(latest?.temperature, previous?.temperature), Icons.thermostat_rounded, const Color(0xFFFF8C5A)),
            _metricCard(context, 'Current', _value(latest?.current, suffix: ' A'),
                _deltaOrNull(latest?.current, previous?.current), Icons.electric_bolt_rounded, const Color(0xFF5CE1E6)),
            _metricCard(context, 'RPM', _value(latest?.rpm, digits: 0),
                _deltaOrNull(latest?.rpm, previous?.rpm), Icons.speed_rounded, AppBrand.amber),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalysisTab(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final chartHeight = width < 520 ? 180.0 : width < 900 ? 200.0 : 220.0;

    Widget panel(String title, String subtitle, Widget child) {
      return _glassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            SizedBox(height: chartHeight, child: child),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(width < 420 ? 14 : 20, 8, width < 420 ? 14 : 20, 28),
      children: [
        GridView.count(
          crossAxisCount: width > 980 ? 2 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: width > 980 ? 1.45 : width < 520 ? 1.0 : 1.18,
          children: [
            panel(
              'Voltage Stability',
              'Grid quality and fluctuation profile',
              TelemetryChart(
                unit: 'V',
                lines: [
                  ChartLine(
                    label: 'Voltage',
                    color: const Color(0xFF77D5FF),
                    values: _history.map((e) => e.voltage).toList(),
                  ),
                ],
              ),
            ),
            panel(
              'Current Flow',
              'Load draw and operating current trend',
              TelemetryChart(
                unit: 'A',
                lines: [
                  ChartLine(
                    label: 'Current',
                    color: const Color(0xFF5CE1E6),
                    values: _history.map((e) => e.current).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_history.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(width < 420 ? 14 : 20, 8, width < 420 ? 14 : 20, 28),
        children: [
          _glassPanel(
            child: Text(
              'Turn on the motor to start storing historical telemetry samples.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(width < 420 ? 14 : 20, 8, width < 420 ? 14 : 20, 28),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = _history.reversed.toList()[index];
        return _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sample ${_history.length - index}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _historyChip('Voltage', '${item.voltage.toStringAsFixed(1)} V'),
                  _historyChip('Current', '${item.current.toStringAsFixed(1)} A'),
                  _historyChip('RPM', item.rpm.toStringAsFixed(0)),
                  _historyChip('Temp', '${item.temperature.toStringAsFixed(1)} deg C'),
                  _historyChip('Vibration', _vibrationLabel(item.vibration)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightsTab(
    BuildContext context,
    MotorData? latest,
    MotorData? previous,
    String status,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (latest == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(width < 420 ? 14 : 20, 8, width < 420 ? 14 : 20, 28),
        children: [
          _glassPanel(
            child: Text(
              'Turn on the motor to receive values for maintenance and anomaly insights.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }

    final rpmDrift = previous == null ? 0.0 : latest.rpm - previous.rpm;
    final avgTemp = _history.map((e) => e.temperature).reduce((a, b) => a + b) / _history.length;
    final vibrationEvents = _history.where((e) => e.vibration >= 1).length;
    final voltageValues = _history.map((e) => e.voltage).toList();
    final currentValues = _history.map((e) => e.current).toList();
    final rpmValues = _history.map((e) => e.rpm).toList();
    final isVoltageFluctuating = AnomalyEngine.isVoltageFluctuating(voltageValues);
    final currentSpread = _spread(currentValues);
    final rpmSpread = _spread(rpmValues);
    final voltageTrend = _trendDirection(voltageValues);
    final currentTrend = _trendDirection(currentValues);
    final tempTrend = _trendDirection(_history.map((e) => e.temperature).toList());

    final maintenanceItems = [
      (
        'Bearing inspection',
        vibrationEvents > 0
            ? 'Binary vibration signal was triggered. Inspect bearing seating, alignment, and shaft play.'
            : 'No vibration alert in recent samples. Continue routine lubrication and housing checks.',
        'Preventive maintenance',
        Icons.settings_input_component_rounded,
        const Color(0xFFFFD166)
      ),
      (
        'Cooling path service',
        avgTemp > 62
            ? 'Thermal load is trending high. Clean vents and validate airflow immediately.'
            : 'Cooling performance is acceptable. Keep airflow paths clean and unobstructed.',
        'Preventive maintenance',
        Icons.air_rounded,
        const Color(0xFFFF8C5A)
      ),
      (
        'Power feed validation',
        isVoltageFluctuating
            ? 'Voltage is fluctuating compared with the previous historical sample. Check supply stability and terminal connections.'
            : 'Voltage is stable against the recent historical sample. Verify terminal tightness during the next shutdown window.',
        'Preventive maintenance',
        Icons.bolt_rounded,
        const Color(0xFF77D5FF)
      ),
    ];

    final anomalyItems = [
      (
        'Thermal anomaly',
        latest.temperature > 70
            ? 'Motor temperature has crossed the high threshold and indicates overheating behavior.'
            : 'No critical thermal anomaly. Temperature remains within controlled range.',
        latest.temperature > 70 ? 'High' : 'Low',
        Icons.thermostat_rounded,
        const Color(0xFFFF8C5A)
      ),
      (
        'Vibration anomaly',
        latest.vibration >= 1
            ? 'Binary vibration signal is active and indicates abnormal vibration detection.'
            : 'Binary vibration signal is inactive and no vibration alert is currently reported.',
        latest.vibration >= 1 ? 'High' : 'Low',
        Icons.vibration_rounded,
        const Color(0xFFFFD166)
      ),
      (
        'Power anomaly',
        isVoltageFluctuating
            ? 'Voltage is fluctuating versus the previous sample and may indicate unstable supply behavior.'
            : 'Supply voltage remains stable when compared with the recent sample history.',
        isVoltageFluctuating ? 'Medium' : 'Low',
        Icons.electric_bolt_rounded,
        const Color(0xFF77D5FF)
      ),
      (
        'Speed instability',
        rpmDrift.abs() > 90
            ? 'RPM changed sharply between the latest two samples, suggesting load instability.'
            : rpmSpread > 140
                ? 'RPM spread across historical data suggests load variation over time.'
                : 'Speed response is steady and matches nominal operating behavior.',
        rpmDrift.abs() > 90 ? 'Medium' : 'Low',
        Icons.speed_rounded,
        const Color(0xFF5CE1E6)
      ),
      (
        'Historical insight',
        'Voltage trend: $voltageTrend. Current trend: $currentTrend. Temperature trend: $tempTrend. Historical current spread is ${currentSpread.toStringAsFixed(2)} A.',
        'History-based',
        Icons.analytics_rounded,
        AppBrand.amber
      ),
      (
        'Overall assessment',
        status,
        status == 'Voltage Stable' ? 'Stable' : 'Attention',
        Icons.health_and_safety_rounded,
        status == 'Voltage Stable' ? AppBrand.cyan : const Color(0xFFFF9A7A)
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(width < 420 ? 14 : 20, 8, width < 420 ? 14 : 20, 28),
      children: [
        Text('Anomalies', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        ...anomalyItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _insightCard(context, item.$1, item.$2, item.$3, item.$4, item.$5),
            )),
        const SizedBox(height: 10),
        Text('Maintenance', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        ...maintenanceItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _insightCard(context, item.$1, item.$2, item.$3, item.$4, item.$5),
            )),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    String value,
    double? delta,
    IconData icon,
    Color accent,
  ) {
    final rising = (delta ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelBox(30).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                rising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: rising ? const Color(0xFF74F0C8) : const Color(0xFFFFA085),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  delta == null
                      ? 'Turn on the motor'
                      : title == 'Vibration'
                          ? _vibrationDeltaLabel(delta)
                          : '${rising ? '+' : ''}${delta.toStringAsFixed(2)} vs last sample',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelBox(24).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppBrand.slate,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelBox(30).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _insightCard(
    BuildContext context,
    String title,
    String body,
    String badge,
    IconData icon,
    Color accent,
  ) {
    return _glassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _historyChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppBrand.slate, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  BoxDecoration _panelBox(double radius) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
    );
  }
}

class _VibrationStatusCard extends StatelessWidget {
  const _VibrationStatusCard({required this.vibration});

  final double? vibration;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final detected = (vibration ?? 0) >= 1;
    final hasData = vibration != null;
    final accent = hasData
        ? detected
            ? const Color(0xFFFFD166)
            : AppBrand.cyan
        : AppBrand.slate;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: width < 420 ? 14 : 18, vertical: width < 420 ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vibration_rounded, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Vibration Status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            hasData ? (detected ? 'Detected' : 'Not Detected') : '-',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            hasData
                ? detected
                    ? 'Binary vibration signal is active.'
                    : 'Binary vibration signal is inactive.'
                : 'Turn on the motor to receive values.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: hasData ? Colors.white : AppBrand.slate,
                ),
          ),
        ],
      ),
    );
  }
}

class _MotorControlCard extends StatelessWidget {
  const _MotorControlCard({
    required this.motorEnabled,
    required this.publishingRelay,
    required this.onChanged,
    this.compact = false,
  });

  final bool motorEnabled;
  final bool publishingRelay;
  final Future<void> Function(bool) onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final accent = motorEnabled ? const Color(0xFF74F0C8) : const Color(0xFFFFA085);
    final stackActions = width < 420;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? (width < 420 ? 12 : 16) : 18,
        vertical: compact ? (width < 420 ? 12 : 14) : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackActions)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, color: accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Motor Control',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: motorEnabled,
                    onChanged: publishingRelay ? null : (value) => onChanged(value),
                    activeThumbColor: AppBrand.cyan,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.power_settings_new_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Motor Control',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(
                  value: motorEnabled,
                  onChanged: publishingRelay ? null : (value) => onChanged(value),
                  activeThumbColor: AppBrand.cyan,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          SizedBox(height: compact ? 10 : 18),
          Text(
            motorEnabled ? 'Motor ON' : 'Motor OFF',
            style: (compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineLarge)
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            publishingRelay
                ? 'Publishing relay state to motor_guardian/relay...'
                : 'Use the switch to turn the motor on or off.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

double? _deltaOrNull(double? current, double? previous) {
  if (current == null || previous == null) {
    return null;
  }
  return current - previous;
}

String _value(double? input, {int digits = 1, String suffix = ''}) {
  if (input == null) {
    return '-';
  }
  return '${input.toStringAsFixed(digits)}$suffix';
}

String _vibrationLabel(double? value) {
  if (value == null) {
    return '-';
  }
  return value >= 1 ? 'Detected' : 'Normal';
}

String _vibrationDeltaLabel(double delta) {
  if (delta > 0) {
    return 'Signal turned on';
  }
  if (delta < 0) {
    return 'Signal turned off';
  }
  return 'No signal change';
}

double _estimateEfficiencyPercent(double rpm) {
  const ratedRpm = 3000.0;
  final load = (rpm / ratedRpm).clamp(0.0, 1.0);
  // Tuned display model for the requested baseline uplift.
  // Yields ~80% at light load, peaking ~90% near rated speed.
  return (80.0 + (load * 10.0)).clamp(0.0, 100.0);
}

String _powerValue(double? watts) {
  if (watts == null) {
    return '-';
  }
  if (watts >= 1000) {
    return '${(watts / 1000).toStringAsFixed(2)} kW';
  }
  return '${watts.toStringAsFixed(1)} W';
}

double _spread(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  return max - min;
}

String _trendDirection(List<double> values) {
  if (values.length < 2) {
    return '-';
  }
  final first = values.first;
  final last = values.last;
  final delta = last - first;
  if (delta.abs() < 0.01) {
    return 'stable';
  }
  return delta > 0 ? 'rising' : 'falling';
}
