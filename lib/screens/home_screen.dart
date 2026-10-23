import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/map_marker_helper.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../core/widgets/cyber_avatar.dart';
import '../models/node_user.dart';
import '../providers/node_link_provider.dart';
import '../services/adaptive_polling_service.dart';
import 'connection_hub_screen.dart';
import 'settings_screen.dart';
import 'side_menu_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;

  BitmapDescriptor? _youMarkerDescriptor;
  final Map<String, BitmapDescriptor> _neighborDescriptors = {};
  NodeUser? _selectedNode;
  bool _isLocationInitialized = false;

  // Dark Cyberpunk Map Style JSON for Google Maps matching Welcome Home.jpg
  static const String _cyberDarkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#0b132b"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0b132b"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
    {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#00f0ff"}, {"weight": 1.5}]},
    {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#00f0ff"}]},
    {"featureType": "poi", "stylers": [{"visibility": "off"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1c2541"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#00f0ff"}, {"weight": 0.8}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#1c2541"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#00f0ff"}, {"weight": 1.2}]},
    {"featureType": "transit", "stylers": [{"visibility": "off"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#050a18"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#39ff14"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _waitForInitialLocation();
  }

  Future<void> _waitForInitialLocation() async {
    final provider = context.read<NodeLinkProvider>();
    final pos = await provider.fetchRealGpsPosition();
    if (pos != null && mounted) {
      await provider.updateCurrentLocation(pos.latitude, pos.longitude);
    }
    if (mounted) {
      setState(() {
        _isLocationInitialized = true;
      });
    }
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final youMarker = await MapMarkerHelper.getYouMarker();
      if (mounted) {
        setState(() {
          _youMarkerDescriptor = youMarker;
        });
      }
    } catch (e) {
      debugPrint('Error loading custom marker: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _centerOnUserRealLocation();
  }

  /// Center and animate camera to actual device GPS location
  Future<void> _centerOnUserRealLocation() async {
    final provider = context.read<NodeLinkProvider>();
    final pos = await provider.fetchRealGpsPosition();
    if (pos != null && mounted) {
      await provider.updateCurrentLocation(pos.latitude, pos.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15.5),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(provider.currentUser.latitude, provider.currentUser.longitude),
          15.5,
        ),
      );
    }
  }

  Set<Marker> _buildMarkers(NodeUser currentUser, List<NodeUser> connectedNodes) {
    final Set<Marker> markers = {};

    // 1. "You" Marker (Matching Welcome Home.jpg)
    markers.add(
      Marker(
        markerId: const MarkerId('user_you'),
        position: LatLng(currentUser.latitude, currentUser.longitude),
        icon: _youMarkerDescriptor ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: const InfoWindow(title: 'You (Current Node)'),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 10,
      ),
    );

    // 2. Neighbor Markers (Matching Home.jpg)
    for (final node in connectedNodes) {
      // Lazy load neighbor marker descriptor if missing
      if (!_neighborDescriptors.containsKey(node.name)) {
        MapMarkerHelper.getNeighborMarker(
          name: node.name,
          avatarAsset: node.avatarPath,
          isOnline: node.status == 'Online' || node.status == 'Active',
        ).then((desc) {
          if (mounted) {
            setState(() {
              _neighborDescriptors[node.name] = desc;
            });
          }
        });
      }

      final markerDesc = _neighborDescriptors[node.name] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

      markers.add(
        Marker(
          markerId: MarkerId('neighbor_${node.id}'),
          position: LatLng(node.latitude, node.longitude),
          icon: markerDesc,
          infoWindow: InfoWindow(
            title: node.name,
            snippet: '${node.status} • Battery: ${node.batteryLevel}%',
          ),
          anchor: const Offset(0.5, 0.5),
          onTap: () {
            setState(() => _selectedNode = node);
          },
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(NodeUser currentUser, List<NodeUser> connectedNodes) {
    final Set<Polyline> polylines = {};
    for (final node in connectedNodes) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('link_${currentUser.id}_${node.id}'),
          points: [
            LatLng(currentUser.latitude, currentUser.longitude),
            LatLng(node.latitude, node.longitude),
          ],
          color: AppTheme.electricCyan.withValues(alpha: 0.75),
          width: 3,
          patterns: [PatternItem.dash(15), PatternItem.gap(8)],
        ),
      );
    }
    return polylines;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final currentUser = provider.currentUser;
    final connectedNodes = provider.connectedNodes;
    final hasNeighbors = connectedNodes.isNotEmpty;

    final userLocation = LatLng(currentUser.latitude, currentUser.longitude);
    final markers = _buildMarkers(currentUser, connectedNodes);
    final polylines = _buildPolylines(currentUser, connectedNodes);

    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavHeight = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.deepNavy,
      drawer: const SideMenuDrawer(),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-Screen GoogleMap Constrained in SizedBox with Loading State
            Positioned.fill(
              child: SizedBox.expand(
                child: !_isLocationInitialized
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.electricCyan,
                          strokeWidth: 3.0,
                        ),
                      )
                    : GoogleMap(
                        onMapCreated: _onMapCreated,
                        style: _cyberDarkMapStyle,
                        initialCameraPosition: CameraPosition(
                          target: userLocation,
                          zoom: 14.5,
                        ),
                        markers: markers,
                        polylines: polylines,
                        mapType: MapType.normal,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        rotateGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        padding: EdgeInsets.only(
                          top: statusBarHeight + 110,
                          bottom: hasNeighbors ? bottomNavHeight + 120 : bottomNavHeight + 220,
                        ),
                      ),
              ),
            ),

            // 2. Top Header Overlay Pinned Strictly to TOP
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top-Left: Translucent Hamburger Button
                          CyberCircleIconButton(
                            icon: Icons.menu_rounded,
                            iconSize: 24,
                            iconColor: AppTheme.textPrimary,
                            onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          ),

                          // Top-Center: "NodeLink" Typography
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, AppTheme.electricCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'NodeLink',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Top-Right: Settings Gear Icon
                          CyberCircleIconButton(
                            icon: Icons.settings_outlined,
                            iconSize: 22,
                            iconColor: AppTheme.textSecondary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Pill Badge below top title:
                      // Zero Neighbors: "👥 0 Active Neighbors" (Welcome Home.jpg)
                      // Populated: "👥 X Active Nodes" (Home.jpg)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.deepNavy.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.electricCyan.withValues(alpha: 0.4),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.electricCyan.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_alt_rounded,
                                  size: 16,
                                  color: AppTheme.electricCyan,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasNeighbors
                                      ? '${connectedNodes.length} Active Nodes'
                                      : '0 Active Neighbors',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.electricCyan,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      _buildAdaptivePollingHUD(provider),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Floating GPS Re-Center Target Button
            Positioned(
              right: 20,
              bottom: hasNeighbors ? 110 : 210,
              child: FloatingActionButton.small(
                heroTag: 'gps_recenter_fab',
                backgroundColor: AppTheme.deepNavy.withValues(alpha: 0.9),
                foregroundColor: AppTheme.electricCyan,
                elevation: 6,
                shape: const CircleBorder(
                  side: BorderSide(color: AppTheme.electricCyan, width: 1.5),
                ),
                onPressed: _centerOnUserRealLocation,
                tooltip: 'My Location',
                child: const Icon(Icons.my_location_rounded, size: 20),
              ),
            ),

            // 4. Floating Bottom Section Pinned Strictly to BOTTOM
            Positioned(
              left: 18,
              right: 18,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: hasNeighbors
                    ? _buildPopulatedBottomTray(connectedNodes)
                    : _buildEmptyStateWelcomeCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// EMPTY MAP STATE: Floating Bottom Card matching Welcome Home.jpg
  Widget _buildEmptyStateWelcomeCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.electricCyan.withValues(alpha: 0.35),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.electricCyan.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Welcome Title
              const Text(
                'Welcome to NodeLink!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'Your map is empty. Add a neighbor to start sharing live locations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Solid Electric-Cyan "+ ADD NEIGHBOR" Button (matching Welcome Home.jpg)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ConnectionHubScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricCyan,
                    foregroundColor: AppTheme.deepNavy,
                    elevation: 6,
                    shadowColor: AppTheme.electricCyan.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 22, color: AppTheme.deepNavy),
                      SizedBox(width: 6),
                      Text(
                        'ADD NEIGHBOR',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// POPULATED STATE: Horizontal Nodes Tray matching Home.jpg
  Widget _buildPopulatedBottomTray(List<NodeUser> nodes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.electricCyan.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: nodes.map((node) {
                      final isSelected = _selectedNode?.id == node.id;
                      final isOnline = node.status == 'Online';

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedNode = node);
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(node.latitude, node.longitude),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CyberAvatar.fromUser(
                                user: node,
                                size: 48,
                                showStatusBadge: true,
                                showGlow: isOnline || isSelected,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    node.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 11,
                                        color: isOnline
                                            ? AppTheme.neonGreen
                                            : AppTheme.electricCyan,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        node.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isOnline
                                              ? AppTheme.neonGreen
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConnectionHubScreen()),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                color: AppTheme.electricCyan,
                tooltip: 'Add Neighbor',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Adaptive Polling HUD
  Widget _buildAdaptivePollingHUD(NodeLinkProvider provider) {
    final motion = provider.motionState.displayName;
    final countdown = provider.secondsUntilNextPoll;
    final mins = countdown ~/ 60;
    final secs = countdown % 60;
    final countdownStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    final isBatteryLow = provider.batteryLevel < 15;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isBatteryLow
                ? AppTheme.warningRed.withValues(alpha: 0.15)
                : AppTheme.spaceIndigo.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBatteryLow
                  ? AppTheme.warningRed.withValues(alpha: 0.5)
                  : AppTheme.neonGreen.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.motionState == NodeMotionState.inVehicle
                    ? Icons.directions_car_rounded
                    : (provider.motionState == NodeMotionState.walking
                        ? Icons.directions_walk_rounded
                        : Icons.location_city_rounded),
                size: 14,
                color: isBatteryLow ? AppTheme.warningRed : AppTheme.neonGreen,
              ),
              const SizedBox(width: 6),
              Text(
                isBatteryLow
                    ? 'LOW BATTERY THROTTLE (20m)'
                    : '$motion • Next Poll: $countdownStr',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isBatteryLow ? AppTheme.warningRed : AppTheme.neonGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
