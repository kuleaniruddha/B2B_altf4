import re
from collections import OrderedDict

def deduplicate_translations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Match the entire _translations map
    map_match = re.search(r'static const Map<String, Map<String, String>> _translations = \{(.*?)\};', content, re.DOTALL)
    if not map_match:
        print("Could not find _translations map")
        return

    full_map_text = map_match.group(1)
    
    # Match each locale block like 'en': { ... },
    locale_blocks = re.findall(r"'(\w+)': \{(.*?)\},", full_map_text, re.DOTALL)
    
    new_full_map_text = "\n"
    for locale, block_content in locale_blocks:
        lines = block_content.strip().split('\n')
        unique_keys = OrderedDict()
        for line in lines:
            line = line.strip()
            if not line or line.startswith('//'):
                continue
            # Match 'key': 'value', or "key": "value",
            match = re.match(r"['\"](\w+)['\"]\s*:\s*(['\"].*?['\"])\s*,?", line)
            if match:
                key, value = match.groups()
                if key not in unique_keys:
                    unique_keys[key] = value
        
        new_block_content = f"    '{locale}': {{\n"
        for key, value in unique_keys.items():
            new_block_content += f"      '{key}': {value},\n"
        new_block_content += "    },"
        new_full_map_text += new_block_content + "\n"

    new_content = content.replace(map_match.group(1), new_full_map_text)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

if __name__ == "__main__":
    deduplicate_translations(r'c:\Users\ASUS\OneDrive\Desktop\smart-civic-system\citizen_app\lib\services\language_service.dart')
