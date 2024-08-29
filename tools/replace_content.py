import re
import sys
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def read_file(filename):
    try:
        with open(filename, 'r') as f:
            return f.read()
    except IOError as e:
        logging.error(f"Error reading file {filename}: {e}")
        raise

def write_file(filename, content):
    try:
        with open(filename, 'w') as f:
            f.write(content)
    except IOError as e:
        logging.error(f"Error writing to file {filename}: {e}")
        raise

def replace_content(target_file, pattern, replacement_file):
    try:
        logging.info(f"Starting content replacement in {target_file}")
        
        content = read_file(target_file)
        replacement = read_file(replacement_file)
        
        logging.info(f"Read {len(content)} characters from {target_file}")
        logging.info(f"Read {len(replacement)} characters from {replacement_file}")
        
        # Use re.escape only on the pattern, not on the replacement
        new_content = re.sub(re.escape(pattern), lambda m: replacement, content, flags=re.DOTALL)
        
        write_file(target_file, new_content)
        
        logging.info(f"Replacement completed in {target_file}")
        return True
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        logging.error("Usage: python replace_content.py <target_file> <pattern> <replacement_file>")
        sys.exit(1)

    target_file = sys.argv[1]
    pattern = sys.argv[2]
    replacement_file = sys.argv[3]

    if not Path(target_file).is_file():
        logging.error(f"Target file does not exist: {target_file}")
        sys.exit(1)

    if not Path(replacement_file).is_file():
        logging.error(f"Replacement file does not exist: {replacement_file}")
        sys.exit(1)

    success = replace_content(target_file, pattern, replacement_file)
    sys.exit(0 if success else 1)
