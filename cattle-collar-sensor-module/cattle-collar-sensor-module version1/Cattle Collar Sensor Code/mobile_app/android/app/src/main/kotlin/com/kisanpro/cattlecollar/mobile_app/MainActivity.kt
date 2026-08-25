package com.kisanpro.cattlecollar.mobile_app

import android.content.Context
import android.location.Location
import android.location.LocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kisanpro/gps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getFarmerLocation") {
                try {
                    val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    val location: Location? = try {
                        locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                            ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    } catch (e: SecurityException) {
                        null
                    }

                    if (location != null) {
                        val map = HashMap<String, Double>()
                        map["latitude"] = location.latitude
                        map["longitude"] = location.longitude
                        result.success(map)
                    } else {
                        val map = HashMap<String, Double>()
                        map["latitude"] = 13.308200
                        map["longitude"] = 77.526500
                        result.success(map)
                    }
                } catch (e: Exception) {
                    val map = HashMap<String, Double>()
                    map["latitude"] = 13.308200
                    map["longitude"] = 77.526500
                    result.success(map)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
