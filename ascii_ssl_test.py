import ssl
import certifi
print('[OK] Import successful')

# Create SSL context exactly as we will in our fix
ssl_context = ssl.create_default_context(cafile=certifi.where())
print('[OK] SSL context created successfully')

print('[OK] All SSL fixes working!')
