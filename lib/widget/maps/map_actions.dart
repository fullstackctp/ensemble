import 'package:ensemble/widget/maps/maps_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// expose actions
mixin MapActions on MapsActionableState {
  /// zoom to fit all markers. If location is enabled and
  /// includeLocationInAutoZoom is true, then also fit the location in the bound.
  void zoomToFit() {
    List<LatLng> points = [];

    // add user location
    Position? currentLocation = getCurrentLocation();
    if (currentLocation != null &&
        widget.controller.includeCurrentLocationInAutoZoom) {
      points.add(LatLng(currentLocation.latitude, currentLocation.longitude));
    }

    for (var payload in getMarkerPayloads()) {
      points.add(payload.latLng);
    }

    zoom(points);
  }

  void moveCamera(LatLng target, {int? zoom}) {
    getMapController().then((controller) => CameraUpdate.newCameraPosition(
        zoom != null
            ? CameraPosition(target: target, zoom: zoom.toDouble())
            : CameraPosition(target: target)));
  }
}
