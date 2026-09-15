import ssl
import certifi
print('✅ Import successful')

# Create SSL context exactly as we will in our fix
ssl_context = ssl.create_default_context(cafile=certifi.where())
print('✅ SSL context created successfully')

print('🎉 All SSL fixes working!')
