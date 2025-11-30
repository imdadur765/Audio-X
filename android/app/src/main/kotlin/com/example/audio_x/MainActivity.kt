package com.example.audio_x

import android.content.ComponentName
import android.os.Bundle
import androidx.media3.common.MediaItem
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.audio_x/audio"
    private var mediaController: MediaController? = null
    private var controllerFuture: ListenableFuture<MediaController>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        val sessionToken = SessionToken(this, ComponentName(this, AudioService::class.java))
        controllerFuture = MediaController.Builder(this, sessionToken).buildAsync()
        controllerFuture?.addListener(
            {
                mediaController = controllerFuture?.get()
            },
            MoreExecutors.directExecutor()
        )
    }

    override fun onStop() {
        controllerFuture?.let {
            MediaController.releaseFuture(it)
        }
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val controller = mediaController
            if (controller == null) {
                result.error("NO_CONTROLLER", "MediaController not ready", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "play" -> {
                    controller.play()
                    result.success(null)
                }
                "pause" -> {
                    controller.pause()
                    result.success(null)
                }
                "setUri" -> {
                    val uri = call.argument<String>("uri")
                    if (uri != null) {
                        val mediaItem = MediaItem.fromUri(uri)
                        controller.setMediaItem(mediaItem)
                        controller.prepare()
                        controller.play()
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "URI is null", null)
                    }
                }
                "setPlaylist" -> {
                    val songs = call.argument<List<Map<String, Any>>>("songs")
                    val initialIndex = call.argument<Int>("initialIndex") ?: 0
                    if (songs != null) {
                        val mediaItems = songs.map { song ->
                            val uri = song["uri"] as? String ?: ""
                            val title = song["title"] as? String ?: "Unknown Title"
                            val artist = song["artist"] as? String ?: "Unknown Artist"
                            val artworkUri = song["artworkUri"] as? String

                            val metadata = androidx.media3.common.MediaMetadata.Builder()
                                .setTitle(title)
                                .setArtist(artist)
                                .setArtworkUri(if (artworkUri != null) android.net.Uri.parse(artworkUri) else null)
                                .build()

                            MediaItem.Builder()
                                .setUri(uri)
                                .setMediaMetadata(metadata)
                                .build()
                        }
                        controller.setMediaItems(mediaItems, initialIndex, 0)
                        controller.prepare()
                        controller.play()
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Songs list is null", null)
                    }
                }
                "getSongs" -> {
                    val songs = getSongs()
                    result.success(songs)
                }
                "getAlbumArt" -> {
                    val albumId = call.argument<String>("albumId")
                    if (albumId != null) {
                        val bytes = getAlbumArt(albumId)
                        result.success(bytes)
                    } else {
                        result.error("INVALID_ARGUMENT", "Album ID is null", null)
                    }
                }
                "seekTo" -> {
                    val positionArg = call.argument<Any>("position")
                    val position = when (positionArg) {
                        is Int -> positionArg.toLong()
                        is Long -> positionArg
                        else -> null
                    }
                    if (position != null) {
                        android.util.Log.d("AudioX", "Seeking to position: $position ms")
                        controller.seekTo(position)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Position is null or invalid type", null)
                    }
                }
                "seekToNext" -> {
                    if (controller.hasNextMediaItem()) {
                        controller.seekToNextMediaItem()
                    }
                    result.success(null)
                }
                "seekToPrevious" -> {
                    if (controller.hasPreviousMediaItem()) {
                        controller.seekToPreviousMediaItem()
                    }
                    result.success(null)
                }
                "getPosition" -> {
                    val position = controller.currentPosition
                    android.util.Log.d("AudioX", "Native getPosition: $position ms")
                    result.success(position)
                }
                "setShuffleMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    controller.shuffleModeEnabled = enabled
                    result.success(null)
                }
                "setRepeatMode" -> {
                    // 0: OFF, 1: ONE, 2: ALL
                    val mode = call.argument<Int>("mode") ?: 0
                    controller.repeatMode = when(mode) {
                        1 -> androidx.media3.common.Player.REPEAT_MODE_ONE
                        2 -> androidx.media3.common.Player.REPEAT_MODE_ALL
                        else -> androidx.media3.common.Player.REPEAT_MODE_OFF
                    }
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 1.0
                    controller.volume = volume.toFloat()
                    result.success(null)
                }
                "setSpeed" -> {
                    val speed = call.argument<Double>("speed") ?: 1.0
                    controller.setPlaybackSpeed(speed.toFloat())
                    result.success(null)
                }
                "setEqualizerBand" -> {
                    val bandIndex = call.argument<Int>("bandIndex") ?: 0
                    val level = call.argument<Int>("level") ?: 0 // -1500 to 1500 (mB)
                    AudioService.equalizer?.setBandLevel(bandIndex.toShort(), level.toShort())
                    android.util.Log.d("AudioX", "Set equalizer band $bandIndex to $level")
                    result.success(null)
                }
                "getEqualizerBand" -> {
                    val bandIndex = call.argument<Int>("bandIndex") ?: 0
                    val level = AudioService.equalizer?.getBandLevel(bandIndex.toShort()) ?: 0
                    result.success(level.toInt())
                }
                "setBassBoost" -> {
                    val strength = call.argument<Int>("strength") ?: 0 // 0-1000
                    AudioService.bassBoost?.setStrength(strength.toShort())
                    android.util.Log.d("AudioX", "Set bass boost to $strength")
                    result.success(null)
                }
                "setVirtualizer" -> {
                    val strength = call.argument<Int>("strength") ?: 0 // 0-1000
                    AudioService.virtualizer?.setStrength(strength.toShort())
                    android.util.Log.d("AudioX", "Set virtualizer to $strength")
                    result.success(null)
                }
                "setReverb" -> {
                    val preset = call.argument<Int>("preset") ?: 0 // 0-6
                    AudioService.presetReverb?.preset = preset.toShort()
                    android.util.Log.d("AudioX", "Set reverb preset to $preset")
                    result.success(null)
                }
                "resetEqualizer" -> {
                    AudioService.equalizer?.let {
                        for (i in 0 until it.numberOfBands) {
                            it.setBandLevel(i.toShort(), 0)
                        }
                    }
                    android.util.Log.d("AudioX", "Reset equalizer to flat")
                    result.success(null)
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getAlbumArt(albumId: String): ByteArray? {
        return try {
            val uri = android.content.ContentUris.withAppendedId(
                android.net.Uri.parse("content://media/external/audio/albumart"),
                albumId.toLong()
            )
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            null
        }
    }

    private fun getSongs(): List<Map<String, Any>> {
        val songs = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            android.provider.MediaStore.Audio.Media._ID,
            android.provider.MediaStore.Audio.Media.TITLE,
            android.provider.MediaStore.Audio.Media.ARTIST,
            android.provider.MediaStore.Audio.Media.ALBUM,
            android.provider.MediaStore.Audio.Media.DATA,
            android.provider.MediaStore.Audio.Media.DURATION,
            android.provider.MediaStore.Audio.Media.ALBUM_ID
        )

        val selection = "${android.provider.MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${android.provider.MediaStore.Audio.Media.TITLE} ASC"

        contentResolver.query(
            android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            null,
            sortOrder
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ALBUM)
            val dataColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.DATA)
            val durationColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.DURATION)
            val albumIdColumn = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ALBUM_ID)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val title = cursor.getString(titleColumn)
                val artist = cursor.getString(artistColumn)
                val album = cursor.getString(albumColumn)
                val uri = cursor.getString(dataColumn)
                val duration = cursor.getLong(durationColumn)
                val albumId = cursor.getLong(albumIdColumn)

                // Artwork URI
                val artworkUri = android.content.ContentUris.withAppendedId(
                    android.net.Uri.parse("content://media/external/audio/albumart"),
                    albumId
                ).toString()

                songs.add(
                    mapOf(
                        "id" to id.toString(),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "uri" to uri,
                        "duration" to duration,
                        "artworkUri" to artworkUri
                    )
                )
            }
        }
        return songs
    }
}
