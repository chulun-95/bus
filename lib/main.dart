import 'dart:async';

import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import 'MqttHandler.dart';
import 'model/bus_position.dart';

void main() {
  runApp(const MaterialApp(
    home: HomePage(),
    debugShowCheckedModeBanner: false,
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _controller;
  MqttHandler mqttHandler = MqttHandler();

  bool isShowing = false;

  BitmapDescriptor? icon;

  BitmapDescriptor? positionBus;
  List<LatLng> positionBusList = <LatLng>[];
  @override
  void initState() {
    super.initState();
    getIcons().then((value) {
      initMarker();
      mqttHandler.connect();
    });
  }

  Future getIcons() async {
    icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 3.2), "assets/icon/ic_school_bus.png");
    positionBus = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 0.1), "assets/icon/ic_bus_stop.png");
  }

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(21.037117583025484, 105.83466669658942),
    zoom: 14.4746,
  );

  final Map<String, Marker> _markers = {};
  Map<CircleId, Circle> circles = <CircleId, Circle>{};

  CircleId? selectedCircle;
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<BusPosition?>(
        builder: (BuildContext mContext, BusPosition? value, Widget? child) {
          if (value?.near == 1 && !isShowing) {
            isShowing = true;
            _showDialog(context);
          }
          if (value != null) {
            _markers["bus"] = Marker(
                markerId: const MarkerId('bus'),
                position: LatLng(value.current.lat, value.current.long),
                icon: icon ?? BitmapDescriptor.defaultMarker);
            moveCamera(LatLng(value.current.lat, value.current.long));
          }
          return Stack(
            children: [
              GoogleMap(
                  myLocationEnabled: false,
                  mapType: MapType.normal,
                  initialCameraPosition: _kGooglePlex,
                  zoomControlsEnabled: false,
                  markers: _markers.values.toSet(),
                  circles: circles.values.toSet(),
                  onTap: (LatLng latLng) {},
                  onCameraMove: (position) {},
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                    _currentLocation();
                  }),
              Container(
                margin: const EdgeInsets.only(left: 20, top: 40),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: Colors.orange, // Set border color
                        width: 1.0), // Set border width
                    borderRadius: const BorderRadius.all(Radius.circular(10.0)), // Set rounded corner radius
                    boxShadow: const [
                      BoxShadow(blurRadius: 10, color: Colors.black, offset: Offset(1, 3))
                    ] // Make rounded corner of border
                    ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          "assets/icon/ic_bus_stop.png",
                          width: 18,
                          height: 18,
                        ),
                        const Text(
                          "Điểm dừng tiếp theo",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        )
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          "assets/icon/ic_school_bus.png",
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(
                          width: 18,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${value?.distance ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${value?.time ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        valueListenable: mqttHandler.data,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _currentLocation,
        label: const Text('My Location'),
        icon: const Icon(Icons.location_on),
      ),
    );
  }

  void _currentLocation() async {
    _requestPermission().then((value) async {
      if (value) {
        LocationData? currentLocation;
        var location = Location();
        try {
          currentLocation = await location.getLocation();
        } on Exception {
          currentLocation = null;
        }

        // _controller?.animateCamera(CameraUpdate.newCameraPosition(
        //   CameraPosition(
        //     bearing: 0,
        //     target: LatLng(currentLocation?.latitude ?? 0, currentLocation?.longitude ?? 0),
        //     zoom: 17.0,
        //   ),
        // ));
          moveCamera(LatLng(21.02362849, 105.8572358));
        // setState(() {
        // });
      }
    });
  }

  Future<bool> _requestPermission() async {
    Location location = Location();

    bool serviceEnabled;
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted;
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  void _showDialog(BuildContext context) {
    Future(() {
      // Future Callback
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Xe bus sắp tới điểm dừng. Vui lòng chuẩn bị!',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ).then((value) {
        isShowing = false;
      });
    });
  }

  void moveCamera(LatLng latLng) {
    if (_controller == null) {
      return;
    }
    _controller?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          bearing: 0,
          target: latLng,
          zoom: 17.0,
        ),
      ));
  }

  void initMarker() {
    positionBusList.add(const LatLng(21.02362849, 105.8572358));
    positionBusList.add(const LatLng(21.02394896, 105.8572412));
    positionBusList.add(const LatLng(21.02496667, 105.85675));
    positionBusList.add(const LatLng(21.02696667, 105.8561333));
    positionBusList.add(const LatLng(21.02771667, 105.8561167));
    positionBusList.add(const LatLng(21.03891667, 105.8520167));
    positionBusList.add(const LatLng(21.04213333, 105.8488667));
    positionBusList.add(const LatLng(21.04941667, 105.83885));
    positionBusList.add(const LatLng(21.04716667, 105.8369333));
    positionBusList.add(const LatLng(21.04363333, 105.833));
    positionBusList.add(const LatLng(21.0448, 105.81735));
    positionBusList.add(const LatLng(221.05223333, 105.8126833));
    positionBusList.add(const LatLng(21.05543333, 105.8114833));
    positionBusList.add(const LatLng(21.0676, 105.8117333));
    positionBusList.add(const LatLng(21.06985, 105.8132333));
    positionBusList.add(const LatLng(21.0592, 105.8340667));
    positionBusList.add(const LatLng(21.04353333, 105.8360333));
    positionBusList.add(const LatLng(21.0414, 105.83615));
    positionBusList.add(const LatLng(21.03836667, 105.8396));
    positionBusList.add(const LatLng(21.034, 105.8349));
    positionBusList.add(const LatLng(21.02788333, 105.8343167));
    positionBusList.add(const LatLng(21.03031667, 105.8362833));
    positionBusList.add(const LatLng(21.02591667, 105.8468333));
    positionBusList.add(const LatLng(21.02451667, 105.8464833));
    positionBusList.add(const LatLng(21.0228, 105.8564833));
    positionBusList.add(const LatLng(21.0228173, 105.8574718));

    // positionBusList.add(const LatLng(21.03185029, 105.8525902));
    // positionBusList.add(const LatLng(21.031800, 105.851950));
    // positionBusList.add(const LatLng(21.03383333, 105.8507833));
    // positionBusList.add(const LatLng(21.03693333, 105.8494333));
    // positionBusList.add(const LatLng(21.04061667, 105.8500167));
    // positionBusList.add(const LatLng(21.04251667, 105.8485167));
    // positionBusList.add(const LatLng(21.04711667, 105.8368833));
    // positionBusList.add(const LatLng(21.043650, 105.8346167));
    // positionBusList.add(const LatLng(21.043700, 105.8327667));
    // positionBusList.add(const LatLng(21.044850, 105.8171833));
    // positionBusList.add(const LatLng(21.052400, 105.8126167));
    // positionBusList.add(const LatLng(21.055550, 105.8112333));
    // positionBusList.add(const LatLng(21.06763333, 105.8117833));
    // positionBusList.add(const LatLng(21.07033333, 105.8134833));
    // positionBusList.add(const LatLng(21.05911667, 105.8341333));
    // positionBusList.add(const LatLng(21.043650, 105.8360833));
    // positionBusList.add(const LatLng(21.041500, 105.836150));
    // positionBusList.add(const LatLng(21.03836667, 105.8396167));
    // positionBusList.add(const LatLng(21.03401667, 105.8348667));
    // positionBusList.add(const LatLng(21.02791667, 105.834350));
    // positionBusList.add(const LatLng(21.02791667, 105.834350));
    // positionBusList.add(const LatLng(21.030100, 105.8370833));
    // positionBusList.add(const LatLng(21.02591667, 105.8468333));
    // positionBusList.add(const LatLng(21.023950, 105.8568833));
    // positionBusList.add(const LatLng(21.030450, 105.8538333));
    // positionBusList.add(const LatLng(21.03084888, 105.8536041));

    for (int i = 0; i < positionBusList.length; i++) {
      _markers["location$i"] = Marker(
          markerId: MarkerId("location$i"),
          position: positionBusList[i],
          icon: positionBus ?? BitmapDescriptor.defaultMarker);
    }
  }
}
