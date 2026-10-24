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
import '../core/widgets/map_theme_dialog.dart';
import '../models/node_user.dart';
import '../models/neighbor_group.dart';
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
  String? _selectedGroupId; // Null represents 'All'
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
        width: iconSize * 2,
        height: iconSize * 2,
        placeholder: (context, url) => Container(
          color: AppTheme.spaceIndigo,
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildAssetOrFallback(user, iconSize, color),
      );
    }

    if (hasBase64Pic) {
      try {
        final base64String = user.profilePicUrl!.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: iconSize * 2,
          height: iconSize * 2,
          errorBuilder: (context, error, stackTrace) => _buildAssetOrFallback(user, iconSize, color),
        );
      } catch (_) {
        return _buildAssetOrFallback(user, iconSize, color);
      }
    }

    return _buildAssetOrFallback(user, iconSize, color);
  }

  Widget _buildAssetOrFallback(NodeUser user, double iconSize, Color color) {
    if (user.avatarPath.isNotEmpty &&
        (user.avatarPath.endsWith('.jpg') ||
            user.avatarPath.endsWith('.jpeg') ||
            user.avatarPath.endsWith('.png'))) {
      return Image.asset(
        user.avatarPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(user, color, iconSize),
      );
    }
    return _buildInitialsFallback(user, color, iconSize);
  }

  Widget _buildInitialsFallback(NodeUser user, Color color, double iconSize) {
    final initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'NL';

    return Container(
      color: AppTheme.spaceIndigo,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: iconSize * 0.75,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Custom Circular Avatar Marker with glowing border and dynamic name label
  Widget _buildUserAvatarMarker(
    NodeUser user, {
    required bool isSelf,
    bool isSelected = false,
    bool isLight = false,
  }) {
    final borderColor = isSelf
        ? const Color(0xFF00F0FF)
        : (isSelected
            ? AppTheme.neonGreen
            : (user.status.toLowerCase() == 'online'
                ? AppTheme.neonGreen
                : const Color(0xFF00F0FF)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name / Status Badge at top of marker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isLight
                ? (isSelf ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.95))
                : AppTheme.deepNavy.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLight && !isSelf ? const Color(0xFFCBD5E1) : borderColor,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF00F0FF).withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: isLight ? 0.15 : 0.4),
                blurRadius: isSelected ? 8 : 4,
              ),
            ],
          ),
          child: Text(
            isSelf ? 'You' : user.name.split(' ').first,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isLight
                  ? (isSelf ? Colors.white : const Color(0xFF0F172A))
                  : (isSelf || isSelected ? const Color(0xFF00F0FF) : Colors.white),
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
            color: isLight ? Colors.white : AppTheme.deepNavy,
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
  List<osm_map.Marker> _buildMarkers(
    NodeUser currentUser,
    List<NodeUser> connectedNodes, {
    bool isLight = false,
  }) {
    final List<osm_map.Marker> markers = [];

    // 1. Local User Node Marker
    markers.add(
      osm_map.Marker(
        point: osm.LatLng(currentUser.latitude, currentUser.longitude),
        width: 60,
        height: 74,
        alignment: Alignment.topCenter,
        child: _buildUserAvatarMarker(currentUser, isSelf: true, isLight: isLight),
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
            child: _buildUserAvatarMarker(
              node,
              isSelf: false,
              isSelected: isSelected,
              isLight: isLight,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  /// Mesh connection lines connecting active neighbors
  List<osm_map.Polyline> _buildPolylines(
    NodeUser currentUser,
    List<NodeUser> connectedNodes,
  ) {
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

  Widget _buildGroupFilterChip({
    required String label,
    required bool isSelected,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isLight
              ? (isSelected ? AppTheme.electricCyan : Colors.white.withValues(alpha: 0.9))
              : (isSelected
                  ? AppTheme.electricCyan.withValues(alpha: 0.28)
                  : AppTheme.deepNavy.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.electricCyan
                : (isLight
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF00F0FF).withValues(alpha: 0.25)),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.electricCyan.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.25),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLight ? const Color(0xFF0F172A) : AppTheme.electricCyan,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isLight
                    ? (isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155))
                    : (isSelected ? const Color(0xFF00F0FF) : AppTheme.textSecondary),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final currentUser = provider.currentUser;
    final connectedNodes = provider.connectedNodes;
    final groups = provider.groups;

    // Consolidate live streams for all connected neighbors
    _syncNeighborStreams(connectedNodes);

    final activeNeighbors = _liveNeighbors.isNotEmpty
        ? _liveNeighbors.values.toList()
        : connectedNodes;

    // Filter neighbors by selected group if active
    List<NodeUser> displayNeighbors = activeNeighbors;
    if (_selectedGroupId != null) {
      final selectedGroup = groups.firstWhere(
        (g) => g.id == _selectedGroupId,
        orElse: () => NeighborGroup(id: '', name: '', members: {}),
      );
      displayNeighbors = activeNeighbors
          .where((node) => selectedGroup.containsMember(node.id))
          .toList();
    }

    final hasNeighbors = displayNeighbors.isNotEmpty;

    final markers = _buildMarkers(currentUser, displayNeighbors, isLight: isLight);
    final polylines = _buildPolylines(currentUser, displayNeighbors);

    // Resolve Map Tile Layer URL & Attribution based on Map Theme preference
    final mapTheme = provider.mapTheme;
    String tileUrl;
    String attributionText;

    switch (mapTheme) {
      case AppMapTheme.cartoLight:
        tileUrl = 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
        attributionText = '© CARTO, © OpenStreetMap';
        break;
      case AppMapTheme.darkMatter:
        tileUrl = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
        attributionText = '© CARTO, © OpenStreetMap';
        break;
      case AppMapTheme.satellite:
        tileUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
        attributionText = '© Esri, Maxar';
        break;
      case AppMapTheme.street:
        tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
        attributionText = '© OpenStreetMap contributors';
        break;
      case AppMapTheme.auto:
        if (isLight) {
          tileUrl = 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
          attributionText = '© CARTO, © OpenStreetMap';
        } else {
          tileUrl = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
          attributionText = '© CARTO, © OpenStreetMap';
        }
        break;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isLight ? const Color(0xFFF1F5F9) : AppTheme.deepNavy,
      drawer: const SideMenuDrawer(),
      body: Column(
        children: [
          // Expanded wrapper ensures FlutterMap fills the screen without collapsing
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. FlutterMap with Dynamic Map Theming
                osm_map.FlutterMap(
                  mapController: _mapController,
                  options: const osm_map.MapOptions(
                    initialCenter: _fallbackLocation, // Static fallback LatLng(7.6166, 80.2000)
                    initialZoom: 14.5,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    // Dynamic Tile Layer (Carto Light, Dark Matter, Satellite, Street)
                    osm_map.TileLayer(
                      key: ValueKey(tileUrl),
                      urlTemplate: tileUrl,
                      userAgentPackageName: 'com.example.nodelink',
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

                // 3. Group Filter Horizontal Chips Overlay (Requirement 3)
                if (groups.isNotEmpty || connectedNodes.isNotEmpty)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 58,
                    left: 16,
                    right: 72,
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildGroupFilterChip(
                            label: 'All (${activeNeighbors.length})',
                            isSelected: _selectedGroupId == null,
                            isLight: isLight,
                            onTap: () => setState(() => _selectedGroupId = null),
                          ),
                          ...groups.map((group) {
                            final count = activeNeighbors
                                .where((n) => group.containsMember(n.id))
                                .length;
                            final isSelected = _selectedGroupId == group.id;
                            return _buildGroupFilterChip(
                              label: '${group.name} ($count)',
                              isSelected: isSelected,
                              isLight: isLight,
                              onTap: () => setState(() {
                                _selectedGroupId = isSelected ? null : group.id;
                              }),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                // 4. Map Compass Control (Reset Bearing to North)
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
                          color: isLight
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppTheme.deepNavy.withValues(alpha: 0.8),
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

                // 5. Map Theme Switcher Button (Directly below compass rose - Requirement 4)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 124,
                  right: 18,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLight
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppTheme.deepNavy.withValues(alpha: 0.8),
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
                              MapThemeDialog.show(context);
                            },
                            child: const Center(
                              child: Icon(
                                Icons.layers_rounded,
                                color: Color(0xFF00F0FF),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 6. Fallback UI Overlay if Location Permissions Denied
                if (_isPermissionDenied) _buildPermissionDeniedOverlay(isLight),

                // 7. Floating Re-Center GPS Button
                Positioned(
                  right: 18,
                  bottom: hasNeighbors ? 128 : 210,
                  child: FloatingActionButton.small(
                    heroTag: 'gps_center_btn',
                    backgroundColor: isLight ? Colors.white : AppTheme.deepNavy,
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

                // 8. Map Attribution Badge
                Positioned(
                  left: 20,
                  bottom: hasNeighbors ? 96 : 196,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.88)
                          : AppTheme.deepNavy.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLight
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF00F0FF).withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      attributionText,
                      style: TextStyle(
                        fontSize: 9,
                        color: isLight ? const Color(0xFF64748B) : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // 9. Floating Bottom Section Pinned to Bottom
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Adaptive Polling HUD
                      _buildAdaptivePollingHUD(provider, isLight),

                      const SizedBox(height: 12),

                      // Neighbor Tray or Empty State
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: hasNeighbors
                            ? _buildPopulatedBottomTray(displayNeighbors, isLight)
                            : _buildEmptyStateCard(isLight),
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
  Widget _buildPermissionDeniedOverlay(bool isLight) {
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
                color: isLight
                    ? Colors.white.withValues(alpha: 0.95)
                    : AppTheme.deepNavy.withValues(alpha: 0.92),
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
                  Text(
                    'Location Permission Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isLight ? const Color(0xFF0F172A) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'NodeLink requires access to your physical location to track node telemetry and render connected neighbors on the live map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLight ? const Color(0xFF64748B) : AppTheme.textSecondary,
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

  /// EMPTY STATE CARD: Adapts to Light Mode (matching Home.jpg) and Dark Mode (matching 1.jpeg)
  Widget _buildEmptyStateCard(bool isLight) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            color: isLight
                ? const Color(0xFFE2F0FD).withValues(alpha: 0.94)
                : AppTheme.deepNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLight
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFF00F0FF).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isLight
                    ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLight ? 'Welcome to NodeLink!' : 'No Active Neighbors',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLight
                    ? 'Your map is empty. Add a neighbor to start sharing live locations.'
                    : 'Connect to nearby nodes via QR code or 16-character node ID to share live telemetry and build your mesh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: isLight ? const Color(0xFF334155) : AppTheme.textSecondary,
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
  Widget _buildPopulatedBottomTray(List<NodeUser> nodes, bool isLight) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isLight
                ? Colors.white.withValues(alpha: 0.94)
                : AppTheme.deepNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF00F0FF).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.5),
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
                          // Avatar with glowing border and badge
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
                              // Status badge
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
                                      color: isLight ? Colors.white : AppTheme.deepNavy,
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
                          // Name and Status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                node.name.split(' ').first,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 13,
                                      color: isLight ? const Color(0xFF64748B) : const Color(0xFF6E85A8),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isLight ? const Color(0xFF64748B) : const Color(0xFF8F9FB8),
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

                // Append Add Button at the very end of the horizontal sequence
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
                      color: isLight
                          ? const Color(0xFFF1F5F9)
                          : AppTheme.deepNavy.withValues(alpha: 0.9),
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
  Widget _buildAdaptivePollingHUD(NodeLinkProvider provider, bool isLight) {
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
            color: isLight
                ? Colors.white.withValues(alpha: 0.92)
                : (isBatteryLow
                    ? AppTheme.warningRed.withValues(alpha: 0.15)
                    : AppTheme.spaceIndigo.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBatteryLow
                  ? AppTheme.warningRed.withValues(alpha: 0.5)
                  : (isLight
                      ? const Color(0xFFCBD5E1)
                      : AppTheme.neonGreen.withValues(alpha: 0.3)),
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
                color: isBatteryLow
                    ? AppTheme.warningRed
                    : (isLight ? const Color(0xFF0F766E) : AppTheme.neonGreen),
              ),
              const SizedBox(width: 6),
              Text(
                isBatteryLow
                    ? 'LOW BATTERY THROTTLE (20m)'
                    : '$motion • Next Poll: $countdownStr',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isBatteryLow
                      ? AppTheme.warningRed
                      : (isLight ? const Color(0xFF0F766E) : AppTheme.neonGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
