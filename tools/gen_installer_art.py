# Mari-style installer bitmaps from design/ (colours: crimson, white, gold, blue)
from PIL import Image, ImageDraw
D='design/'; RED=(155,27,48); GOLD=(212,162,76); WHITE=(250,246,239)
hero=Image.open(D+'hero-mari-ornament.png').convert('RGB')
W,H=hero.size
# welcome/finish panel 164x314: crop around the big star (right part of hero)
ch=H; cw=int(ch*164/314)
wel=hero.crop((int(W*0.05),0,int(W*0.05)+cw,ch)).resize((164,314),Image.LANCZOS)   # patterned crimson background
sx0,sy0,sx1,sy1=int(W*0.70),int(H*0.10),int(W*0.96),int(H*0.90)                       # the big 8-point star
side=max(sx1-sx0,sy1-sy0); cxs=(sx0+sx1)//2; cys=(sy0+sy1)//2
star=hero.crop((cxs-side//2,cys-side//2,cxs+side//2,cys+side//2)).resize((150,150),Image.LANCZOS)
m=Image.new('L',(150,150),0); ImageDraw.Draw(m).ellipse([4,4,145,145],fill=255)
from PIL import ImageFilter; m=m.filter(ImageFilter.GaussianBlur(8))
wel.paste(star,(7,50),m)
band=Image.open(D+'ornament-band.png').convert('RGBA')
bh=int(band.size[1]*164/band.size[0]); b=band.resize((164,bh),Image.LANCZOS)
bg=Image.new('RGBA',b.size,WHITE+(255,)); bg.alpha_composite(b)
wel.paste(bg.convert('RGB'),(0,314-bh))
d=ImageDraw.Draw(wel); d.line([(0,314-bh-2),(163,314-bh-2)],fill=GOLD,width=2)
wel.save('res/welcome.bmp')
# header 150x57: white ornament band, tiled
hb=band.resize((int(band.size[0]*57/band.size[1]),57),Image.LANCZOS)
hdr=Image.new('RGBA',(150,57),WHITE+(255,))
x=0
while x<150: hdr.alpha_composite(hb,(x,0)); x+=hb.size[0]
hdr.convert('RGB').save('res/header.bmp')
print('ok',wel.size,hdr.size)
