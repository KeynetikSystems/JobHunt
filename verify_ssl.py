import ssl
import certifi
print('Imports successful')
try:
    ssl_context = ssl.create_default_context(cafile=certifi.where())
    print('SSL context created successfully')
except Exception as e:
    print('Error:', e)
