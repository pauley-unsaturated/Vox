#!/bin/bash

# Vox AudioUnit Validation Script
# Validates the AudioUnit using Apple's auval tool

echo "Validating Vox AudioUnit..."
echo "Running: auval -v aumu Atng nSat"
echo "----------------------------------------"

auval -v aumu Atng nSat

echo "----------------------------------------"
echo "Validation complete."