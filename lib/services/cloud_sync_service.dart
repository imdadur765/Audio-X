import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/models/playlist_model.dart';
import '../data/services/auth_service.dart';

/// Service for syncing user data (Favorites, Playlists) to Firebase Firestore.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Notifier that fires when sync happens - UI can listen to this
  static final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  /// Returns the user's document reference, or null if not logged in.
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final user = _authService.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  /// Check if user is logged in and can sync.
  bool get canSync => _authService.isLoggedIn;

  // ==================== FAVORITES ====================

  /// Upload current favorite song IDs to Firestore.
  Future<void> syncFavoritesToCloud(List<String> favoriteSongIds) async {
    if (!canSync) return;

    try {
      await _userDoc?.set({
        'favorites': {'songIds': favoriteSongIds, 'updatedAt': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
      debugPrint('Favorites synced to cloud: ${favoriteSongIds.length} songs');

      // Update local notifier so UI knows sync happened
      lastSyncNotifier.value = DateTime.now();
    } catch (e) {
      debugPrint('Error syncing favorites to cloud: $e');
    }
  }

  /// Download favorite song IDs from Firestore.
  Future<List<String>> getFavoritesFromCloud() async {
    if (!canSync) return [];

    try {
      final doc = await _userDoc?.get();
      if (doc?.exists == true) {
        final data = doc!.data();
        final favorites = data?['favorites'] as Map<String, dynamic>?;
        if (favorites != null) {
          return List<String>.from(favorites['songIds'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('Error getting favorites from cloud: $e');
    }
    return [];
  }

  // ==================== PLAYLISTS ====================

  /// Upload all custom playlists to Firestore.
  Future<void> syncPlaylistsToCloud(List<Playlist> playlists) async {
    if (!canSync) return;

    try {
      final batch = _firestore.batch();
      final playlistsRef = _userDoc?.collection('playlists');

      if (playlistsRef == null) return;

      // Delete existing playlists first (to handle deleted ones)
      final existingDocs = await playlistsRef.get();
      for (var doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      // Add current playlists
      for (var playlist in playlists) {
        final docRef = playlistsRef.doc(playlist.id);
        batch.set(docRef, {
          'id': playlist.id,
          'name': playlist.name,
          'songIds': playlist.songIds,
          'created': playlist.created.toIso8601String(),
          'iconEmoji': playlist.iconEmoji,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Playlists synced to cloud: ${playlists.length} playlists');
    } catch (e) {
      debugPrint('Error syncing playlists to cloud: $e');
    }
  }

  /// Download all custom playlists from Firestore.
  Future<List<Playlist>> getPlaylistsFromCloud() async {
    if (!canSync) return [];

    try {
      final playlistsRef = _userDoc?.collection('playlists');
      if (playlistsRef == null) return [];

      final snapshot = await playlistsRef.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Playlist(
          id: data['id'] as String,
          name: data['name'] as String,
          songIds: List<String>.from(data['songIds'] ?? []),
          created: DateTime.parse(data['created'] as String),
          isAuto: false,
          iconEmoji: data['iconEmoji'] as String? ?? '🎵',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting playlists from cloud: $e');
    }
    return [];
  }

  // ==================== MASTER SYNC ====================

  /// Called after login to sync all data from cloud to local.
  /// Returns true if sync was successful.
  Future<bool> syncOnLogin({
    required Future<void> Function(List<String>) onFavoritesDownloaded,
    required Future<void> Function(List<Playlist>) onPlaylistsDownloaded,
  }) async {
    if (!canSync) return false;

    try {
      debugPrint('Starting cloud sync on login...');

      // Download favorites
      final cloudFavorites = await getFavoritesFromCloud();
      if (cloudFavorites.isNotEmpty) {
        await onFavoritesDownloaded(cloudFavorites);
        debugPrint('Downloaded ${cloudFavorites.length} favorites from cloud');
      }

      // Download playlists
      final cloudPlaylists = await getPlaylistsFromCloud();
      if (cloudPlaylists.isNotEmpty) {
        await onPlaylistsDownloaded(cloudPlaylists);
        debugPrint('Downloaded ${cloudPlaylists.length} playlists from cloud');
      }

      debugPrint('Cloud sync completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error during cloud sync: $e');
      return false;
    }
  }

  /// Get last sync timestamp for display purposes.
  Future<DateTime?> getLastSyncTime() async {
    if (!canSync) return null;

    try {
      final doc = await _userDoc?.get();
      if (doc?.exists == true) {
        final favorites = doc!.data()?['favorites'] as Map<String, dynamic>?;
        final timestamp = favorites?['updatedAt'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
    }
    return null;
  }
}
