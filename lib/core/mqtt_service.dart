import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  static const String _telemetryTopic = "motor_guardian/telemetry";
  static const String _relayTopic = "motor_guardian/relay";

  late MqttServerClient client;

  Function(Map<String,dynamic>)? onData;

  Future connect(
      String username,
      String password
  ) async {



    const String brokerUrl = "b430c21bbccd4810b64214467105b56e.s1.eu.hivemq.cloud";
    const int portNumber = 8883;


    client = MqttServerClient(brokerUrl, "motor_guardian_client");

    client.port = portNumber;
    client.secure = true;

    client.logging(on: false);

    client.connectionMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .startClean();

    await client.connect();



    client.subscribe(
        _telemetryTopic,
        MqttQos.atLeastOnce
    );


    client.updates!.listen((events){

      final rec = events[0].payload as MqttPublishMessage;

      final payload =
          MqttPublishPayload.bytesToStringAsString(
              rec.payload.message);

      final data = jsonDecode(payload);

      if(onData != null){
        onData!(data);
      }

    });

  }

  void publishRelayState(bool isOn) {
    final payload = jsonEncode({'value': isOn});
    final builder = MqttClientPayloadBuilder()..addString(payload);

    client.publishMessage(
      _relayTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.unsubscribe(_telemetryTopic);
      client.disconnect();
    }
  }

}
