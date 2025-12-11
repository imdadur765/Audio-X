package com.example.audio_x

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.PresetReverb
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaNotification
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import com.google.common.collect.ImmutableList

class AudioService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private var notificationManager: NotificationManager? = null

    companion object {
        const val CHANNEL_ID = "AudioX_Playback"
        const val NOTIFICATION_ID = 1
        
        const val ACTION_PLAY = "com.example.audio_x.PLAY"
        const val ACTION_PAUSE = "com.example.audio_x.PAUSE"
        const val ACTION_NEXT = "com.example.audio_x.NEXT"
        const val ACTION_PREVIOUS = "com.example.audio_x.PREVIOUS"
        const val ACTION_SHUFFLE = "com.example.audio_x.SHUFFLE"
        const val ACTION_STOP = "com.example.audio_x.STOP"
        
        // Static references to audio effects
        var equalizer: Equalizer? = null
        var bassBoost: BassBoost? = null
        var virtualizer: Virtualizer? = null
        var presetReverb: PresetReverb? = null
        var audioSessionId: Int = 0
    }

    override fun onCreate() {
        super.onCreate()
        
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        
        val player = ExoPlayer.Builder(this).build()
        
        // Get the audio session ID from the player
        audioSessionId = player.audioSessionId
        android.util.Log.d("AudioX", "Audio Session ID: $audioSessionId")
        
        // Initialize audio effects
        initializeAudioEffects(audioSessionId)
        
        // Build media session with custom callback to prevent auto-stop
        mediaSession = MediaSession.Builder(this, player)
            .setCallback(object : MediaSession.Callback {
                override fun onConnect(
                    session: MediaSession,
                    controller: MediaSession.ControllerInfo
                ): MediaSession.ConnectionResult {
                    return MediaSession.ConnectionResult.AcceptedResultBuilder(session)
                        .build()
                }
                
                override fun onPlaybackResumption(
                    mediaSession: MediaSession,
                    controller: MediaSession.ControllerInfo
                ): com.google.common.util.concurrent.ListenableFuture<MediaSession.MediaItemsWithStartPosition> {
                    android.util.Log.d("AudioX", "onPlaybackResumption called")
                    // Return empty result - we handle playback through Flutter
                    return com.google.common.util.concurrent.Futures.immediateFuture(
                        MediaSession.MediaItemsWithStartPosition(emptyList(), 0, 0)
                    )
                }
            })
            .build()
        
        // Add listener to track player state
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                android.util.Log.d("AudioX", "Playback state: $playbackState")
            }
            
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                android.util.Log.d("AudioX", "Is playing: $isPlaying")
            }
        })
        
        // Set custom notification provider
        setMediaNotificationProvider(CustomNotificationProvider(this))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audio X Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Media playback controls"
                setShowBadge(false)
                setSound(null, null)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun initializeAudioEffects(sessionId: Int) {
        try {
            equalizer = Equalizer(0, sessionId).apply {
                enabled = true
                android.util.Log.d("AudioX", "Equalizer initialized with ${numberOfBands} bands")
            }

            bassBoost = BassBoost(0, sessionId).apply {
                enabled = true
                android.util.Log.d("AudioX", "BassBoost initialized")
            }

            virtualizer = Virtualizer(0, sessionId).apply {
                enabled = true
                android.util.Log.d("AudioX", "Virtualizer initialized")
            }

            presetReverb = PresetReverb(0, sessionId).apply {
                preset = PresetReverb.PRESET_NONE
                enabled = true
                android.util.Log.d("AudioX", "PresetReverb initialized")
            }

            android.util.Log.d("AudioX", "All audio effects initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e("AudioX", "Error initializing audio effects: ${e.message}")
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // When app is swiped away from recents, stop playback and service
        val player = mediaSession?.player
        
        android.util.Log.d("AudioX", "Task removed - App closed from recents")
        
        // Stop playback
        player?.pause()
        
        // Stop service after a short delay to allow state to save
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }, 500)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }
    
    override fun onUpdateNotification(session: MediaSession, startInForegroundRequired: Boolean) {
        super.onUpdateNotification(session, startInForegroundRequired)
        android.util.Log.d("AudioX", "Notification updated")
    }

    override fun onDestroy() {
        android.util.Log.d("AudioX", "Service being destroyed")
        
        // Only create stop marker if player actually had media items
        // This prevents false markers when service stops naturally
        val hadMediaItems = mediaSession?.player?.mediaItemCount ?: 0 > 0
        
        if (hadMediaItems) {
            try {
                val markerFile = java.io.File(filesDir, "playback_stopped.marker")
                markerFile.createNewFile()
                android.util.Log.d("AudioX", "✅ Stop marker created - player had ${mediaSession?.player?.mediaItemCount} items")
            } catch (e: Exception) {
                android.util.Log.e("AudioX", "Failed to create stop marker: ${e.message}")
            }
        } else {
            android.util.Log.d("AudioX", "No marker needed - player was empty")
        }
        
        // Release audio effects
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        presetReverb?.release()
        
        equalizer = null
        bassBoost = null
        virtualizer = null
        presetReverb = null
        
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                android.util.Log.d("AudioX", "Play button clicked")
                mediaSession?.player?.play()
            }
            ACTION_PAUSE -> {
                android.util.Log.d("AudioX", "Pause button clicked")
                mediaSession?.player?.pause()
            }
            ACTION_NEXT -> {
                android.util.Log.d("AudioX", "Next button clicked")
                mediaSession?.player?.let { player ->
                    if (player.hasNextMediaItem()) {
                        player.seekToNextMediaItem()
                    }
                }
            }
            ACTION_PREVIOUS -> {
                android.util.Log.d("AudioX", "Previous button clicked")
                mediaSession?.player?.let { player ->
                    if (player.hasPreviousMediaItem()) {
                        player.seekToPreviousMediaItem()
                    }
                }
            }
            ACTION_SHUFFLE -> {
                android.util.Log.d("AudioX", "Shuffle button clicked")
                mediaSession?.player?.let { player ->
                    player.shuffleModeEnabled = !player.shuffleModeEnabled
                    android.util.Log.d("AudioX", "Shuffle mode: ${player.shuffleModeEnabled}")
                }
            }
            ACTION_STOP -> {
                android.util.Log.d("AudioX", "Close button clicked - creating stop marker")
                
                // Create a marker file that Flutter will check during restoration
                try {
                    val markerFile = java.io.File(filesDir, "playback_stopped.marker")
                    markerFile.createNewFile()
                    android.util.Log.d("AudioX", "✅ Stop marker created: ${markerFile.absolutePath}")
                } catch (e: Exception) {
                    android.util.Log.e("AudioX", "Failed to create stop marker: ${e.message}")
                }
                
                // Stop player and service
                mediaSession?.player?.stop()
                mediaSession?.player?.clearMediaItems()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                
                return START_NOT_STICKY
            }
        }
        // Return START_STICKY to restart service if killed by system
        return START_STICKY
    }

    // Method to handle method channel calls from MainActivity
    fun handleMethodCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
       when (call.method) {
           "play" -> {
               mediaSession?.player?.play()
               result.success(null)
           }
           "pause" -> {
               mediaSession?.player?.pause()
               result.success(null)
           }
           "stop" -> {
               mediaSession?.player?.stop()
               mediaSession?.player?.clearMediaItems()
               stopForeground(STOP_FOREGROUND_REMOVE)
               stopSelf()
               result.success(null)
           }
           "seekTo" -> {
               val pos = call.argument<Int>("position")?.toLong() ?: 0L
               mediaSession?.player?.seekTo(pos)
               result.success(null)
           }
           "seekToNext" -> {
                if (mediaSession?.player?.hasNextMediaItem() == true) {
                    mediaSession?.player?.seekToNextMediaItem()
                }
               result.success(null)
           }
            "seekToPrevious" -> {
                if (mediaSession?.player?.hasPreviousMediaItem() == true) {
                    mediaSession?.player?.seekToPreviousMediaItem()
                }
                result.success(null)
            }
           "getEqualizerBandCount" -> {
               try {
                   val count = equalizer?.numberOfBands?.toInt() ?: 0
                   result.success(count)
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
           "getEqualizerCenterFreq" -> {
               try {
                   val index = call.argument<Int>("bandIndex") ?: 0
                   val freq = equalizer?.getCenterFreq(index.toShort())?.toInt() ?: 0
                   result.success(freq)
               } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
               }
           }
           "getEqualizerBandLevelRange" -> {
               try {
                   val range = equalizer?.bandLevelRange
                   if (range != null && range.size >= 2) {
                       result.success(listOf(range[0].toInt(), range[1].toInt()))
                   } else {
                       result.success(listOf(-1500, 1500))
                   }
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
           "setEqualizerBand" -> {
               try {
                   val index = call.argument<Int>("bandIndex") ?: 0
                   val level = call.argument<Int>("level") ?: 0
                   equalizer?.setBandLevel(index.toShort(), level.toShort())
                   result.success(null)
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
           "getEqualizerBand" -> {
               try {
                   val index = call.argument<Int>("bandIndex") ?: 0
                   val level = equalizer?.getBandLevel(index.toShort())?.toInt() ?: 0
                   result.success(level)
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
           "setBassBoost" -> {
               try {
                   val strength = call.argument<Int>("strength") ?: 0
                   bassBoost?.setStrength(strength.toShort())
                   result.success(null)
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
           "setVirtualizer" -> {
               try {
                   val strength = call.argument<Int>("strength") ?: 0
                   virtualizer?.setStrength(strength.toShort())
                   result.success(null)
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
            "setReverb" -> {
               try {
                   val preset = call.argument<Int>("preset")?.toShort() ?: 0
                   presetReverb?.preset = preset
                   result.success(null)
               } catch (e: Exception) {
                   result.error("EQ_ERROR", e.message, null)
               }
           }
           else -> result.notImplemented()
       }
    }

    private fun createPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, AudioService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    // Custom Notification Provider
    private inner class CustomNotificationProvider(val context: Context) : MediaNotification.Provider {
        override fun createNotification(
            mediaSession: MediaSession,
            customLayout: ImmutableList<CommandButton>,
            actionFactory: MediaNotification.ActionFactory,
            onNotificationChangedCallback: MediaNotification.Provider.Callback
        ): MediaNotification {
            val player = mediaSession.player
            val isPlaying = player.isPlaying
            
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_music_note)
                .setContentTitle(player.currentMediaItem?.mediaMetadata?.title ?: "Audio X")
                .setContentText(player.currentMediaItem?.mediaMetadata?.artist ?: "Unknown Artist")
                .setSubText("Audio X")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true) // Persistent notification
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setStyle(
                    androidx.media.app.NotificationCompat.MediaStyle()
                        .setShowActionsInCompactView(0, 1, 2, 3, 4)
                        .setMediaSession(mediaSession.sessionCompatToken)
                )
                
            // Load Album Art
            val artworkUri = player.currentMediaItem?.mediaMetadata?.artworkUri
            if (artworkUri != null) {
                try {
                    val bitmap = BitmapFactory.decodeStream(
                        context.contentResolver.openInputStream(artworkUri)
                    )
                    notification.setLargeIcon(bitmap)
                } catch (e: Exception) {
                    android.util.Log.e("AudioX", "Error loading album art: ${e.message}")
                }
            }


            // Add actions - Order: Shuffle, Previous, Play/Pause, Next, Close
            val service = this@AudioService
            notification.addAction(R.drawable.ic_shuffle, "Shuffle", service.createPendingIntent(ACTION_SHUFFLE))
                .addAction(R.drawable.ic_skip_previous, "Previous", service.createPendingIntent(ACTION_PREVIOUS))
                .addAction(
                    if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play,
                    if (isPlaying) "Pause" else "Play",
                    service.createPendingIntent(if (isPlaying) ACTION_PAUSE else ACTION_PLAY)
                )
                .addAction(R.drawable.ic_skip_next, "Next", service.createPendingIntent(ACTION_NEXT))
                .addAction(R.drawable.ic_close, "Close", service.createPendingIntent(ACTION_STOP))
            
            return MediaNotification(NOTIFICATION_ID, notification.build())
        }

        override fun handleCustomCommand(
            session: MediaSession,
            action: String,
            extras: Bundle
        ): Boolean {
            return false
        }
    }
}
