#!/usr/bin/env python3

from datetime import date, datetime
import sys
import os

expDate = datetime.strptime(os.getenv('EXPIRATION_DATE'), "%Y-%m-%d")
delta = expDate.date() - date.today()
secretPath = os.getenv('SECRET_PATH')

# token still valid, nothing to do except exiting gracefully
if delta.days > int(os.getenv('MIN_DAYS_LEFT')):
  print(f"Token at '{secretPath}' still valid for {delta.days} days")
  sys.exit(0)

print(f"""
⚠️  The GitHub Personal Access Token is about to expire in {delta.days} days! ⚠️

Please:
- refresh or create a new token (with 'repo' scope)
- update the 'token' field in '{secretPath}' with the new token (e.g. 'ghp_A3K......')
- update the 'expiration' field in '{secretPath}' with the expiration date (in ISO 8601 format, i.e. run 'date -I')
""")
sys.exit(1)
