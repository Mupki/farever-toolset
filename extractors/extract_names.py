#!/usr/bin/env python3
"""
extract_names.py  -  find and extract the packed file INSIDE a .pak that holds
                     the unit display-name table (texts.name).

find_names.py proved the names live inside res.light.pak / res.pak (as packed
entry CONTENT, not as filenames). This walks the pak's entry tree, and for each
file blob, checks whether its bytes contain known display names. Any entry that
does is written to ./names_out/ for inspection -- that's our localization/CDB.

Reads in a streaming way; safe on the 4.8 GB res.pak. Writes only the matching
(small) entries.

Usage (in the Farever folder):
    python extract_names.py res.light.pak     # start here: only 5.8 MB
    python extract_names.py res.pak           # the big one, if needed
"""
import sys, os, struct, io as _io

NEEDLES = [b"Crabgantua", b"Gorgon's Hollow", b"Lady Bee", b"Reblochonk",
           b"Spongeblob", b"Nepsilon", b"Munster Chuck"]
# also match the structural key we saw in FareverDB raw data
STRUCT_HINTS = [b'"texts"', b'"name"', b'Bees_Mokshi', b'Kobold_Z2D']

def read(f,n):
    b=f.read(n)
    if len(b)!=n: raise EOFError(f"wanted {n}, got {len(b)} @ {f.tell()}")
    return b
def u8(f): return read(f,1)[0]
def u32(f): return struct.unpack("<I",read(f,4))[0]

class E: __slots__=("name","is_dir","children","pos","size")

def parse_tree(f):
    root=E(); root.name=""; root.is_dir=True; root.children=[]; root.pos=root.size=None
    nlen=u8(f); root.name=read(f,nlen).decode("utf-8","replace"); flags=u8(f)
    if not (flags&1):
        root.is_dir=False; root.pos=u32(f); root.size=u32(f); read(f,4); return root
    remaining=[u32(f)]; parents=[root]
    while remaining:
        if remaining[-1]==0: remaining.pop(); parents.pop(); continue
        remaining[-1]-=1
        nlen=u8(f)
        if nlen==0: break                      # padding -> tree done
        e=E(); e.children=[]; e.pos=e.size=None
        e.name=read(f,nlen).decode("utf-8","replace")
        fl=u8(f); e.is_dir=bool(fl&1)
        parents[-1].children.append(e)
        if e.is_dir:
            n=u32(f); parents.append(e); remaining.append(n)
        else:
            e.pos=u32(f); e.size=u32(f); read(f,4)
    return root

def walk(root):
    st=[(root,"")]
    while st:
        e,path=st.pop(); full=(path+"/"+e.name).lstrip("/")
        if e.is_dir:
            for c in reversed(e.children): st.append((c,full))
        else:
            yield full,e.pos,e.size

def main():
    pak=sys.argv[1] if len(sys.argv)>1 else "res.light.pak"
    if not os.path.isfile(pak): print(f"ERROR: no '{pak}'"); sys.exit(1)
    with open(pak,"rb") as f:
        if read(f,3)!=b"PAK": print("not a PAK"); sys.exit(1)
        ver=u8(f); headerSize=u32(f); dataSize=u32(f)
        print(f"PAK v{ver} headerSize={headerSize} dataSize={dataSize}")
        hdr=read(f,headerSize-16); root=parse_tree(_io.BytesIO(hdr))
        marker=read(f,4)
        data_start=f.tell()
        entries=list(walk(root))
        print(f"{len(entries)} entries. Scanning contents for unit names...\n")
        os.makedirs("names_out",exist_ok=True)
        hits=0
        for name,pos,size in entries:
            if size is None or size>50*1024*1024:   # skip huge blobs (textures etc.)
                continue
            f.seek(data_start+pos); blob=f.read(size)
            score=sum(blob.count(n) for n in NEEDLES)
            struct_score=sum(blob.count(h) for h in STRUCT_HINTS)
            if score>0:
                hits+=1
                out=os.path.join("names_out", name.replace("/","__"))
                with open(out,"wb") as o: o.write(blob)
                print(f"  HIT names={score:>4} struct={struct_score:>5}  {name}  ({size:,} B)")
                print(f"        -> {out}")
        if not hits:
            print("No entry content matched. Names may be zlib-compressed in this pak.")
            print("If so, tell me and I'll add decompression. Else try res.pak.")
        else:
            print(f"\n{hits} matching entr(y/ies) written to ./names_out/")
            print("Upload the SMALLEST one that has a high 'names' score to Drive.")

if __name__=="__main__": main()
