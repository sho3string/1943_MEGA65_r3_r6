#!/usr/bin/env python3
"""Build MEGA65 1943 ROMs from the MAME 1943 set (1943.zip plus parent ROMs)."""
import argparse
import pathlib
import zipfile
import zlib

FILES = {
 '1943_main.rom': ['bme01.12d','bme02.13d','bme03.14d'],
 '1943_sound.rom': ['bm05.4k'],
 '1943_char.rom': ['bm04.5h'],
 '1943_map1.rom': ['bm14.5f'],
 '1943_map2.rom': ['bm23.8k'],
 '1943_scr1.rom': [f'bm{i}.{p}' for i,p in [(15,'10f'),(16,'11f'),(17,'12f'),(18,'14f'),(19,'10j'),(20,'11j'),(21,'12j'),(22,'14j')]],
 '1943_scr2.rom': ['bm24.14k','bm25.14l'],
 '1943_obj.rom': [f'bm{i:02d}.{p}' for i,p in [(6,'10a'),(7,'11a'),(8,'12a'),(9,'14a'),(10,'10c'),(11,'11c'),(12,'12c'),(13,'14c')]],
 '1943_prom.rom': ['bm.7k','bm10.7l','bm11.12l','bm1.12a','bm12.12m','bm2.13a','bm3.14a','bm4.12c','bm5.7f','bm6.4b','bm7.7c','bm8.8c','bm9.6l']
}

def interleave(a,b):
    assert len(a)==len(b)
    out=bytearray(len(a)*2)
    out[0::2]=a;out[1::2]=b
    return bytes(out)

def build(name, parts):
    if name=='1943_main.rom': return parts[0]+parts[1]+parts[2]
    if name in ('1943_char.rom','1943_map1.rom','1943_map2.rom'):
        raw=parts[0]
        return bytes(v for i in range(0,len(raw),2) for v in raw[i:i+2][::-1])
    if name=='1943_prom.rom': return b''.join(parts)
    if name=='1943_scr2.rom':
        # Scroll 2 graphics: two 8-bit chips interleaved into 16-bit words.
        # No gfx_sort is specified for scr2 in JTFRAME mem.yaml.
        return interleave(parts[1],parts[0])
    if name in ('1943_scr1.rom','1943_obj.rom'):
        # mame2mra sequence [4,0,5,1,6,2,7,3] on 16-bit region
        seq=[4,0,5,1,6,2,7,3]
        chunks=[parts[i] for i in seq]
        return b''.join(interleave(chunks[i],chunks[i+1]) for i in range(0,8,2))
    return b''.join(parts)

def sort_object_hvvvvxx(data):
    """Apply the same object ROM address permutation used by the MEGA65 1942 port."""
    result = bytearray(len(data))
    for src, value in enumerate(data):
        dst = (src & ~0x7c) | ((src & 0x40) >> 4) | ((src & 0x3c) << 1)
        result[dst] = value
    return bytes(result)

def sort_map_hvvvx(data):
    """Rotate h-v-v-v within each 16-bit map word address; x (byte lane) stays fixed."""
    result = bytearray(len(data))
    for src, value in enumerate(data):
        dst = (src & ~0x1e) | ((src & 0x10) >> 3) | ((src & 0x0e) << 1)
        result[dst] = value
    return bytes(result)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('zip',nargs='+',help='MAME 1943 zip(s), e.g. 1943.zip')
    ap.add_argument('-o','--output',default='arcade/1943')
    args=ap.parse_args()
    sources={}
    for path in args.zip:
        with zipfile.ZipFile(path) as z:
            for item in z.namelist():
                if not item.endswith('/'):
                    sources[pathlib.PurePosixPath(item).name.lower()]=z.read(item)
    output=pathlib.Path(args.output);output.mkdir(parents=True,exist_ok=True)
    for name,inputs in FILES.items():
        missing=[f for f in inputs if f.lower() not in sources]
        if missing: raise SystemExit(f'{name}: missing {missing}')
        data=build(name,[sources[f.lower()] for f in inputs])
        if name in ('1943_map1.rom', '1943_map2.rom'):
            data = sort_map_hvvvx(data)
        if name == '1943_obj.rom':
            data = sort_object_hvvvvxx(data)
        expected={'1943_main.rom':163840,'1943_sound.rom':32768,'1943_char.rom':32768,'1943_map1.rom':32768,'1943_map2.rom':32768,'1943_scr1.rom':262144,'1943_scr2.rom':65536,'1943_obj.rom':262144,'1943_prom.rom':7168}[name]
        if len(data)!=expected:raise SystemExit(f'{name}: expected {expected}, got {len(data)}')
        (output/name).write_bytes(data)
        print(f'{name:20s} {len(data):7d} bytes CRC32 {zlib.crc32(data):08X}')

if __name__=='__main__': main()
