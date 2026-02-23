#!/usr/bin/env python3
"""
Simple launcher script for TranslationFiesta
"""

import os
import sys

# Add current directory to Python path
sys.path.insert(0, os.path.dirname(__file__))

# Import and run the main application
from TranslationFiesta import main

if __name__ == "__main__":
    main()
