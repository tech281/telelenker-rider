package com.telelenker.rider

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.net.URISyntaxException

class SocketManager(context: Context) {
    private var socket: Socket
    private var riderId: String
    private var status = "online"
    private val prefs: SharedPreferences = context.getSharedPreferences("TELELENKER", Context.MODE_PRIVATE)

    init {
        riderId = prefs.getString("riderId", "RIDER_${System.currentTimeMillis()}")!!
        prefs.edit().putString("riderId", riderId).apply()

        val serverUrl = prefs.getString("serverUrl", "https://symmetrical-space-dollop-97vw5565r5r3pr7j-3000.app.github.dev") ?: "https://symmetrical-space-dollop-97vw5565r5r3pr7j-3000.app.github.dev"
        try {
            socket = IO.socket(serverUrl)
            socket.connect()
            setupListeners()
        } catch (e: URISyntaxException) {
            throw RuntimeException(e)
        }
    }

    private fun setupListeners() {
        socket.on(Socket.EVENT_CONNECT) {
            Log.d("SocketManager", "Connected")
        }
        socket.on("new-message") { args ->
            val data = args[0] as JSONObject
            val message = data.getString("message")
            // Play sound
            playNotificationSound()
        }
        socket.on("ptt-broadcast-data") { args ->
            val audioData = args[0] as String
            // Play audio
            playAudio(audioData)
        }
    }

    fun sendLocation(lat: Double, lng: Double, isStopped: Boolean) {
        if (status == "online") {
            val data = JSONObject().apply {
                put("riderId", riderId)
                put("lat", lat)
                put("lng", lng)
                put("status", status)
                put("isStopped", isStopped)
            }
            socket.emit("rider-location", data)
        }
    }

    fun emitStopped() {
        socket.emit("rider-stopped", riderId)
        // Also notify admin with sound (server will send back?)
    }

    fun emitMoving() {
        socket.emit("rider-moving", riderId)
    }

    fun setOffline() {
        status = "offline"
        socket.emit("rider-offline", riderId)
    }

    fun setOnline() {
        status = "online"
        // Resend last location
    }

    fun disconnect() {
        socket.disconnect()
    }

    private fun playNotificationSound() {
        // Implementation using MediaPlayer
    }

    private fun playAudio(base64: String) {
        // Implementation using MediaPlayer
    }
}
