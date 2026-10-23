# Extract KBDTABLES from an MSKLC-style 64-bit-pointer keyboard DLL into JSON
import pefile, struct, sys, json
pe=pefile.PE(sys.argv[1]); img=pe.get_memory_mapped_image(); base=pe.OPTIONAL_HEADER.ImageBase
rd=lambda fmt,off: struct.unpack_from('<'+fmt,img,off)
def ptr(off):
    v=rd('Q',off)[0]; return 0 if v==0 else v-base
exp=[e for e in pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name==b'KbdLayerDescriptor'][0].address
code=img[exp:exp+8]; assert code[:3]==b'\x48\x8d\x05'
kt=exp+7+struct.unpack_from('<i',code,3)[0]
F=[ptr(kt+8*i) for i in range(7)]
pCharMod,pVkTbl,pDead,pNames,pNamesExt,pNamesDead,pVsc=F
bMax=img[kt+56]; pE0=ptr(kt+64); pE1=ptr(kt+72); flags=rd('I',kt+80)[0]
m=pCharMod; pvb=ptr(m); maxmod=rd('H',m+8)[0]
out={'fLocaleFlags':flags,'modbits':[],'modnumber':list(img[m+10:m+11+maxmod]),'tables':[]}
q=pvb
while img[q]: out['modbits'].append([img[q],img[q+1]]); q+=2
t=pVkTbl
while True:
    pv=ptr(t); nmod=img[t+8]; cb=img[t+9]; t+=16
    if pv==0: break
    rows=[]; q=pv
    while any(img[q:q+cb]):
        rows.append([img[q],img[q+1],list(rd('%dH'%nmod,q+2))]); q+=cb
    out['tables'].append({'nmod':nmod,'rows':rows})
out['vsc_to_vk']=list(rd('%dH'%bMax,pVsc))
def vv(p):
    r=[]
    while True:
        s=img[p]; vk=rd('H',p+2)[0]
        if s==0 and vk==0: break
        r.append([s,vk]); p+=4
    return r
out['e0']=vv(pE0); out['e1']=vv(pE1)
def names(p):
    r=[]
    while True:
        s=img[p]; sp=ptr(p+8)
        if s==0 and sp==0: break
        e=sp
        while img[e:e+2]!=b'\0\0': e+=2
        r.append([s,img[sp:e].decode('utf-16le')]); p+=16
    return r
out['keynames']=names(pNames); out['keynames_ext']=names(pNamesExt)
assert pDead==0 and pNamesDead==0
json.dump(out,open(sys.argv[2],'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print('ok',len(out['tables']))
