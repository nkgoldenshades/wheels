import re

data = open('lib/main.dart', 'rb').read()
text = data.decode('utf-8')

# ── 1. Add new imports after existing flutter/material import ──────────────
old_imports = "import 'package:flutter/material.dart';\nimport 'package:flutter/foundation.dart';"
new_imports = """import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smart_translate_text/smart_translate_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';"""

if old_imports in text:
    text = text.replace(old_imports, new_imports, 1)
    print('✅ Added imports')
else:
    print('❌ Import anchor not found')

# ── 2. Add location_field import after supabase ────────────────────────────
old_supa = "import 'package:supabase_flutter/supabase_flutter.dart';\nimport 'package:url_launcher"
new_supa = """import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/location_field.dart';
import 'package:url_launcher"""

if old_supa in text:
    text = text.replace(old_supa, new_supa, 1)
    print('✅ Added location_field import')
else:
    print('❌ Supabase import anchor not found')

open('lib/main.dart', 'wb').write(text.encode('utf-8'))
print('Done step 1')
