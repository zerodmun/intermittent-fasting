## Keep attributes required for Gson TypeToken generic signature retention
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*

## Gson rules
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

## Flutter Local Notifications plugin rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
