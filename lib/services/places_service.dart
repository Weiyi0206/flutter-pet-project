// import 'dart:convert';
import 'package:dio/dio.dart';

class PlaceLocation {
  final double lat;
  final double lng;

  PlaceLocation({required this.lat, required this.lng});

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      lat: json['lat'],
      lng: json['lng'],
    );
  }
}

class PlaceGeometry {
  final PlaceLocation location;

  PlaceGeometry({required this.location});

  factory PlaceGeometry.fromJson(Map<String, dynamic> json) {
    return PlaceGeometry(
      location: PlaceLocation.fromJson(json['location']),
    );
  }
}

class Place {
  final String id;
  final String name;
  final String? vicinity;
  final String? formattedAddress;
  final PlaceGeometry? geometry;

  Place({
    required this.id,
    required this.name,
    this.vicinity,
    this.formattedAddress,
    this.geometry,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['place_id'],
      name: json['name'],
      vicinity: json['vicinity'],
      formattedAddress: json['formatted_address'],
      geometry: json['geometry'] != null
          ? PlaceGeometry.fromJson(json['geometry'])
          : null,
    );
  }
}

class PlacesService {
  final Dio _dio = Dio();
  final String apiKey;

  PlacesService({required this.apiKey});

  Future<List<Place>> searchNearbyWithRadius(
    double lat,
    double lng,
    int radius, {
    String? type,
    String? keyword,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'location': '$lat,$lng',
        'radius': radius,
        'key': apiKey,
      };
      
      if (type != null) {
        queryParameters['type'] = type;
      }
      
      if (keyword != null) {
        queryParameters['keyword'] = keyword;
      }
      
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results.map((place) => Place.fromJson(place)).toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to search nearby places: $e');
    }
  }

  Future<List<Place>> searchByText(String query) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/textsearch/json',
        queryParameters: {
          'query': query,
          'key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results.map((place) => Place.fromJson(place)).toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to search places by text: $e');
    }
  }
} 