# SSL TEST SCRIPT - Verify our approach works
import ssl
import certifi
import urllib.request
import json

# Create SSL context exactly as we will in our fix
ssl_context = ssl.create_default_context(cafile=certifi.where())

# Test connection to a known HTTPS site
try:
    req = urllib.request.Request('https://httpbin.org/get')
    with urllib.request.urlopen(req, timeout=10, context=ssl_context) as response:
        data = json.loads(response.read().decode('utf-8'))
        print('✅ SSL connection successful!')
        print('Response status: ' + data.get('url', 'Unknown'))
except Exception as e:
    print('❌ SSL connection failed: ' + str(e))
