data = open('lib/main.dart', 'rb').read()
text = data.decode('utf-8', errors='replace')
checks = ['LangText', 'flutter_localizations', 'speech_to_text', 'smart_translate', 'LanguageService', '_InlineTripTimer', '_DateRangeFilter', '_filterFrom', 'VoiceInputButton']
for c in checks:
    count = text.count(c)
    print(f'{c}: {count}')
