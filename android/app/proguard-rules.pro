# Flutter Foreground Task ProGuard Rules
-keep class com.pravera.flutter_foreground_task.** { *; }

# Record plugin rules
-keep class com.llfbandit.record.** { *; }

# Shared preferences & Jetpack DataStore rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class androidx.datastore.** { *; }
-keep class * extends androidx.datastore.preferences.protobuf.GeneratedMessageLite { *; }
-keepclassmembers class * extends androidx.datastore.preferences.protobuf.GeneratedMessageLite { *; }
-dontwarn javax.annotation.**
-dontwarn kotlinx.coroutines.**
