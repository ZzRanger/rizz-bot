#!/bin/bash



# Navigate to the specified directory
cd "lambda-hilly-rizz"

# Check if package.json exists in the current directory
if [ ! -f "package.json" ]; then
  echo "package.json not found in the specified directory."
  exit 1
fi

# Run npm run build
npm run build
