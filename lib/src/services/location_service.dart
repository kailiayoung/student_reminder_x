import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Request permissions (fine/coarse)
  static Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  // Returns current position or throws
  static Future<Position> getCurrentPosition({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: accuracy);
  }

  // Optional: Listen to position stream
  static Stream<Position> positionStream({LocationAccuracy accuracy = LocationAccuracy.best, int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter),
    );
  }
}