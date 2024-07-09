
import 'dart:ffi';

class BusPosition{
  final BusLocation current;
  final BusLocation nextPosition;
  final int near;
  final String time;
  final String distance;


  BusPosition(this.current, this.nextPosition, this.near, this.time, this.distance);
}

class BusLocation{
  final double lat;
  final double long;

  BusLocation(this.lat, this.long);
}