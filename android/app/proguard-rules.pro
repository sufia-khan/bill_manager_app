# ========================================
# Flutter Core Rules
# ========================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter embedding (required)
-keep class io.flutter.embedding.** { *; }

# ========================================
# Firebase Core & Authentication Rules
# ========================================
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Firebase Core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.firebase.**

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keepclassmembers class com.google.firebase.auth.** { *; }

# Firestore
-keep class com.google.firebase.firestore.** { *; }
-keepclassmembers class com.google.firebase.firestore.** { *; }
-keep class com.google.cloud.firestore.** { *; }

# ========================================
# Google Play Services & Sign-In
# ========================================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ========================================
# Hive Database (Local Storage)
# ========================================
# Keep Hive core classes
-keep class hive.** { *; }
-keep class hive_flutter.** { *; }

# Keep all TypeAdapters
-keep class * extends hive.TypeAdapter { *; }

# Keep Hive boxes and their implementations
-keep class * implements hive.HiveObjectMixin { *; }

# Protobuf (used by Hive)
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# ========================================
# Flutter Local Notifications
# ========================================
# Keep notification classes
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Android notification components
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.app.AlarmManager

# Notification action receivers
-keepclassmembers class * extends android.content.BroadcastReceiver {
    public void onReceive(android.content.Context, android.content.Intent);
}

# ========================================
# Google Fonts
# ========================================
-keep class com.google.android.gms.fonts.** { *; }
-keep class androidx.core.provider.** { *; }
-dontwarn com.google.android.gms.fonts.**

# ========================================
# Connectivity Plus (Network Detection)
# ========================================
-keep class io.flutter.plugins.connectivity.** { *; }
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Network callbacks
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ========================================
# Shared Preferences
# ========================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ========================================
# UUID Generation
# ========================================
-keep class java.util.UUID { *; }

# ========================================
# Timezone Support
# ========================================
-keep class com.github.flutter_timezone.** { *; }
-keep class org.threeten.bp.** { *; }

# ========================================
# Android Standard Libraries
# ========================================
# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ========================================
# Play Core Library (Deferred Components)
# ========================================
# Not used by app but referenced by Flutter
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ========================================
# Security & Optimization
# ========================================
# Remove debug and verbose logging in production
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

# Preserve line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep view constructors (required for XML inflation)
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# ========================================
# Gson (if used indirectly by Firebase)
# ========================================
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# ========================================
# Kotlin Specific
# ========================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ========================================
# Optimization Settings
# ========================================
# Allow aggressive optimization
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Repackage classes into single package (reduces APK size)
-repackageclasses ''

# Remove unused code
-dontwarn javax.**
-dontwarn java.lang.management.**
-dontwarn org.apache.**
