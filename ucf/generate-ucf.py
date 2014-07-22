#!/usr/bin/python
# -*- coding: utf-8 -*-
# vim: set ts=4 sw=4 et sts=4 ai:

import cStringIO as StringIO

def main(argv):
    import gdata.spreadsheet.service
    client = gdata.spreadsheet.service.SpreadsheetsService()

    key = '10vNcsOAxnuiwc5diespjIepMySxhR0iVZfYxouq4p-E'
    w = client.GetWorksheetsFeed(key, visibility='public', projection='basic')
    for sheet in w.entry:
        if sheet.title.text.lower() == "Pins - Firmware".lower():
            break
    else:
        raise Exception("'Pins - Firmware' sheet not found!")
    
    sheet_key = sheet.id.text.split('/')[-1]
    data = client.GetListFeed(key, sheet_key, visibility='public', projection='values')

    boards = dict(sorted((k, v.text) for k, v in data.entry[0].custom.items() if v.text is not None))
    print "Generating UCF files for", boards.values()

    names_raw = list(sorted((k, v.text) for k, v in data.entry[1].custom.items()))
    names = []
    board = ''
    while len(names_raw) > 0:
        v = names_raw.pop(0)
        if v[-1] is None:
            continue
        if v[0] in boards:
            board = boards[v[0]]

        if board:
            r = (board, v[-1])
        else:
            r = v[-1]
        names.append((v[0], r))
    names = dict(names)

    rows = list(dict((k, v.text) for k, v in r.custom.items() if v.text is not None) for r in data.entry[2:])
    for board in boards.values():
        f = file('hdmi2usb-%s.ucf' % board.lower(), 'w')
        
        module = None
        for row in rows:
            row4board = {}
            for r, v in sorted(row.items()):
                if r not in names:
                    continue
                name = names[r]
                if isinstance(name, tuple):
                    if name[0] != board:
                        continue
                    name = name[-1]
                row4board[name] = v
            if 'Description' not in row4board:
                row4board['Description'] = '????'

            # This board doesn't have this module, so skip this row.
            if row4board['Mod'] == 'No':
                continue
            if row4board['Mod'] == '???':
                print "Warning %(Net Name)s is in unknown module." % row4board
                continue

            # Output module header, if new module
            if module != row4board['Module']:
                f.write("""
##############################################################################
# %(Module)s - %(Description)s
##############################################################################
""" % row4board)
                module = row4board['Module']

            # Output pin information

            pin_config = [
                (12, 'LOC = "%(Pin)s"' % row4board),
            ]
            if 'IO Standard' in row4board and row4board['IO Standard'] != 'N/A':
                pin_config.append((80, 'IOSTANDARD = %s;' % row4board['IO Standard']))

            row4board['Net Name'] = '"%s"' % row4board['Net Name']
            row4board['Pin Config'] = " | ".join("%%-%is" % p % v for p, v in pin_config)
            f.write("""\
NET %(Net Name) -18s  %(Pin Config)s # %(Description)s
""" % row4board)
        f.close()


if __name__ == "__main__":
    import sys
    main(sys.argv)
