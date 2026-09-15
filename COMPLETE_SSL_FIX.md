# SSL CERTIFICATE FIX FOR MACOS - COMPLETE SOLUTION
#
# PROBLEM: SSL certificate verification failed when making HTTPS requests to Tavily/Groq APIs on macOS
#
# SOLUTION: Add proper SSL context using certifi package
#
# STEPS TO APPLY:
# 1. Add certifi to requirements-desktop.txt
# 2. Modify digest_engine.py as shown below
# 3. Install updated dependencies
#


## STEP 1: Update requirements-desktop.txt

Add this line to your requirements-desktop.txt:

certifi>=2023.7.22

Then run:
pip install -r requirements-desktop.txt

## STEP 2: Modify digest_engine.py

### Add these imports (after line 14):

import ssl
import certifi

### Add SSL context creation (after the new imports):

# SSL context for secure HTTPS connections
ssl_context = ssl.create_default_context(cafile=certifi.where())

### Modify the _http_post_json function (change line 137):

# FROM:
with urllib.request.urlopen(req, timeout=60) as resp:

# TO:
with urllib.request.urlopen(req, timeout=60, context=ssl_context) as resp:

## STEP 3: Verify the changes

After applying these changes, the relevant sections should look like:

`python
# Imports section
import json
import re
import time
import urllib.request
import urllib.error
import ssl  # <-- ADDED
import certifi  # <-- ADDED

# SSL context for secure HTTPS connections  <-- ADDED
ssl_context = ssl.create_default_context(cafile=certifi.where())  # <-- ADDED

from config import ROOT, load_env
from send_report import send_report


# In _http_post_json function:
try:
    with urllib.request.urlopen(req, timeout=60, context=ssl_context) as resp:  # <-- MODIFIED
        return json.loads(resp.read().decode("utf-8"))

- Uses certifi's up-to-date certificate bundle instead of potentially outdated system certificates
- Works on all platforms (macOS, Linux, Windows)
- Maintains security (doesn't disable certificate verification)
- Requires minimal code changes

## ALTERNATIVE QUICK FIX (NOT RECOMMENDED FOR PRODUCTION)

If you need an immediate workaround and understand the security implications:

You can temporarily set environment variables before running:

export PYTHONHTTPSVERIFY=0  # macOS/Linux
set PYTHONHTTPSVERIFY=0     # Windows

⚠️  WARNING: This disables SSL certificate verification and makes you vulnerable to MITM attacks!

