$flutterRoot = 'C:\path\to\flutter'
$androidSdk = 'C:\path\to\AndroidSDK'
$jdk = 'C:\path\to\jdk-21'

$env:Path = "$flutterRoot\bin;$androidSdk\platform-tools;$jdk\bin;$env:Path"
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk

Write-Host "Flutter root: $flutterRoot"
Write-Host "Android SDK: $androidSdk"
Write-Host "JAVA_HOME: $jdk"
