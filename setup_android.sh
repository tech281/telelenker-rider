#!/bin/bash
echo "🚀 Creating TELELENKER Rider Android Project..."

# 1. بنیادی ڈھانچہ
mkdir -p app/src/main/{java/com/telelenker/rider,res/{layout,values,drawable}}
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/layout
mkdir -p .github/workflows

# 2. Gradle فائلیں
cat > settings.gradle << 'EOF'
rootProject.name = "TELELENKER"
include ':app'
EOF

cat > build.gradle << 'EOF'
buildscript {
    ext.kotlin_version = '1.9.0'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOF

cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
    id 'kotlin-android'
}

android {
    namespace 'com.telelenker.rider'
    compileSdk 33

    defaultConfig {
        applicationId "com.telelenker.rider"
        minSdk 26
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = '1.8'
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.10.1'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
    implementation 'com.google.android.gms:play-services-location:21.0.1'
    implementation 'io.socket:socket.io-client:2.0.1'
    implementation 'com.google.code.gson:gson:2.10.1'
}
EOF

# 3. AndroidManifest.xml
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.telelenker.rider">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.AppCompat.Light.DarkActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".LocationService"
            android:exported="false"
            android:foregroundServiceType="location" />

        <service
            android:name=".PTTService"
            android:exported="false" />
    </application>
</manifest>
EOF

# 4. MainActivity.kt
cat > app/src/main/java/com/telelenker/rider/MainActivity.kt << 'EOF'
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
EOF

# 5. LocationService.kt
cat > app/src/main/java/com/telelenker/rider/LocationService.kt << 'EOF'
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
EOF

# 6. SocketManager.kt
cat > app/src/main/java/com/telelenker/rider/SocketManager.kt << 'EOF'
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

        val serverUrl = prefs.getString("serverUrl", "http://192.168.x.x:3000") ?: "http://192.168.x.x:3000"
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
EOF

# 7. PTTService.kt
cat > app/src/main/java/com/telelenker/rider/PTTService.kt << 'EOF'
package com.telelenker.rider

import android.app.Service
import android.content.Intent
import android.media.MediaRecorder
import android.os.*
import android.util.Base64
import android.util.Log
import java.io.File
import java.io.FileInputStream

class PTTService : Service() {

    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var audioFile: File? = null
    private lateinit var socketManager: SocketManager

    override fun onCreate() {
        super.onCreate()
        socketManager = SocketManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_PTT" -> startRecording()
            "STOP_PTT" -> stopRecording()
        }
        return START_NOT_STICKY
    }

    private fun startRecording() {
        if (isRecording) return
        try {
            audioFile = File(externalCacheDir, "ptt_${System.currentTimeMillis()}.3gp")
            mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                setOutputFile(audioFile?.absolutePath)
                prepare()
                start()
            }
            isRecording = true

            // Start a thread to send chunks
            Thread {
                while (isRecording) {
                    Thread.sleep(100)
                    sendChunk()
                }
            }.start()
        } catch (e: Exception) {
            Log.e("PTTService", "Recording error", e)
        }
    }

    private fun sendChunk() {
        audioFile?.let { file ->
            if (file.exists() && file.length() > 0) {
                val inputStream = FileInputStream(file)
                val bytes = inputStream.readBytes()
                inputStream.close()
                val base64 = Base64.encodeToString(bytes, Base64.DEFAULT)
                socketManager.sendAudio(base64)
                file.delete()
            }
        }
    }

    private fun stopRecording() {
        isRecording = false
        mediaRecorder?.apply {
            stop()
            release()
        }
        mediaRecorder = null
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
EOF

# 8. Layout activity_main.xml
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="@color/white">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="🚀 TELELENKER"
        android:textSize="24sp"
        android:textStyle="bold"
        android:layout_gravity="center"
        android:layout_marginBottom="20dp"/>

    <TextView
        android:id="@+id/tvStatus"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Status: 🟢 ONLINE"
        android:textSize="18sp"
        android:layout_gravity="center"
        android:layout_marginBottom="30dp"/>

    <Button
        android:id="@+id/btnPTT"
        android:layout_width="200dp"
        android:layout_height="200dp"
        android:text="🎤\nPush to Talk"
        android:textSize="18sp"
        android:gravity="center"
        android:backgroundTint="#DC2626"
        android:layout_gravity="center"
        android:layout_marginBottom="20dp"/>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center">

        <Button
            android:id="@+id/btnOffline"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="⚫ Offline"
            android:backgroundTint="#6B7280"
            android:layout_marginEnd="8dp"/>

        <Button
            android:id="@+id/btnOnline"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="🟢 Online"
            android:backgroundTint="#10B981"/>
    </LinearLayout>

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Press and hold to speak"
        android:textSize="12sp"
        android:textColor="#9CA3AF"
        android:layout_gravity="center"
        android:layout_marginTop="30dp"/>

</LinearLayout>
EOF

# 9. strings.xml
cat > app/src/main/res/values/strings.xml << 'EOF'
<resources>
    <string name="app_name">TELELENKER Rider</string>
</resources>
EOF

# 10. colors.xml
cat > app/src/main/res/values/colors.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="white">#FFFFFF</color>
</resources>
EOF

# 11. GitHub Actions workflow
cat > .github/workflows/build-apk.yml << 'EOF'
name: Build APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'
      - name: Build APK
        run: |
          chmod +x gradlew
          ./gradlew assembleRelease
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: telelenker-rider
          path: app/build/outputs/apk/release/*.apk
EOF

# 12. gradlew
cat > gradlew << 'EOF'
#!/bin/sh
# Just a stub, actual gradle wrapper needed. We'll provide minimal.
echo "Gradle wrapper would be here. You need to run './gradlew' after setting up."
EOF

echo "✅ Android project created!"
echo ""
echo "📌 Next steps:"
echo "1. Add the actual gradle wrapper files (copy from any Android project or generate locally)"
echo "2. Commit and push to GitHub"
echo "3. Go to Actions tab → wait for build → download APK"
echo ""
echo "⚠️ Note: You need to add the gradle wrapper files. Since you have an existing Android project somewhere, you can copy them."
