#!/usr/bin/env python3
"""Fix placeholders lost in Calamares 3.3.14 translations.

The catalogs in lang/ are the upstream files of Calamares v3.3.14
(https://github.com/calamares/calamares/tree/v3.3.14/lang), identical to the
ones compiled into the Ubuntu package.  This script applies, once, the
corrections listed below; each must match exactly one translation.  It is
kept as the record of what differs from upstream.

    python3 tools/calamares-lang/fix-placeholders.py        # apply
    python3 tools/calamares-lang/fix-placeholders.py --check # verify only
"""
import re
import sys
from pathlib import Path

LANG = Path(__file__).resolve().parent / 'lang'

# (language, source text, wrong fragment, right fragment)
FIXES = [
    ('pt_BR', 'Keyboard model has been set to %1.',
     'modelo teclado foi configurado para 1', 'O modelo de teclado foi definido como %1.'),
    ('pt_BR', 'Set timezone to %1.',
     'Configure timezone para 1', 'Definir o fuso horário para %1.'),
    ('es', 'Set flags on %1MiB <strong>%2</strong> partition to <strong>%3</strong>',
     'particion de %1MiB<strong>2</strong>', 'partición de %1MiB <strong>%2</strong>'),
    ('fr', 'Create new <strong>%1MiB</strong> partition on <strong>%3</strong> (%2)',
     '<strong>1 Mio</strong>', '<strong>%1 Mio</strong>'),
    ('ar', 'The setup of %1 is complete.', 'اكتمل إعداد 1%.', 'اكتمل إعداد %1.'),
    ('fi_FI', 'Install boot loader on <strong>%1</strong>…', '<strong>% 1</strong>', '<strong>%1</strong>'),
    ('fi_FI', 'Install %1 <strong>alongside</strong> another operating system on disk <strong>%2</strong> (%3)',
     '<strong>2%</strong>', '<strong>%2</strong>'),
    ('fi_FI', '<strong>Manual</strong> partitioning on disk <strong>%1</strong> (%2)', '(% 2)', '(%2)'),
    ('ro', 'Link creation failed, target: %1; link name: %2', 'numele legăturii: 2', 'numele legăturii: %2'),
    ('sv', 'Create new <strong>%1MiB</strong> partition on <strong>%3</strong> (%2) with entries <em>%4</em>',
     '<strong>1MiB</strong>', '<strong>%1MiB</strong>'),
    ('sv', 'Setting is not of string type', 'Inställning %1 är inte av sträng typ ', 'Inställningen är inte av strängtyp'),
    ('zh_CN', '%1 can not be installed. Calamares was unable to load all of the configured modules. This is a problem with the way Calamares is being used by the distribution.',
     '％1', '%1'),
    ('zh_CN', 'The partition table on %1 already has %2 primary partitions, and no more can be added. Please remove one primary partition and add an extended partition, instead.',
     '％1上的分区表已经有％2个', '%1 上的分区表已经有 %2 个'),
    ('fa', 'This storage device has %1 on it. What would you like to do?<br/>You will be able to review and confirm your choices before any change is made to the storage device.',
     'سازی٪ 1 روی', 'سازی %1 روی'),
    ('fa', 'The numbers and dates locale will be set to %1.', 'روی٪ 1 تنظیم', 'روی %1 تنظیم'),
    ('fa', '<h1>Welcome to the Calamares setup program for %1</h1>', 'برای 1٪', 'برای %1'),
    ('fa', '<h1>All done.</h1><br/>%1 has been set up on your computer.<br/>You may now start using your new system.',
     'تمام شد.٪ 1 در', 'تمام شد. %1 در'),
    ('fa', 'The partition table on %1 already has %2 primary partitions, and no more can be added. Please remove one primary partition and add an extended partition, instead.',
     'در٪ 1 از قبل دارای٪ 2 پارتیشن', 'در %1 از قبل دارای %2 پارتیشن'),
    ('fa', 'Tracking helps %1 to see how often it is installed, what hardware it is installed on and which applications are used. To see what will be sent, please click the help icon next to each area.',
     'به٪ 1 کمک', 'به %1 کمک'),
]


def xml(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def placeholders_ok(path):
    """Every finished translation uses the same %N as its source."""
    import xml.etree.ElementTree as ET
    bad = []
    for message in ET.parse(path).getroot().iter('message'):
        source = message.findtext('source') or ''
        node = message.find('translation')
        if node is None or node.get('type') or message.get('numerus') == 'yes':
            continue
        text = ''.join(node.itertext())
        if text.strip() and set(re.findall(r'%\d', source)) != set(re.findall(r'%\d', text)):
            bad.append(source)
    return bad


def main():
    check = '--check' in sys.argv
    status = 0
    for lang, source, wrong, right in FIXES:
        path = LANG / f'calamares_{lang}.ts'
        data = path.read_text(encoding='utf-8')
        start = data.find(f'<source>{xml(source)}</source>')
        if start < 0:
            print(f'{lang}: source not found: {source[:50]}'); status = 1; continue
        end = data.find('</message>', start)
        block = data[start:end]
        if xml(right) in block and xml(wrong) not in block:
            continue
        if check or block.count(xml(wrong)) != 1:
            print(f'{lang}: not fixed: {source[:50]}'); status = 1; continue
        data = data[:start] + block.replace(xml(wrong), xml(right)) + data[end:]
        path.write_text(data, encoding='utf-8')
        print(f'{lang}: fixed {source[:50]}')
    # Omissions that read correctly (cs, hi, pl) are not in these files;
    # every catalog shipped here must have matching placeholders.
    allowed = {('es', 'A GPT partition table is the best option for all systems.')}
    for path in sorted(LANG.glob('calamares_*.ts')):
        lang = path.stem.removeprefix('calamares_')
        for source in placeholders_ok(path):
            if not any(lang == l and source.startswith(s) for l, s in allowed):
                print(f'{lang}: placeholder mismatch: {source[:60]}'); status = 1
    return status


if __name__ == '__main__':
    sys.exit(main())
