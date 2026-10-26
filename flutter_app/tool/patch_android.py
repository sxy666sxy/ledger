from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
text = text.replace('android:label="xingkong_ledger"', 'android:label="星空记账"')
manifest.write_text(text, encoding='utf-8')
print('patched', manifest)
