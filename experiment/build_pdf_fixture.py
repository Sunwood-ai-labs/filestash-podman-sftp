from PIL import Image, ImageDraw, ImageFont
import sys
path=sys.argv[1]
font=ImageFont.load_default()
p1=Image.new('RGB',(612,792),'white')
d1=ImageDraw.Draw(p1)
d1.rectangle((36,36,576,756),outline=(40,90,150),width=3)
d1.text((60,80),'Additional SFTP Fixture - Page 1',font=font,fill=(20,40,70))
d1.text((60,125),'This first page checks PDF preview and upload.',font=font,fill=(30,30,30))
d1.text((60,165),'It contains a heading, short body text and footer.',font=font,fill=(30,30,30))
d1.text((60,710),'Page 1 of 2',font=font,fill=(70,70,70))
p2=Image.new('RGB',(612,792),'white')
d2=ImageDraw.Draw(p2)
d2.rectangle((36,36,576,756),outline=(40,140,110),width=3)
d2.text((60,80),'Additional SFTP Fixture - Page 2',font=font,fill=(20,70,55))
d2.text((60,125),'This second page confirms a two-page document.',font=font,fill=(30,30,30))
d2.text((60,165),'The fixture is intentionally simple and disposable.',font=font,fill=(30,30,30))
d2.text((60,710),'Page 2 of 2',font=font,fill=(70,70,70))
p1.save(path,'PDF',save_all=True,append_images=[p2],resolution=72)
