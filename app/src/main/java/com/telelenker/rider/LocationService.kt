package com.telelenker.rider

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*

class LocationService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var lastLocation: Location? = null
    private var isStopped = false
    private var stopTimer: Handler? = null
    private val CHANNEL_ID = "telelenker_location"
    private val NOTIFICATION_ID = 123
    private lateinit var socketManager: SocketManager

    override fun onCreate() {
        super.onCreate()
        socketManager = SocketManager(this)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    handleLocation(location)
                }
            }
        }

        requestLocationUpdates()
    }

    private fun handleLocation(location: Location) {
        // Stop detection
        if (lastLocation != null) {
            val distance = location.distanceTo(lastLocation!!)
            if (distance < 5 && !isStopped) {
                // Rider stopped
                isStopped = true
                socketManager.emitStopped()
                // Also play alert sound (optional locally)
            } else if (distance > 10 && isStopped) {
                isStopped = false
                socketManager.emitMoving()
            }
        }
        lastLocation = location

        // Send location
        socketManager.sendLocation(location.latitude, location.longitude, isStopped)
    }

    private fun requestLocationUpdates() {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000)
            .setMinUpdateIntervalMillis(2000)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            Log.e("LocationService", "Location permission error", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "TELELENKER Location",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TELELENKER Rider")
            .setContentText("Tracking your location for fleet management")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
        socketManager.disconnect()
    }
}
