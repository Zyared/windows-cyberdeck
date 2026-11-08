import math,wave,struct,pathlib
p=pathlib.Path(r'C:\Users\Zyared\CyberDeck\audio');p.mkdir(exist_ok=True)
rate=44100; frames=[]
for i in range(int(rate*2.4)):
 t=i/rate;v=0
 for start,freq,dur in [(0,110,.65),(.12,220,.6),(.45,440,.28),(.8,659.25,.25),(1.12,880,.7)]:
  u=t-start
  if 0<=u<dur:
   env=min(u/.02,1)*min((dur-u)/.12,1);v+=.13*env*(math.sin(2*math.pi*freq*u)+.25*math.sin(4*math.pi*freq*u))
 frames.append(struct.pack('<h',int(max(-.85,min(.85,v))*32767)))
with wave.open(str(p/'arasaka-start.wav'),'wb') as w:w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(b''.join(frames))
