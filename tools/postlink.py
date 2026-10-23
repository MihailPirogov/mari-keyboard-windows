# Match MSKLC/kbdutool section flags (.data = INITIALIZED_DATA|EXECUTE|READ) and set PE checksum.
import pefile, sys
for p in sys.argv[1:]:
    pe = pefile.PE(p)
    for s in pe.sections:
        if s.Name.rstrip(b'\0') == b'.data': s.Characteristics = 0x60000040
    pe.OPTIONAL_HEADER.CheckSum = pe.generate_checksum()
    data = pe.write(); pe.close(); open(p, 'wb').write(data)
    pe = pefile.PE(p); pe.OPTIONAL_HEADER.CheckSum = pe.generate_checksum(); data = pe.write(); pe.close(); open(p, 'wb').write(data)
    print('postlink ok', p)
