package com.telelenker.rider

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices

class MainActivity : AppCompatActivity() {

    private lateinit var socketManager: SocketManager
    private lateinit var locationServiceIntent: Intent
    private var isServiceRunning = false
    private lateinit var tvStatus: TextView
    private lateinit var btnPTT: Button
    private lateinit var btnOffline: Button
    private lateinit var btnOnline: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvStatus = findViewById(R.id.tvStatus)
        btnPTT = findViewById(R.id.btnPTT)
        btnOffline = findViewById(R.id.btnOffline)
        btnOnline = findViewById(R.id.btnOnline)

        socketManager = SocketManager(this)

        // Foreground service intent
        locationServiceIntent = Intent(this, LocationService::class.java)

        checkPermissions()

        btnPTT.setOnTouchListener { _, event ->
            when (event.action) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    startPTT()
                    true
                }
                android.view.MotionEvent.ACTION_UP -> {
                    stopPTT()
                    true
                }
                else -> false
            }
        }

        btnOffline.setOnClickListener {
            socketManager.setOffline()
            tvStatus.text = "Status: ⚫ OFFLINE"
            Toast.makeText(this, "You are offline", Toast.LENGTH_SHORT).show()
        }

        btnOnline.setOnClickListener {
            socketManager.setOnline()
            tvStatus.text = "Status: 🟢 ONLINE"
            Toast.makeText(this, "You are online", Toast.LENGTH_SHORT).show()
        }
    }

    private fun startPTT() {
        val intent = Intent(this, PTTService::class.java).apply {
            action = "START_PTT"
        }
        startService(intent)
        btnPTT.text = "🔴 Speaking..."
    }

    private fun stopPTT() {
        val intent = Intent(this, PTTService::class.java).apply {
            action = "STOP_PTT"
        }
        startService(intent)
        btnPTT.text = "🎤 Push to Talk"
    }

    private fun checkPermissions() {
        val permissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.POST_NOTIFICATIONS
        )
        val need = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (need.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, need.toTypedArray(), 100)
        } else {
            startLocationService()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100 && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startLocationService()
        } else {
            Toast.makeText(this, "Permissions required", Toast.LENGTH_SHORT).show()
            finish()
        }
    }

    private fun startLocationService() {
        if (!isServiceRunning) {
            startForegroundService(locationServiceIntent)
            isServiceRunning = true
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        socketManager.disconnect()
    }
}
