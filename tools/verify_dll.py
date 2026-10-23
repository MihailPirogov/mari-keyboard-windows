# Verify a built keyboard DLL: PE layout + re-parse KBDTABLES and compare with JSON.
import pefile, struct, sys, json
def parse(path, ps):
    pe=pefile.PE(path); img=pe.get_memory_mapped_image(); base=pe.OPTIONAL_HEADER.ImageBase
    rd=lambda f,o: struct.unpack_from('<'+f,img,o)
    def ptr(o):
        v=rd('Q' if ps==8 else 'I',o)[0]; return 0 if v==0 else v-base
    exp={e.name:e for e in pe.DIRECTORY_ENTRY_EXPORT.symbols}
    e=exp[b'KbdLayerDescriptor']; a=e.address; code=img[a:a+12]
    m=pe.FILE_HEADER.Machine
    if m==0x8664:
        assert code[:3]==b'\x48\x8d\x05'; kt=a+7+struct.unpack_from('<i',code,3)[0]
    elif m==0x14c:
        assert code[0]==0xb8, code.hex(); kt=struct.unpack_from('<I',code,1)[0]-base
    elif m==0xaa64:
        i1,i2=struct.unpack_from('<II',code,0)
        assert (i1&0x9f000000)==0x90000000
        immlo=(i1>>29)&3; immhi=(i1>>5)&0x7ffff; imm=((immhi<<2)|immlo)
        if imm & (1<<20): imm-=1<<21
        page=(a & ~0xfff)+(imm<<12)
        assert (i2&0xffc00000)==0x91000000; kt=page+((i2>>10)&0xfff)
    P=ps; o=kt; F=[]
    for i in range(7): F.append(ptr(o)); o+=P
    bmax=img[o]; o+=P; e0=ptr(o); o+=P; e1=ptr(o); o+=P
    flags=rd('I',o)[0]; o+=4; o+=4 if P==8 else 4
    lig=ptr(o); o+=P; typ=rd('II',o)
    cm,vt,dk,kn,kne,knd,vsc=F
    pvb=ptr(cm); maxmod=rd('H',cm+P)[0]; modnum=list(img[cm+P+2:cm+P+3+maxmod])
    tables=[]; t=vt
    while True:
        pv=ptr(t); n=img[t+P]; cb=img[t+P+1]; t+=2*P
        if pv==0: break
        rows=[]; q=pv
        while any(img[q:q+cb]): rows.append([img[q],img[q+1],list(rd('%dH'%n,q+2))]); q+=cb
        tables.append({'nmod':n,'rows':rows})
    def names(p):
        r=[]
        while True:
            s=img[p]; sp=ptr(p+P)
            if s==0 and sp==0: break
            e_=sp
            while img[e_:e_+2]!=b'\0\0': e_+=2
            r.append([s,img[sp:e_].decode('utf-16le')]); p+=2*P
        return r
    def vv(p):
        r=[]
        while True:
            s=img[p]; vk=rd('H',p+2)[0]
            if s==0 and vk==0: break
            r.append([s,vk]); p+=4
        return r
    return pe, dict(fLocaleFlags=flags, modnumber=modnum, tables=tables, vsc_to_vk=list(rd('%dH'%bmax,vsc)),
                e0=vv(e0), e1=vv(e1), keynames=names(kn), keynames_ext=names(kne), type=typ, dead=dk, lig=lig)
ref=json.load(open('src/layout_original.json',encoding='utf-8'))
for arch,ps in (('x86',4),('wow64',8),('x64',8),('arm64',8)):
    pe,d=parse('build/%s/kbdmari.dll'%arch, ps)
    secs=[(s.Name.rstrip(b'\0').decode(),hex(s.Characteristics)) for s in pe.sections]
    print(arch, hex(pe.FILE_HEADER.Machine), 'base',hex(pe.OPTIONAL_HEADER.ImageBase),'subsys',pe.OPTIONAL_HEADER.Subsystem,
          'entry',pe.OPTIONAL_HEADER.AddressOfEntryPoint,'imports',hasattr(pe,'DIRECTORY_ENTRY_IMPORT'),
          'exports',[(x.ordinal,x.name) for x in pe.DIRECTORY_ENTRY_EXPORT.symbols], secs, 'type',d['type'])
    for k in ('fLocaleFlags','modnumber','vsc_to_vk','e0','e1','keynames','keynames_ext'):
        assert d[k]==ref[k], (arch,k)
    diffs=[]
    for t1,t2 in zip(d['tables'],ref['tables']):
        assert len(t1['rows'])==len(t2['rows'])
        for r1,r2 in zip(t1['rows'],t2['rows']):
            assert r1[0]==r2[0] and r1[2]==r2[2], (arch,r1,r2)
            if r1[1]!=r2[1]: diffs.append('%02X:%d->%d'%(r1[0],r2[1],r1[1]))
    assert len(d['tables'])==len(ref['tables'])
    print('   tables identical to mari1.dll except attributes:', ' '.join(diffs))
    fi=pe.FileInfo[0] if hasattr(pe,'FileInfo') else []
    for f in fi:
        for st in getattr(f,'StringTable',[]):
            print('   ', {k.decode():v.decode() for k,v in st.entries.items()})
