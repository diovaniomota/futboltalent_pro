# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
-dontwarn org.bouncycastle.jce.provider.BouncyCastleProvider
-dontwarn org.bouncycastle.pqc.jcajce.provider.BouncyCastlePQCProvider
-keep class org.xmlpull.v1.** { *; }






# Flutter Video Player Custom Rules
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep interface io.flutter.plugins.videoplayer.** { *; }
-keep class dev.flutter.pigeon.video_player_android.** { *; }
-keep interface dev.flutter.pigeon.video_player_android.** { *; }
