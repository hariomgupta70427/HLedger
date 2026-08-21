# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /path/to/android-sdk/tools/proguard/proguard-android.txt

# Keep Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Firebase (Auth + Firestore)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep notification classes (flutter_local_notifications, incl. boot + scheduled
# receivers referenced by name in AndroidManifest.xml).
-keep class com.dexterous.** { *; }

# Keep another_telephony SMS plugin. The IncomingSmsReceiver is referenced by
# name in AndroidManifest.xml and the plugin dispatches incoming SMS to a
# background Dart isolate via reflection — R8 must not rename/remove these.
-keep class com.shounakmulay.telephony.** { *; }
-dontwarn com.shounakmulay.telephony.**
