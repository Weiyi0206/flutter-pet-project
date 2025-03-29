import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:helloworld/services/places_service.dart';
import 'package:helloworld/services/helpdata_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // Replace with your actual Google API key
  static const String _googleApiKey = 'AIzaSyDo4nP04agGNTjiSkNuf8rjETujxOGVICI';

  late GoogleMapController _mapController;
  Position? currentPosition;
  List<Place> nearbyHospitals = [];
  bool _isLoading = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  late PlacesService _placesService;

  final HelpDataService _helpDataService = HelpDataService();

  // Replace hardcoded lists with these
  List<Map<String, String>> helplines = [];
  List<Map<String, String>> counselingCenters = [];
  bool _isLoadingData = true;

  static const LatLng _defaultLocation = LatLng(
    37.4219999,
    -122.0840575,
  ); // Silicon Valley as default

  @override
  void initState() {
    super.initState();
    _placesService = PlacesService(apiKey: _googleApiKey);

    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      // Load both data sets simultaneously
      final results = await Future.wait([
        _helpDataService.getHelplines(),
        _helpDataService.getCounselingCenters(),
      ]);

      setState(() {
        helplines = results[0];
        counselingCenters = results[1];
        _isLoadingData = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = position;
      });

      // Wait for the map controller to be fully initialized
      // and then move the camera
      if (mounted) {
        try {
          _mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 14.0,
              ),
            ),
          );
        } catch (e) {
          // Silently handle any animation errors
          print("Map animation error: $e");
        }
      }

      // Find nearby hospitals after getting current location
      await _findNearbyHospitals();
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _findNearbyHospitals() async {
    if (currentPosition == null) return;

    setState(() {
      _isLoading = true;
      nearbyHospitals = []; // Clear previous results
    });

    try {
      // Search for hospitals
      final hospitalResults = await _placesService.searchNearbyWithRadius(
        currentPosition!.latitude,
        currentPosition!.longitude,
        5000, // 5 km radius
        type: 'hospital',
      );

      // Search for clinics specifically
      final clinicResults = await _placesService.searchNearbyWithRadius(
        currentPosition!.latitude,
        currentPosition!.longitude,
        5000, // 5 km radius
        keyword: 'medical clinic', // Use keyword to specify medical clinics
      );

      // Combine the results
      final allMedicalFacilities = [...hospitalResults, ...clinicResults];

      // Filter out dental clinics
      final filteredFacilities =
          allMedicalFacilities.where((place) {
            final name = place.name.toLowerCase();
            return !name.contains('dental') &&
                !name.contains('dentist') &&
                !name.contains('orthodontic');
          }).toList();

      // Remove duplicates based on place ID
      final uniqueIds = <String>{};
      final uniquePlaces = <Place>[];

      for (final place in filteredFacilities) {
        if (uniqueIds.add(place.id)) {
          uniquePlaces.add(place);
        }
      }

      setState(() {
        nearbyHospitals = uniquePlaces;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error finding medical facilities: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  //seach location function
  // Future<void> _searchLocation(String query) async {
  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final places = await _placesService.searchByText(query);

  //     if (places.isNotEmpty) {
  //       final firstPlace = places.first;

  //       if (firstPlace.geometry != null) {
  //         final location = firstPlace.geometry!.location;

  //         setState(() {
  //           currentPosition = Position(
  //             latitude: location.lat,
  //             longitude: location.lng,
  //             timestamp: DateTime.now(),
  //             accuracy: 0,
  //             altitude: 0,
  //             heading: 0,
  //             speed: 0,
  //             speedAccuracy: 0,
  //             altitudeAccuracy: 0,
  //             headingAccuracy: 0,
  //           );
  //         });

  //         // Move map to new location and find nearby hospitals
  //         _mapController.animateCamera(
  //           CameraUpdate.newLatLng(LatLng(location.lat, location.lng)),
  //         );

  //         await _findNearbyHospitals();
  //       }
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _error = 'Location search failed: ${e.toString()}';
  //     });
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  void _showHospitalDetails(Place hospital) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Address: ${hospital.vicinity ?? hospital.formattedAddress ?? 'N/A'}',
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (hospital.geometry != null) {
                          _mapController.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(
                                hospital.geometry!.location.lat,
                                hospital.geometry!.location.lng,
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.location_on),
                      label: const Text('Show on Map'),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help & Support'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.phone), text: 'Helplines'),
              Tab(icon: Icon(Icons.psychology), text: 'Counseling'),
              Tab(icon: Icon(Icons.local_hospital), text: 'Hospitals'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHelplineList(),
            _buildCounselingList(),
            _buildHospitalsMap(),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineList() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (helplines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("No helplines available"),
            ElevatedButton(onPressed: _loadData, child: Text("Retry")),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: helplines.length,
      itemBuilder: (context, index) {
        final helpline = helplines[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  helpline['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                if (helpline['description'] != null &&
                    helpline['description']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      helpline['description'] ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),

                // Phone number
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16),
                    const SizedBox(width: 4),
                    Text(helpline['number'] ?? ''),
                  ],
                ),

                // Email
                if (helpline['email'] != null && helpline['email']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.email, size: 16),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap:
                              () => launchUrl(
                                Uri.parse('mailto:${helpline['email']}'),
                              ),
                          child: Text(
                            helpline['email'] ?? '',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Working hours
                if (helpline['working_hours'] != null &&
                    helpline['working_hours']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Text(helpline['working_hours'] ?? ''),
                      ],
                    ),
                  ),

                // Show website if available
                if (helpline['website'] != null &&
                    helpline['website']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: GestureDetector(
                      onTap: () => _launchUrl(helpline['website']!),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.language,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Visit Website',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Call button
                    IconButton(
                      icon: const Icon(Icons.phone),
                      color: Colors.green,
                      onPressed: () {
                        launchUrl(Uri.parse('tel:${helpline['number']}'));
                      },
                    ),

                    // Email button
                    if (helpline['email'] != null &&
                        helpline['email']!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.email),
                        color: Colors.blue,
                        onPressed: () {
                          launchUrl(Uri.parse('mailto:${helpline['email']}'));
                        },
                      ),

                    // WhatsApp button
                    if (helpline['whatsapp'] != null &&
                        helpline['whatsapp']!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.message),
                        color: Colors.green,
                        onPressed: () {
                          _openWhatsApp(helpline['whatsapp']!);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Direct WhatsApp opening method
  void _openWhatsApp(String number) async {
    try {
      // Clean the number - remove any non-numeric characters
      String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');

      // Make sure the number has a country code
      if (cleanNumber.startsWith('0')) {
        cleanNumber = '60${cleanNumber.substring(1)}';
      } else if (!cleanNumber.startsWith('60') && cleanNumber.length <= 10) {
        cleanNumber = '60$cleanNumber';
      }

      print('Opening WhatsApp with number: $cleanNumber');

      try {
        // Try direct external URL first
        bool launched = await launchUrl(
          Uri.parse('https://wa.me/$cleanNumber'),
          mode: LaunchMode.externalApplication,
        );
        print('External launch result: $launched');
        if (launched) return;
      } catch (e) {
        print('External launch failed: $e');
      }

      try {
        // Try platform default as fallback
        await launchUrl(
          Uri.parse('https://wa.me/$cleanNumber'),
          mode: LaunchMode.platformDefault,
        );
      } catch (e) {
        print('Platform default launch failed: $e');
        _showWhatsAppError();
      }
    } catch (e) {
      print('WhatsApp error: $e');
      _showWhatsAppError();
    }
  }

  void _showWhatsAppError() {
    print('Showing WhatsApp error message');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Failed to open WhatsApp. Try installing it or updating it.',
        ),
      ),
    );
  }

  // Direct URL launching method
  Future<void> _launchUrl(String urlString) async {
    try {
      // Process URL
      String processedUrl = urlString;
      if (!urlString.startsWith('http://') &&
          !urlString.startsWith('https://')) {
        processedUrl = 'https://$urlString';
      }

      print('Opening URL: $processedUrl');

      try {
        // Try direct external URL first
        bool launched = await launchUrl(
          Uri.parse(processedUrl),
          mode: LaunchMode.externalApplication,
        );
        print('External URL launch result: $launched');
        if (launched) return;
      } catch (e) {
        print('External URL launch failed: $e');
      }

      try {
        // Try platform default as fallback
        await launchUrl(
          Uri.parse(processedUrl),
          mode: LaunchMode.platformDefault,
        );
      } catch (e) {
        print('Platform default URL launch failed: $e');
        _showUrlError(processedUrl);
      }
    } catch (e) {
      print('URL error: $e');
      _showUrlError(urlString);
    }
  }

  void _showUrlError(String url) {
    print('Showing URL error message for: $url');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to open $url. Check your browser or internet connection.',
        ),
      ),
    );
  }

  Widget _buildCounselingList() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (counselingCenters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("No counseling centers available"),
            ElevatedButton(onPressed: _loadData, child: Text("Retry")),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: counselingCenters.length,
      itemBuilder: (context, index) {
        final center = counselingCenters[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  center['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                if (center['description'] != null &&
                    center['description']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      center['description'] ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),

                // Address
                if (center['address'] != null && center['address']!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Address: ${center['address'] ?? ''}'),
                      ),
                    ],
                  ),

                const SizedBox(height: 4),

                // Phone number
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16),
                    const SizedBox(width: 4),
                    Text('Phone: ${center['phone'] ?? ''}'),
                  ],
                ),

                // Email
                if (center['email'] != null && center['email']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.email, size: 16),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap:
                              () => launchUrl(
                                Uri.parse('mailto:${center['email']}'),
                              ),
                          child: Text(
                            center['email'] ?? '',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Show website if available
                if (center['website'] != null && center['website']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: GestureDetector(
                      onTap: () => _launchUrl(center['website']!),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.language,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Visit Website',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Call button
                    IconButton(
                      icon: const Icon(Icons.phone),
                      color: Colors.green,
                      onPressed: () {
                        launchUrl(Uri.parse('tel:${center['phone']}'));
                      },
                    ),

                    // Email button
                    if (center['email'] != null && center['email']!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.email),
                        color: Colors.blue,
                        onPressed: () {
                          launchUrl(Uri.parse('mailto:${center['email']}'));
                        },
                      ),

                    // WhatsApp button
                    if (center['whatsapp'] != null &&
                        center['whatsapp']!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.message),
                        color: Colors.green,
                        onPressed: () {
                          _openWhatsApp(center['whatsapp']!);
                        },
                      ),

                    // Map button
                    IconButton(
                      icon: const Icon(Icons.map),
                      color: Colors.blue,
                      onPressed: () {
                        _openInMaps(
                          center['name'] ?? '',
                          center['address'] ?? '',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add helper method for opening address in maps
  void _openInMaps(String name, String address) async {
    try {
      // Try to search by name first
      final encodedName = Uri.encodeComponent(name);
      final mapUrl =
          'https://www.google.com/maps/search/?api=1&query=$encodedName';

      if (await canLaunchUrl(Uri.parse(mapUrl))) {
        await launchUrl(Uri.parse(mapUrl));
      } else {
        // Fallback to address if name doesn't work
        final encodedAddress = Uri.encodeComponent(address);
        final addressUrl =
            'https://www.google.com/maps/search/?api=1&query=$encodedAddress';

        if (await canLaunchUrl(Uri.parse(addressUrl))) {
          await launchUrl(Uri.parse(addressUrl));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
        }
      }
    } catch (e) {
      print('Error opening maps: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildHospitalsMap() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  currentPosition != null
                      ? LatLng(
                        currentPosition!.latitude,
                        currentPosition!.longitude,
                      )
                      : _defaultLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            compassEnabled: true,
            markers: {
              // Current location marker
              if (currentPosition != null)
                Marker(
                  markerId: const MarkerId('current_location'),
                  position: LatLng(
                    currentPosition!.latitude,
                    currentPosition!.longitude,
                  ),
                  icon: BitmapDescriptor.defaultMarker,
                ),

              // Hospital markers
              ...nearbyHospitals
                  .map((hospital) {
                    if (hospital.geometry != null) {
                      return Marker(
                        markerId: MarkerId(hospital.id),
                        position: LatLng(
                          hospital.geometry!.location.lat,
                          hospital.geometry!.location.lng,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                        onTap: () => _showHospitalDetails(hospital),
                      );
                    }
                    return const Marker(markerId: MarkerId(''));
                  })
                  .where((marker) => marker.markerId.value.isNotEmpty)
                  .toSet(),
            },
          ),
        ),
        if (nearbyHospitals.isNotEmpty)
          Container(
            height: 120,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: nearbyHospitals.length,
              itemBuilder: (context, index) {
                final hospital = nearbyHospitals[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          hospital.vicinity ??
                              hospital.formattedAddress ??
                              'N/A',
                          overflow: TextOverflow.ellipsis,
                        ),
                        TextButton.icon(
                          onPressed: () => _showHospitalDetails(hospital),
                          icon: const Icon(Icons.info),
                          label: const Text('Details'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
