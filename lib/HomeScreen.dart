import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'location_error_widget.dart';

class QiblaCompass extends StatefulWidget {
  const QiblaCompass({Key? key}) : super(key: key);

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  final _locationStreamController =
      StreamController<LocationStatus>.broadcast();
  Position? _currentPosition;
  String? _locationName;

  get stream => _locationStreamController.stream;

  @override
  void initState() {
    _checkLocationStatus();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder(
        stream: stream,
        builder: (context, AsyncSnapshot<LocationStatus> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CupertinoActivityIndicator();
          }
          if (snapshot.data!.enabled == true) {
            switch (snapshot.data!.status) {
              case LocationPermission.always:
              case LocationPermission.whileInUse:
                return QiblahCompassWidget();

              case LocationPermission.denied:
                return LocationErrorWidget(
                  error: "Location service permission denied",
                  callback: _checkLocationStatus,
                );
              case LocationPermission.deniedForever:
                return LocationErrorWidget(
                  error: "Location service Denied Forever !",
                  callback: _checkLocationStatus,
                );
              // case GeolocationStatus.unknown:
              //   return LocationErrorWidget(
              //     error: "Unknown Location service error",
              //     callback: _checkLocationStatus,
              //   );
              default:
                return Container();
            }
          } else {
            return LocationErrorWidget(
              error: "Please enable Location service",
              callback: _checkLocationStatus,
            );
          }
        },
      ),
    );
  }

  Future<void> _checkLocationStatus() async {
    final locationStatus = await FlutterQiblah.checkLocationStatus();
    if (locationStatus.enabled &&
        locationStatus.status == LocationPermission.denied) {
      await FlutterQiblah.requestPermissions();
      final s = await FlutterQiblah.checkLocationStatus();
      _locationStreamController.sink.add(s);
    } else {
      _locationStreamController.sink.add(locationStatus);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _locationStreamController.close();
    FlutterQiblah().dispose();
  }
}

class QiblahCompassWidget extends StatefulWidget {
  QiblahCompassWidget({Key? key}) : super(key: key);

  @override
  State<QiblahCompassWidget> createState() => _QiblahCompassWidgetState();
}

class _QiblahCompassWidgetState extends State<QiblahCompassWidget> {
  Position? _currentPosition;
  String? _locationName;
  bool isRed = true;
  bool showArrow = false;
  // Define the _locationName variable

  void _getCurrentLocation() async {
    Position? newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _currentPosition = newPosition;
      });
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        setState(() {
          _locationName = "${placemark.locality}, ${placemark.country}";
        });
      }
    } catch (e) {
      print("Error while getting the location name: $e");
    }
  }

  @override
  void initState() {
    _getCurrentLocation();
    super.initState();
  }

  final _kaabaSvg = SvgPicture.asset('assets/4.svg');

  @override
  Widget build(BuildContext context) {
    var platformBrightness = Theme.of(context).brightness;
    return StreamBuilder(
      stream: FlutterQiblah.qiblahStream,
      builder: (_, AsyncSnapshot<QiblahDirection> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator();
        }

        final qiblahDirection = snapshot.data!;
        var angle = ((qiblahDirection.qiblah) * (pi / 180) * -1);

        // if (_angle < 5 && _angle > -5) print('IN RANGE');

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (isRed)
              Transform.rotate(
                angle: angle,
                child: SvgPicture.asset(
                  'assets/red.svg',
                ),
              )
            else if (showArrow)
              Transform.rotate(
                angle: angle,
                child: SvgPicture.asset(
                  'assets/arrow.svg',
                ),
              ),
            if (isRed)
              SvgPicture.asset(
                'assets/3.svg',
                width: 200,
                height: 200,
              ),
            Positioned(
              top: 550,
              child: Column(
                children: [
                  Text(
                    'Current location: \n $_locationName,',
                    style: const TextStyle(fontSize: 19),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 70,
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isRed = !isRed;
                        showArrow = !showArrow;
                      });
                    },
                    child: Text(
                      isRed ? 'Show Arrow' : 'Show Compass',
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                "Align both arrow head\nDo not put device close to metal object.\nCalibrate the compass every time you use it.",
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}
