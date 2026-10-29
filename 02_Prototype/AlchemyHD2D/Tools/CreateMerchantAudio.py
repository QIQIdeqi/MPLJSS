"""Original short UI coin chimes, deterministic synthesis; no external samples."""
from pathlib import Path
import math,random,struct,wave,json,hashlib
root=Path(__file__).resolve().parents[1]/'ArtSource/MerchantAudio'
root.mkdir(parents=True,exist_ok=True)
rate=44100
report={"origin":"Original deterministic synthesis, no external samples","sample_rate":rate,"files":{}}
for name,notes in [('S_MerchantBuy',[(0,1050),(.065,760)]),('S_MerchantSell',[(0,850),(.055,1250),(.11,1660)])]:
    rng=random.Random(7729);samples=[]
    for i in range(int(rate*.42)):
        t=i/rate;v=0
        for start,freq in notes:
            a=t-start
            if a<0:continue
            attack=min(1,a/.0015)
            v+=attack*(math.sin(2*math.pi*freq*a)*math.exp(-a*23)+.35*math.sin(2*math.pi*freq*2.73*a)*math.exp(-a*45)+rng.uniform(-.1,.1)*math.exp(-a*160))
        samples.append(v)
    maximum=max(abs(v) for v in samples);samples=[v/maximum*.45 for v in samples]
    path=root/(name+'.wav')
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in samples))
    report['files'][path.name]={"seconds":.42,"peak_dbfs":round(20*math.log10(max(abs(v) for v in samples)),2),"rms":math.sqrt(sum(v*v for v in samples)/len(samples)),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
(root/'provenance.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('MERCHANT_AUDIO_SOURCE_PASS')
