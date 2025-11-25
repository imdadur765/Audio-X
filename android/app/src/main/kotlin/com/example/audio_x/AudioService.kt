package com.example.audio_x

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.PresetReverb
import android.os.Build
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

class AudioService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    
    companion object {
        const val ACTION_STOP = "com.example.audio_x.ACTION_STOP"
        
        // Static references to audio effects
        var equalizer: Equalizer? = null
        var bassBoost: BassBoost? = null
        var virtualizer: Virtualizer? = null
        var presetReverb: PresetReverb? = null
        var audioSessionId: Int = 0
    }

    override fun onCreate() {
        super.onCreate()
        
        val player = ExoPlayer.Builder(this).build()
        
        // Get the audio session ID from the player
        audioSessionId = player.audioSessionId
        android.util.Log.d("AudioX", "Audio Session ID: $audioSessionId")
        
        // Initialize audio effects
        initializeAudioEffects(audioSessionId)
        
        mediaSession = MediaSession.Builder(this, player).build()
    }

    private fun initializeAudioEffects(sessionId: Int) {
        try {
            // Initialize Equalizer with 5 bands
            equalizer = Equalizer(0, sessionId).apply {
                enabled = true
                android.util.Log.d("AudioX", "Equalizer initialized with ${numberOfBands} bands")
            }

            // Initialize BassBoost
            bassBoost = BassBoost(0, sessionId).apply {
                enabled = true
                android.util.Log.d("AudioX", "BassBoost initialized")
            }

            // Initialize Virtualizer
            virtualizer = Virtualizer(0, sessionId).apply {
                enabled = true
                android.util.Log.d("AudioX", "Virtualizer initialized")
            }

            // Initialize PresetReverb
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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Handle close/stop action
        if (intent?.action == ACTION_STOP) {
            android.util.Log.d("AudioX", "Close button tapped, stopping service")
            mediaSession?.player?.apply {
                stop()
                clearMediaItems()
            }
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Stop playback and service when app is removed from recents
        android.util.Log.d("AudioX", "App removed from recents, stopping service")
        mediaSession?.player?.stop()
        stopSelf()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onDestroy() {
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
}
