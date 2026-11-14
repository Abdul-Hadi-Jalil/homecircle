package com.homecircle.homecircle

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("homecircle_updates", "HomeCircle updates", NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = "Updates from your households"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
