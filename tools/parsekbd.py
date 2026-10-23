import pefile, struct, sys, json
def load(f):
    pe=pefile.PE(f)
    img=pe.get_memory_mapped_image()
    base=pe.OPTIONAL_HEADER.ImageBase
    return pe,img,base
def strings(pe):
    out={}
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id==6:
            for e in t.directory.entries:
                for l in e.directory.entries:
                    d=pe.get_data(l.data.struct.OffsetToData,l.data.struct.Size)
                    p=0
                    for i in range(16):
                        n=struct.unpack_from('<H',d,p)[0]; p+=2
                        s=d[p:p+2*n].decode('utf-16le'); p+=2*n
                        if n: out[(e.id-1)*16+i]=s
    return out
def parse(f):
    pe,img,base=load(f)
    is64ptr=True  # both use 64-bit pointers (x64 native, wow64 ptr64)
    P=8
    def rd(fmt,off): return struct.unpack_from('<'+fmt,img,off)
    def ptr(off):
        v=rd('Q',off)[0]
        return 0 if v==0 else v-base
    exp=[e for e in pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name==b'KbdLayerDescriptor'][0].address
    code=img[exp:exp+16]
    print('func bytes',code.hex())
    # find KBDTABLES: x64: lea rax,[rip+X] (48 8d 05 rel32); x86: mov eax,imm32 (b8 imm32)
    if code[:3]==b'\x48\x8d\x05':
        kt=exp+7+struct.unpack_from('<i',code,3)[0]
    elif code[0]==0xb8:
        kt=struct.unpack_from('<I',code,1)[0]-base
    else: raise SystemExit('unknown')
    o=kt
    fields={}
    for n in ['pCharModifiers','pVkToWcharTable','pDeadKey','pKeyNames','pKeyNamesExt','pKeyNamesDead','pusVSCtoVK']:
        fields[n]=ptr(o); o+=8
    fields['bMaxVSCtoVK']=img[o]; o+=8
    fields['pVSCtoVK_E0']=ptr(o); o+=8
    fields['pVSCtoVK_E1']=ptr(o); o+=8
    fields['fLocaleFlags']=rd('I',o)[0]; o+=4
    fields['nLgMax']=img[o]; fields['cbLgEntry']=img[o+1]; o+=4
    fields['pLigature']=ptr(o); o+=8
    fields['dwType'],fields['dwSubType']=rd('II',o)
    print({k:hex(v) for k,v in fields.items()})
    # modifiers
    m=fields['pCharModifiers']; pvb=ptr(m); maxmod=rd('H',m+8)[0]
    modnum=list(img[m+10:m+10+maxmod+1])
    vkbits=[]; q=pvb
    while img[q]: vkbits.append((img[q],img[q+1])); q+=2
    print('VK_TO_BIT',[(hex(a),b) for a,b in vkbits],'maxmod',maxmod,'ModNumber',modnum)
    def wch(w):
        if w==0xF000: return 'WCH_NONE'
        if w==0xF001: return 'WCH_DEAD'
        if w==0xF002: return 'WCH_LGTR'
        return 'U+%04X(%s)'%(w, chr(w) if w>=0x20 else '^')
    tables=[]
    t=fields['pVkToWcharTable']
    while True:
        pv=ptr(t); nmod=img[t+8]; cb=img[t+9]; t+=16
        if pv==0 and nmod==0: break
        rows=[]; q=pv+0
        while True:
            vk=img[q]; at=img[q+1]
            if vk==0 and at==0 and cb and all(b==0 for b in img[q:q+cb]): break
            w=list(rd('%dH'%nmod,q+2)); rows.append((vk,at,w)); q+=cb
        tables.append((nmod,cb,rows))
        print('--- table nMod',nmod,'cb',cb)
        for vk,at,w in rows:
            print('  VK %02X attr %02X'%(vk,at), ' | '.join(wch(x) for x in w))
    # deadkeys
    dk=fields['pDeadKey']; dks=[]
    if dk:
        q=dk
        while True:
            both,comp,fl=rd('IHH',q)
            if both==0: break
            dks.append((both>>16, both&0xffff, comp, fl)); q+=8
    print('DEADKEYS',[(hex(a),hex(b),hex(c),fl) for a,b,c,fl in dks])
    # vsc to vk
    sc=fields['pusVSCtoVK']; vsc=list(rd('%dH'%fields['bMaxVSCtoVK'],sc))
    print('VSCtoVK',[hex(x) for x in vsc])
    def vscvk(p):
        r=[]
        while p:
            a,b=rd('BBH',p)[:2] if False else (img[p],None)
            vk=rd('H',p+2)[0]; s=img[p]
            if s==0 and vk==0: break
            r.append((hex(s),hex(vk))); p+=4
        return r
    print('E0',vscvk(fields['pVSCtoVK_E0'])); print('E1',vscvk(fields['pVSCtoVK_E1']))
    def names(p):
        r=[]
        while p:
            s=img[p]; sp=ptr(p+8)
            if s==0 and sp==0: break
            e=img.index(b'\0\0',sp); 
            while (e-sp)%2: e=img.index(b'\0\0',e+1)
            r.append((hex(s),img[sp:e].decode('utf-16le'))); p+=16
        return r
    print('KeyNames',names(fields['pKeyNames'])); print('KeyNamesExt',names(fields['pKeyNamesExt']))
    dn=[]; p=fields['pKeyNamesDead']
    while p and ptr(p):
        sp=ptr(p); e=sp
        while img[e:e+2]!=b'\0\0': e+=2
        dn.append(img[sp:e].decode('utf-16le')); p+=8
    print('DeadNames',dn)
    print('lig',fields['nLgMax'],fields['cbLgEntry'],hex(fields['pLigature']))
    print('STRINGS',strings(pe))
for f in sys.argv[1:]:
    print('=====',f); parse(f)
