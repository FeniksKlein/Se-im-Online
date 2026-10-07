#!/bin/bash
# Eski komut korunur; Windows: node build/sql_birlestir.js
set -e
exec node "$(dirname "$0")/sql_birlestir.js"
