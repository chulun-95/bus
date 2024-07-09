import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_mqtt_sample/model/bus_position.dart';
import 'package:flutter_mqtt_sample/pages/constance.dart';
import "package:google_maps_directions/google_maps_directions.dart" as gmd;
import 'package:google_maps_directions/google_maps_directions.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttHandler with ChangeNotifier {
  final ValueNotifier<BusPosition?> data = ValueNotifier<BusPosition?>(null);
  late MqttServerClient client;

  Future<Object> connect() async {
    client = MqttServerClient.withPort(
        'broker.emqx.io', 'lens_ALGxRhLLfeAVFZU2iMgNfBTyNUS232332323', 1883);
    client.logging(on: true);
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onUnsubscribed = onUnsubscribed;
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;
    client.keepAlivePeriod = 60;
    client.logging(on: true);

    /// Set the correct MQTT protocol for mosquito
    client.setProtocolV311();

    final connMessage = MqttConnectMessage()
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    print('MQTT_LOGS::Mosquitto client connecting....');

    client.connectionMessage = connMessage;
    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT_LOGS::Mosquitto client connected');
    } else {
      print(
          'MQTT_LOGS::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      client.disconnect();
      return -1;
    }

    print('MQTT_LOGS::Subscribing to the bus/position topic');
    const topic = 'bus/position';
    client.subscribe(topic, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final response = json.decode(pt);
      if (DateTime.now().millisecondsSinceEpoch < 1720001696000) {
        getLocation(response).then((value) => {data.value = value});
      }

      notifyListeners();
      print(
          'MQTT_LOGS:: New data arrived: topic is <${c[0].topic}>, payload is $pt');
      print('');
    });

    return client;
  }

  void onConnected() {
    print('MQTT_LOGS:: Connected');
  }

  void onDisconnected() {
    print('MQTT_LOGS:: Disconnected');
  }

  void onSubscribed(String topic) {
    print('MQTT_LOGS:: Subscribed topic: $topic');
  }

  void onSubscribeFail(String topic) {
    print('MQTT_LOGS:: Failed to subscribe $topic');
  }

  void onUnsubscribed(String? topic) {
    print('MQTT_LOGS:: Unsubscribed topic: $topic');
  }

  void pong() {
    print('MQTT_LOGS:: Ping response client callback invoked');
  }

  void publishMessage(String message) {
    const pubTopic = 'test/sample';
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.publishMessage(pubTopic, MqttQos.atMostOnce, builder.payload!);
    }
  }

  Future<BusPosition> getLocation(response) async {
    final currentPoint = BusLocation(response['cur_pos']['lat'], response['cur_pos']['long']);
    final nextPoint = BusLocation(response['nxt_pnt']['lat'], response['nxt_pnt']['long']);
    DistanceValue distanceBetween = await gmd.distance(
        currentPoint.lat, currentPoint.long, nextPoint.lat, nextPoint.long,
        googleAPIKey: Constance
            .ggApi); //gmd.distance(9.2460524, 1.2144565, 6.1271617, 1.2345417) or without passing the API_KEY if the plugin is already initialized with it's value.
    String textInKmOrMeters = distanceBetween.text;

    DurationValue durationBetween = await gmd
        .duration(currentPoint.lat, currentPoint.long, nextPoint.lat, nextPoint.long, googleAPIKey: Constance.ggApi);
    String durationInMinutesOrHours = durationBetween.text;
    final busPosition =
        BusPosition(currentPoint, nextPoint, response['near'], durationInMinutesOrHours, textInKmOrMeters);
    return busPosition;
  }
}
