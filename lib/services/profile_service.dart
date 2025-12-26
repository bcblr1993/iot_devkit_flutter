import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/profile_metadata.dart';
import 'package:logging/logging.dart';

class ProfileService {
  static final _logger = Logger('ProfileService');
  static const String _profilesKey = 'saved_profiles_list';
  static const String _profileDataPrefix = 'profile_data_';
  static const String _activeProfileKey = 'active_profile_id';

  // Singleton
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  /// Load all available profiles metadata
  Future<List<ProfileMetadata>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profilesKey);
    if (jsonString == null) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => ProfileMetadata.fromJson(e)).toList();
    } catch (e) {
      _logger.warning('Failed to load profile list', e);
      return [];
    }
  }

  /// Load specific profile configuration
  Future<Map<String, dynamic>?> loadProfileConfig(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_profileDataPrefix$id');
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _logger.warning('Failed to load profile data: $id', e);
      return null;
    }
  }

  /// Save or Update a profile
  /// If [id] is null, creates a new profile
  Future<ProfileMetadata> saveProfile(String name, Map<String, dynamic> config, {String? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    
    String profileId = id ?? const Uuid().v4();
    DateTime now = DateTime.now();

    // Update metadata list
    int index = profiles.indexWhere((p) => p.id == profileId);
    final newMeta = ProfileMetadata(id: profileId, name: name, lastModified: now);

    if (index != -1) {
      profiles[index] = newMeta;
    } else {
      profiles.add(newMeta);
    }
    
    // Save Data
    await prefs.setString('$_profileDataPrefix$profileId', jsonEncode(config));
    
    // Save List
    await prefs.setString(_profilesKey, jsonEncode(profiles.map((e) => e.toJson()).toList()));
    
    return newMeta;
  }

  /// Delete a profile
  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    
    profiles.removeWhere((p) => p.id == id);
    
    await prefs.setString(_profilesKey, jsonEncode(profiles.map((e) => e.toJson()).toList()));
    await prefs.remove('$_profileDataPrefix$id');
    
    // If deleted active profile, clear it
    if (prefs.getString(_activeProfileKey) == id) {
      await prefs.remove(_activeProfileKey);
    }
  }

  /// Get last active profile ID
  Future<String?> getLastActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  /// Set active profile ID
  Future<void> setActiveProfileId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeProfileKey);
    } else {
      await prefs.setString(_activeProfileKey, id);
    }
  }
}
