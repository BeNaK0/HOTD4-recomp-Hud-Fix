"""Build only from the user's verified HOTD4 ELF; never ships lifted code."""
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EXPECTED='72fdd45830acd9317ec1e4f97de35a270c94746068fdaF827381c91bb47aa296'.lower()
def digest(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def find_dump(path):
 p=path.resolve()
 if p.is_file():p=p.parent
 candidates=[p,p/'disk0',p/'The House of the Dead 4/disk0',p.parent if p.name.lower()=='elf' else p]
 for d in candidates:
  elf=d/'elf/hod4M.elf'
  if elf.is_file():
   if digest(elf)!=EXPECTED:raise ValueError('Unsupported hod4M.elf. This build requires the original supported arcade revision, not Special or a patched executable.')
   for part in ['fs','drv']:
    if not (d/part).is_dir() or not any(x.is_file() for x in (d/part).rglob('*')):raise ValueError('Incomplete dump: missing '+part+' files.')
   return d
 raise ValueError('Cannot find elf/hod4M.elf. Choose disk0 or its parent folder. Encrypted disc images must first be dumped/extracted with your own tools.')
def run(args,cwd=None,stdout=None):
 print('+ '+' '.join(map(str,args)),flush=True)
 subprocess.run(list(map(str,args)),cwd=cwd,stdout=stdout,check=True)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--dump',required=True);ap.add_argument('--output',required=True);ap.add_argument('--toolchain',required=True);ap.add_argument('--jobs',type=int,default=4);ap.add_argument('--validate-only',action='store_true');a=ap.parse_args()
 dump=find_dump(Path(a.dump));print('Verified normal HOTD4 arcade dump:',dump,flush=True)
 if a.validate_only:return
 out=Path(a.output).resolve()
 for protected in [dump,ROOT/'source',ROOT/'ui',ROOT/'tools']:
  if out==protected or out in protected.parents or protected in out.parents:raise ValueError('Choose a separate installation directory, outside the dump and package sources.')
 tool=Path(a.toolchain).resolve();bin=tool/'mingw64/bin'
 for f in ['gcc.exe','cmake.exe','ninja.exe','python.exe','objdump.exe']:
  if not (bin/f).is_file():raise ValueError('Missing build tool: '+str(bin/f))
 os.environ['PATH']=str(bin)+os.pathsep+os.environ.get('PATH','')
 os.environ['CC']=str(bin/'gcc.exe')
 source=ROOT/'source';gen=source/'games/hotd4/generated';gen.mkdir(parents=True,exist_ok=True)
 # Refuse foreign/stale lifted code; regenerate if toolkit or ELF differs.
 manifest=json.loads((ROOT/'package-manifest.json').read_text(encoding='utf-8'))
 generator_files=[f for f in manifest['files'] if f['path'].endswith(('.py','.h','.json')) and f['path'].startswith(('source/lindberghrecomp/tools/','source/lindberghrecomp/pcrecomp/tools/','tools/gl-','tools/build.py'))]
 signature=hashlib.sha256((EXPECTED+json.dumps(generator_files,sort_keys=True)).encode()).hexdigest()
 marker=gen/'local-build-signature.txt'
 if not marker.exists() or marker.read_text()!=signature:
  run([bin/'python.exe','-m','tools','recomp',dump/'elf/hod4M.elf',gen],cwd=source/'lindberghrecomp')
  thunk=gen/'recomp_gl_thunks_windows.c'
  with thunk.open('w',encoding='utf-8') as f:
   run([bin/'python.exe',source/'lindberghrecomp/tools/gen_gl_thunks.py',gen/'recomp_imports.h',bin.parent/'include/GL/glew.h'],stdout=f)
  s=thunk.read_text(encoding='utf-8');s=s.replace('#include "arbprog.h"','#include "arbprog.h"\n'+(ROOT/'tools/gl-enhancements.h').read_text())
  for name,body in json.loads((ROOT/'tools/gl-overrides.json').read_text()).items():
   s,n=re.subn(r'static void th_'+name+r'\(CPU \*c\)\n\{.*?\n\}',lambda m:body,s,count=1,flags=re.S)
   if n!=1:raise ValueError('GL wrapper generation changed: '+name)
  thunk.write_text(s,encoding='utf-8');marker.write_text(signature)
 build=ROOT/'build'
 run([bin/'cmake.exe','-S',source,'-B',build,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DCMAKE_C_FLAGS_RELEASE=','-DLINDBERGH_GAMES=hotd4','-DLINDBERGH_OPENXR=OFF','-DLINDBERGH_RENDERER=OPENGL','-DCMAKE_C_COMPILER='+str(bin/'gcc.exe'),'-DCMAKE_MAKE_PROGRAM='+str(bin/'ninja.exe'),'-DCMAKE_PREFIX_PATH='+str(bin.parent)])
 run([bin/'cmake.exe','--build',build,'--target','hotd4','--parallel',max(1,min(a.jobs,16))])
 # Resolve runtime DLLs recursively, including indirect OpenAL/SDL dependencies.
 dlls={};pending=[build/'hotd4.exe'];seen=set();system=Path(os.environ.get('WINDIR','C:/Windows'))/'System32'
 while pending:
  file=pending.pop()
  text=subprocess.check_output([str(bin/'objdump.exe'),'-p',str(file)],text=True,errors='replace')
  for name in re.findall(r'DLL Name:\s*(\S+)',text):
   if name.lower() in seen:continue
   seen.add(name.lower());dependency=bin/name
   if dependency.is_file():dlls[name]=dependency;pending.append(dependency)
   elif not (system/name).is_file() and not name.lower().startswith(('api-ms-','ext-ms-')):raise ValueError('Unresolved DLL: '+name)
 out.mkdir(parents=True,exist_ok=True);app=out/'HOTD4_Recomp';app.mkdir(exist_ok=True)
 shutil.copy2(build/'hotd4.exe',app/'hotd4-desktop.exe');run([bin/'strip.exe',app/'hotd4-desktop.exe'])
 for name,p in dlls.items():shutil.copy2(p,app/name)
 # No source game data was packaged: the following copies happen only here.
 localdump=out/'game/disk0';(localdump/'elf').mkdir(parents=True,exist_ok=True)
 shutil.copy2(dump/'elf/hod4M.elf',localdump/'elf/hod4M.elf')
 for part in ['fs','drv']:shutil.copytree(dump/part,localdump/part,dirs_exist_ok=True)
 for p in (ROOT/'ui').rglob('*'):
  if p.is_file():
   rel=p.relative_to(ROOT/'ui');dest=(out if p.name=='Play HOTD4.cmd' else app)/rel
   if p.name=='lindbergh.ini' and dest.exists():continue
   dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
 (out/'dump-path.txt').write_text(str(localdump),encoding='utf-8')
 licenses=app/'licenses';licenses.mkdir(exist_ok=True)
 for label,p in [('ports',source/'LICENSE'),('lindberghrecomp',source/'lindberghrecomp/LICENSE'),('pcrecomp',source/'lindberghrecomp/pcrecomp/LICENSE')]:shutil.copy2(p,licenses/(label+'.txt'))
 # Toolchain package license notices for libraries, including indirect DLLs.
 for p in (bin.parent/'share/licenses').glob('*'):
  if p.is_dir():shutil.copytree(p,licenses/'dependencies'/p.name,dirs_exist_ok=True)
 (out/'local-build.json').write_text(json.dumps({'built_locally':True,'elf_sha256':EXPECTED,'generator_signature':signature,'package_manifest_sha256':digest(ROOT/'package-manifest.json'),'executable_sha256':digest(app/'hotd4-desktop.exe'),'built_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())},indent=2))
 print('\nBuild complete. Start: '+str(out/'Play HOTD4.cmd'),flush=True)
if __name__=='__main__':
 try:main()
 except Exception as e:print('Setup failed: '+str(e),file=sys.stderr);sys.exit(1)
