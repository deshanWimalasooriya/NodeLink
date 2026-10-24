import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm_map;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../models/node_user.dart';
import '../providers/node_link_provider.dart';
import '../services/adaptive_polling_service.dart';
import '../services/firebase_sync_service.dart';
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

  // OpenStreetMap Controller
  final osm_map.MapController _mapController = osm_map.MapController();

  // Static fallback location so the map instantly renders without waiting for GPS
  static const osm.LatLng _fallbackLocation = osm.LatLng(7.6166, 80.2000);

  // Multi-Stream Neighbor Tracking
  final Map<String, StreamSubscription<NodeUser?>> _neighborSubscriptions = {};
  final Map<String, NodeUser> _liveNeighbors = {};

  // State variables
  NodeUser? _selectedNode;
  bool _isPermissionDenied = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndFetchLocation();
  }

  /// Multi-Stream Neighbor Tracking:
  /// Extract the list of neighbor IDs from active_connections,
  /// create a listener for each ID (`users/<neighbor_id>`) to track live latitude, longitude, and profilePicUrl.
  /// Consolidate incoming streams and call setState() when a neighbor moves.
  void _syncNeighborStreams(List<NodeUser> connectedNodes) {
    final currentIds = connectedNodes.map((n) => n.id).toSet();

    // 1. Cancel and remove streams for removed neighbors
    final removedIds = _neighborSubscriptions.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in removedIds) {
      _neighborSubscriptions[id]?.cancel();
      _neighborSubscriptions.remove(id);
      _liveNeighbors.remove(id);
    }

    // 2. Add streams for new neighbors
    for (final node in connectedNodes) {
      if (!_liveNeighbors.containsKey(node.id)) {
        _liveNeighbors[node.id] = node;
      }
      if (!_neighborSubscriptions.containsKey(node.id)) {
        _neighborSubscriptions[node.id] = FirebaseSyncService.streamNeighborNode(node.id).listen((updatedNode) {
          if (updatedNode != null && mounted) {
            setState(() {
              _liveNeighbors[node.id] = updatedNode;
            });
          }
        });
      }
    }
  }

  /// Check location permissions and fetch device physical coordinates
  Future<void> _checkPermissionsAndFetchLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _isPermissionDenied = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _isLoadingLocation = false;
          });
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null && mounted) {
        final provider = context.read<NodeLinkProvider>();
        await provider.updateCurrentLocation(position.latitude, position.longitude);

        // Smoothly pan map from fallback position to actual GPS location
        _mapController.move(
          osm.LatLng(position.latitude, position.longitude),
          15.5,
        );
      }
    } catch (e) {
      debugPrint('Error getting device GPS location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Center OpenStreetMap on device live physical GPS
  Future<void> _centerOnUserRealLocation() async {
    final provider = context.read<NodeLinkProvider>();
    final pos = await provider.fetchRealGpsPosition();
    if (pos != null && mounted) {
      await provider.updateCurrentLocation(pos.latitude, pos.longitude);
      _mapController.move(osm.LatLng(pos.latitude, pos.longitude), 16.0);
    } else {
      final user = provider.currentUser;
      _mapController.move(osm.LatLng(user.latitude, user.longitude), 15.5);
    }
  }

  /// Helper to render avatar image from profilePicUrl (CachedNetworkImage), base64, or asset fallback
  Widget _buildAvatarImage(NodeUser user, {double iconSize = 24, Color? fallbackColor}) {
    final color = fallbackColor ?? const Color(0xFF00F0FF);
    final hasRemotePic = user.profilePicUrl != null && user.profilePicUrl!.startsWith('http');
    final hasBase64Pic = user.profilePicUrl != null && user.profilePicUrl!.startsWith('data:image');

    if (hasRemotePic) {
      return CachedNetworkImage(
        imageUrl: user.profilePicUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Image.asset(
          user.avatarPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.person_rounded,
            color: color,
            size: iconSize,
          ),
        ),
      );
    } else if (hasBase64Pic) {
      try {
        final rawBase64 = user.profilePicUrl!.split(',').last;
        final bytes = base64Decode(rawBase64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Image.asset(
          user.avatarPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.person_rounded,
            color: color,
            size: iconSize,
          ),
        );
      }
    } else if (user.avatarPath.isNotEmpty && !user.avatarPath.startsWith('http')) {
      return Image.asset(
        user.avatarPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.person_rounded,
          color: color,
          size: iconSize,
        ),
      );
    } else {
      return Icon(
        Icons.person_rounded,
        color: color,
        size: iconSize,
      );
    }
  }

  /// Marker Widget Design:
  /// Wrap cached_network_image profile pictures in a circular Container with glowing neon green or electric-cyan border.
  /// If no image exists, use a default fallback icon.
  Widget _buildUserAvatarMarker(NodeUser user, {bool isSelf = false, bool isSelected = false}) {
    final isOnline = user.status.toLowerCase() == 'online';
    final borderColor = isSelf
        ? const Color(0xFF00F0FF)
        : (isSelected
            ? const Color(0xFF00F0FF)
            : (isOnline ? AppTheme.neonGreen : const Color(0xFF00F0FF)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name / Status Badge at top of marker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF00F0FF).withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isSelected ? 8 : 4,
              ),
            ],
          ),
          child: Text(
            isSelf ? 'YOU' : user.name.split(' ').first,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isSelf || isSelected ? const Color(0xFF00F0FF) : Colors.white,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 3),

        // Circular Container with glowing Neon Green or Electric-Cyan border
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.deepNavy,
            border: Border.all(
              color: borderColor,
              width: isSelected ? 3.0 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: isSelected ? 0.7 : 0.5),
                blurRadius: isSelected ? 16 : 12,
                spreadRadius: isSelected ? 2 : 1,
              ),
            ],
          ),
          child: ClipOval(
            child: _buildAvatarImage(user, iconSize: 26, fallbackColor: borderColor),
          ),
        ),
      ],
    );
  }

  /// Build OSM Markers from incoming live consolidated neighbor stream
  List<osm_map.Marker> _buildMarkers(NodeUser currentUser, List<NodeUser> connectedNodes) {
    final List<osm_map.Marker> markers = [];

    // 1. Local User Node Marker
    markers.add(
      osm_map.Marker(
        point: osm.LatLng(currentUser.latitude, currentUser.longitude),
        width: 60,
        height: 74,
        alignment: Alignment.topCenter,
        child: _buildUserAvatarMarker(currentUser, isSelf: true),
      ),
    );

    // 2. Connected Neighbors from multi-stream tracking
    for (final node in connectedNodes) {
      final isSelected = _selectedNode?.id == node.id;
      markers.add(
        osm_map.Marker(
          point: osm.LatLng(node.latitude, node.longitude),
          width: 60,
          height: 74,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedNode = node);
              _mapController.move(osm.LatLng(node.latitude, node.longitude), 16.0);
            },
            child: _buildUserAvatarMarker(node, isSelf: false, isSelected: isSelected),
          ),
        ),
      );
    }

    return markers;
  }

  /// Mesh connection lines connecting active neighbors
  List<osm_map.Polyline> _buildPolylines(
      NodeUser currentUser, List<NodeUser> connectedNodes) {
    return connectedNodes.map((node) {
      return osm_map.Polyline(
        points: [
          osm.LatLng(currentUser.latitude, currentUser.longitude),
          osm.LatLng(node.latitude, node.longitude),
        ],
        strokeWidth: 3.0,
        color: const Color(0xFF00F0FF).withValues(alpha: 0.75),
        pattern: osm_map.StrokePattern.dashed(segments: const [12.0, 6.0]),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final sub in _neighborSubscriptions.values) {
      sub.cancel();
    }
    _neighborSubscriptions.clear();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final currentUser = provider.currentUser;
    final connectedNodes = provider.connectedNodes;
    final hasNeighbors = connectedNodes.isNotEmpty;

    // Consolidate live streams for all connected neighbors
    _syncNeighborStreams(connectedNodes);

    final activeNeighbors = _liveNeighbors.isNotEmpty
        ? _liveNeighbors.values.toList()
        : connectedNodes;

    final markers = _buildMarkers(currentUser, activeNeighbors);
    final polylines = _buildPolylines(currentUser, activeNeighbors);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.deepNavy,
      drawer: const SideMenuDrawer(),
      body: Column(
        children: [
          // Expanded wrapper ensures FlutterMap fills the screen without collapsing
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. FlutterMap with Free OpenStreetMap Cyber Dark Layer
                osm_map.FlutterMap(
                  mapController: _mapController,
                  options: const osm_map.MapOptions(
                    initialCenter: _fallbackLocation, // Static fallback LatLng(7.6166, 80.2000)
                    initialZoom: 14.5,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    // 100% Free OpenStreetMap with Cyber Dark Filter
                    osm_map.TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.nodelink',
                      tileBuilder: (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -0.65, 0.0, 0.0, 0.0, 170.0,
                            0.0, -0.65, 0.0, 0.0, 180.0,
                            0.0, 0.0, -0.60, 0.0, 200.0,
                            0.0, 0.0, 0.0, 1.0, 0.0,
                          ]),
                          child: tileWidget,
                        );
                      },
                    ),

                    // Cyber Cyan Mesh Polylines
                    osm_map.PolylineLayer(polylines: polylines),

                    // Rebuilt Live Dynamic Markers
                    osm_map.MarkerLayer(markers: markers),
                  ],
                ),

                // 2. Custom Cyber Top App Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: CyberAppBar(
                      titleText: 'NodeLink',
                      showBackButton: false,
                      leading: CyberCircleIconButton(
                        icon: Icons.menu_rounded,
                        onTap: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                      actions: [
                        CyberCircleIconButton(
                          icon: Icons.tune_rounded,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Map Compass Control (Reset Bearing to North) - Matching Cyber-Dark Aesthetic
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  right: 18,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.deepNavy.withValues(alpha: 0.8),
                          border: Border.all(
                            color: const Color(0xFF00F0FF),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              _mapController.rotate(0.0);
                            },
                            child: const Center(
                              child: Icon(
                                Icons.explore,
                                color: Color(0xFF00F0FF),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Fallback UI Overlay if Location Permissions Denied
                if (_isPermissionDenied) _buildPermissionDeniedOverlay(),

                // 5. Floating Re-Center GPS Button
                Positioned(
                  right: 18,
                  bottom: hasNeighbors ? 128 : 210,
                  child: FloatingActionButton.small(
                    heroTag: 'gps_center_btn',
                    backgroundColor: AppTheme.deepNavy,
                    foregroundColor: const Color(0xFF00F0FF),
                    elevation: 6,
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFF00F0FF), width: 1.5),
                    ),
                    onPressed: _isLoadingLocation ? null : _centerOnUserRealLocation,
                    tooltip: 'My Location',
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00F0FF),
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ),

                // 6. OpenStreetMap Attribution Badge
                Positioned(
                  left: 20,
                  bottom: hasNeighbors ? 96 : 196,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.deepNavy.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // 7. Floating Bottom Section Pinned to Bottom
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Adaptive Polling HUD
                      _buildAdaptivePollingHUD(provider),

                      const SizedBox(height: 12),

                      // Neighbor Tray or Empty State
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: hasNeighbors
                            ? _buildPopulatedBottomTray(activeNeighbors)
                            : _buildEmptyStateCard(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback UI Overlay when Location Permissions are Permanently Denied
  Widget _buildPermissionDeniedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: AppTheme.deepNavy.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppTheme.warningRed.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warningRed.withValues(alpha: 0.25),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.warningRed.withValues(alpha: 0.15),
                      border: Border.all(color: AppTheme.warningRed, width: 1.8),
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      color: AppTheme.warningRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Location Permission Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'NodeLink requires access to your physical location to track node telemetry and render connected neighbors on the live map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                        _checkPermissionsAndFetchLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F0FF),
                        foregroundColor: AppTheme.deepNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// EMPTY STATE CARD: Matching 1.jpeg exactly
  Widget _buildEmptyStateCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No Active Neighbors',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect to nearby nodes via QR code or 6-digit node ID to share live telemetry and build your mesh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ConnectionHubScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: AppTheme.deepNavy,
                    elevation: 8,
                    shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.45),
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

  /// POPULATED STATE: Horizontal Nodes Tray matching 2.jpg with circular add button at the end
  Widget _buildPopulatedBottomTray(List<NodeUser> nodes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.deepNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Render connected neighbors from 2.jpg
                ...nodes.map((node) {
                  final isSelected = _selectedNode?.id == node.id;
                  final isOnline = node.status.toLowerCase() == 'online';
                  final glowColor = isSelected
                      ? const Color(0xFF00F0FF)
                      : (isOnline ? AppTheme.neonGreen : const Color(0xFF00F0FF));

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedNode = node);
                      _mapController.move(
                        osm.LatLng(node.latitude, node.longitude),
                        16.0,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 22),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar with glowing border and badge (matching 2.jpg)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: glowColor,
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildAvatarImage(node, iconSize: 26, fallbackColor: glowColor),
                                ),
                              ),
                              // Status badge (Alex has green dot, Emma/Jessica/Liam have location pin badge in 2.jpg)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: glowColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.deepNavy,
                                      width: 1.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: glowColor.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: isOnline
                                        ? const SizedBox()
                                        : const Icon(
                                            Icons.location_on,
                                            size: 9,
                                            color: AppTheme.deepNavy,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          // Name and Status (matching 2.jpg)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                node.name.split(' ').first,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (isOnline)
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '• ',
                                      style: TextStyle(
                                        color: AppTheme.neonGreen,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Online',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.neonGreen,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 13,
                                      color: Color(0xFF6E85A8),
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8F9FB8),
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
                }),

                // Append Add Button at the very end of the horizontal sequence (Requirement 1)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ConnectionHubScreen()),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.deepNavy.withValues(alpha: 0.9),
                      border: Border.all(
                        color: const Color(0xFF00F0FF),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: Color(0xFF00F0FF),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
