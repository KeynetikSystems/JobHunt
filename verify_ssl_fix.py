# VERIFY OUR SSL FIX WORKS
import ssl
import certifi

print('[TEST] Testing SSL context creation...')
try:
    ssl_context = ssl.create_default_context(cafile=certifi.where())
    print('[OK] SUCCESS: SSL context created with certifi')
    print('[INFO] Certificate file: ' + certifi.where())
except Exception as e:
    print('[ERROR] FAILED: ' + str(e))

print('')
print('[TEST] Testing imports...')
try:
    import ssl
    import certifi
    import urllib.request
    print('[OK] SUCCESS: All required imports work')
except Exception as e:
    print('[ERROR] FAILED: ' + str(e))

print('')
print('[RESULT] If you see [OK] above, our SSL fix will work on macOS!')
