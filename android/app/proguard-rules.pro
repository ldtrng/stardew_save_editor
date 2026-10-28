# WorkManager (pulled in by Google Mobile Ads) creates its Room database by
# reflection on the generated *_Impl class; R8 must keep it, or the app
# crashes at start-up in androidx.startup.InitializationProvider.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** extends androidx.room.RoomDatabase { *; }

# AppLovin's OMID library references the optional Amazon Privacy Pass classes,
# which are not in the app; without this R8 fails the release build.
-dontwarn com.amazon.privacypass.PrivacyPass
-dontwarn com.amazon.privacypass.VerificationContext
-dontwarn com.amazon.privacypass.callback.AttestAPICallback
