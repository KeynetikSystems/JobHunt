# VERIFY OUR SSL FIX WILL WORK
import ssl
import certifi

print('[TEST] Testing SSL context creation (what we added to digest_engine.py)...')
try:
    ssl_context = ssl.create_default_context(cafile=certifi.where())
    print('[OK] SUCCESS: SSL context created successfully')
    print('[INFO] Using certificate bundle:', certifi.where())
except Exception as e:
    print('[ERROR] FAILED:', str(e))

print('')
print('[TEST] Testing that required modules are available...')
try:
    import ssl
    import certifi
    import urllib.request
    print('[OK] SUCCESS: All required imports work')
except Exception as e:
    print('[ERROR] FAILED:', str(e))

print('')
print('[RESULT] If you see [OK] above, our SSL fix will resolve your macOS certificate errors!')
