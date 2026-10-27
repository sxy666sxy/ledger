from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]

# 1. App label
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
text = text.replace('android:label="xingkong_ledger"', 'android:label="星空记账"')
if 'android.permission.RECORD_AUDIO' not in text:
    permissions = (
        '    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n'
    )
    if 'android.permission.INTERNET' not in text:
        permissions += '    <uses-permission android:name="android.permission.INTERNET" />\n'
    if 'android.speech.RecognitionService' not in text:
        permissions += (
            '    <queries>\n'
            '        <intent>\n'
            '            <action android:name="android.speech.RecognitionService" />\n'
            '        </intent>\n'
            '    </queries>\n'
        )
    text = text.replace('<application', permissions + '\n    <application', 1)
manifest.write_text(text, encoding='utf-8')

# 2. Previous Xingkong icon
for src in (root / 'tool/icons').glob('mipmap-*'):
    dst = root / 'android/app/src/main/res' / src.name
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / 'ic_launcher.png', dst / 'ic_launcher.png')
    shutil.copy2(src / 'ic_launcher.png', dst / 'ic_launcher_round.png')

# Remove the generated adaptive-icon XML so the previous PNG launcher is used on API 26+.
for folder in (root / 'android/app/src/main/res').glob('mipmap-anydpi*'):
    for f in folder.glob('ic_launcher*'):
        f.unlink()

# 3. Release signing (stable keystore from GitHub secrets)
gradle = root / 'android/app/build.gradle.kts'
text = gradle.read_text(encoding='utf-8')
if 'XK_KEYSTORE_PATH' not in text:
    if 'signingConfigs {' not in text:
        needle = '    buildTypes {'
        insert = '''    signingConfigs {
        create("release") {
            val keyPath = System.getenv("XK_KEYSTORE_PATH")
            if (keyPath != null) {
                storeFile = file(keyPath)
                storePassword = System.getenv("XK_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("XK_KEY_ALIAS")
                keyPassword = System.getenv("XK_KEY_PASSWORD")
            }
        }
    }

'''
        text = text.replace(needle, insert + needle, 1)
    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = if (System.getenv("XK_KEYSTORE_PATH") != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
    )
    gradle.write_text(text, encoding='utf-8')

print('patched label, icon, signing config')
