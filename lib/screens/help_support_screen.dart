import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:helloworld/services/places_service.dart';
import 'package:helloworld/services/helpdata_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: Colors.purple.shade50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_hospital,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hospital.name,
                        style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Address: ${hospital.vicinity ?? hospital.formattedAddress ?? 'N/A'}',
                          style: GoogleFonts.fredoka(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      label: Text('Show on Map', style: GoogleFonts.fredoka()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade100,
                        foregroundColor: Colors.purple.shade800,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
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
          title: Text(
            'Help & Support',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 238, 210, 243),
          bottom: TabBar(
            labelStyle: GoogleFonts.fredoka(),
            indicatorColor: Colors.purple.shade800,
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    if (helplines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No helplines available",
              style: GoogleFonts.fredoka(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.purple.shade800,
              ),
              child: Text("Retry", style: GoogleFonts.fredoka()),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.purple.shade50.withOpacity(0.3),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: helplines.length,
        itemBuilder: (context, index) {
          final helpline = helplines[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.support_agent,
                          color: Colors.purple.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          helpline['name'] ?? '',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  if (helpline['description'] != null &&
                      helpline['description']!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Text(
                        helpline['description'] ?? '',
                        style: GoogleFonts.fredoka(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Contact Information section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Information',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Phone number
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              helpline['number'] ?? '',
                              style: GoogleFonts.fredoka(),
                            ),
                          ],
                        ),

                        // Email
                        if (helpline['email'] != null &&
                            helpline['email']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap:
                                      () => launchUrl(
                                        Uri.parse(
                                          'mailto:${helpline['email']}',
                                        ),
                                      ),
                                  child: Text(
                                    helpline['email'] ?? '',
                                    style: GoogleFonts.fredoka(
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
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  helpline['working_hours'] ?? '',
                                  style: GoogleFonts.fredoka(),
                                ),
                              ],
                            ),
                          ),

                        // Show website if available
                        if (helpline['website'] != null &&
                            helpline['website']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: GestureDetector(
                              onTap: () => _launchUrl(helpline['website']!),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.language,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Visit Website',
                                    style: GoogleFonts.fredoka(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Call button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.phone, size: 16),
                        label: Text(
                          'Call',
                          style: GoogleFonts.fredoka(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          launchUrl(Uri.parse('tel:${helpline['number']}'));
                        },
                      ),

                      const SizedBox(width: 4),

                      // Email button
                      if (helpline['email'] != null &&
                          helpline['email']!.isNotEmpty)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.email, size: 16),
                          label: Text(
                            'Email',
                            style: GoogleFonts.fredoka(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            launchUrl(Uri.parse('mailto:${helpline['email']}'));
                          },
                        ),

                      const SizedBox(width: 4),

                      // WhatsApp button back on the same line
                      if (helpline['whatsapp'] != null &&
                          helpline['whatsapp']!.isNotEmpty)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.message, size: 16),
                          label: Text(
                            'Whatsapp',
                            style: GoogleFonts.fredoka(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                            foregroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
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
      ),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    if (counselingCenters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No counseling centers available",
              style: GoogleFonts.fredoka(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.purple.shade800,
              ),
              child: Text("Retry", style: GoogleFonts.fredoka()),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.purple.shade50.withOpacity(0.3),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: counselingCenters.length,
        itemBuilder: (context, index) {
          final center = counselingCenters[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology,
                          color: Colors.purple.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          center['name'] ?? '',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  if (center['description'] != null &&
                      center['description']!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Text(
                        center['description'] ?? '',
                        style: GoogleFonts.fredoka(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Contact Information section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Information',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Address
                        if (center['address'] != null &&
                            center['address']!.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Address: ${center['address'] ?? ''}',
                                  style: GoogleFonts.fredoka(),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // Phone number
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              'Phone: ${center['phone'] ?? ''}',
                              style: GoogleFonts.fredoka(),
                            ),
                          ],
                        ),

                        // Email
                        if (center['email'] != null &&
                            center['email']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap:
                                      () => launchUrl(
                                        Uri.parse('mailto:${center['email']}'),
                                      ),
                                  child: Text(
                                    center['email'] ?? '',
                                    style: GoogleFonts.fredoka(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Show website if available
                        if (center['website'] != null &&
                            center['website']!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: GestureDetector(
                              onTap: () => _launchUrl(center['website']!),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.language,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Visit Website',
                                    style: GoogleFonts.fredoka(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Call button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text(
                          'Call',
                          style: GoogleFonts.fredoka(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          launchUrl(Uri.parse('tel:${center['phone']}'));
                        },
                      ),

                      const SizedBox(width: 8),

                      // Email button
                      if (center['email'] != null &&
                          center['email']!.isNotEmpty)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.email, size: 18),
                          label: Text(
                            'Email',
                            style: GoogleFonts.fredoka(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            launchUrl(Uri.parse('mailto:${center['email']}'));
                          },
                        ),

                      const SizedBox(width: 8),

                      // Map button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map, size: 18),
                        label: Text(
                          'Map',
                          style: GoogleFonts.fredoka(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
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
      ),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: GoogleFonts.fredoka(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.purple.shade800,
              ),
              child: Text("Retry", style: GoogleFonts.fredoka()),
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
            height: 150,
            color: Colors.purple.shade100,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: nearbyHospitals.length,
              itemBuilder: (context, index) {
                final hospital = nearbyHospitals[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_hospital,
                              color: Colors.red.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hospital.name,
                                style: GoogleFonts.fredoka(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hospital.vicinity ??
                              hospital.formattedAddress ??
                              'N/A',
                          style: GoogleFonts.fredoka(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showHospitalDetails(hospital),
                              icon: const Icon(Icons.info_outline, size: 14),
                              label: Text(
                                'Details',
                                style: GoogleFonts.fredoka(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  226,
                                  172,
                                  235,
                                ),
                                foregroundColor: const Color.fromARGB(
                                  255,
                                  42,
                                  20,
                                  68,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
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
