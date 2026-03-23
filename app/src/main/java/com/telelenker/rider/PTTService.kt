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
