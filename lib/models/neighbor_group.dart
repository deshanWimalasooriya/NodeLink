class NeighborGroup {
  final String id;
  final String name;
  final Map<String, bool> members; // nodeId -> true

  const NeighborGroup({
    required this.id,
    required this.name,
    this.members = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'members': members,
    };
  }

  factory NeighborGroup.fromJson(String id, Map<dynamic, dynamic> json) {
    final rawMembers = json['members'];
    final Map<String, bool> membersMap = {};
    if (rawMembers is Map) {
      rawMembers.forEach((k, v) {
        if (v == true) {
          membersMap[k.toString()] = true;
        }
      });
    }
    return NeighborGroup(
      id: id,
      name: json['name']?.toString() ?? 'Unnamed Group',
      members: membersMap,
    );
  }

  NeighborGroup copyWith({
    String? id,
    String? name,
    Map<String, bool>? members,
  }) {
    return NeighborGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }

  bool containsMember(String nodeId) {
    if (members[nodeId] == true) return true;
    final clean = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return members[clean] == true || members['node_$clean'] == true;
  }
}
