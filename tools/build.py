"""Build only from the user's verified HOTD4 ELF; never ships lifted code."""
import argparse,hashlib,json,os,re,shutil,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ELF_VARIANTS = json.loads((ROOT/'tools/elf-variants.json').read_text(encoding='utf-8'))
EXPECTED = ELF_VARIANTS['prepared_sha256']

def digest(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()

def find_dump(path):
 p=path.resolve()
 if p.is_file():p=p.parent
 candidates=[p,p/'disk0',p/'The House of the Dead 4/disk0']
 if p.name.lower() in ('elf','hod4prog'):
  candidates.append(p.parent)
 for d in candidates:
  for layout in ELF_VARIANTS['layouts']:
   if not (d/layout['elf']).is_file():
    continue
   for part in ('fs','drv'):
    folder=d/layout[part]
    if not folder.is_dir() or not any(x.is_file() for x in folder.rglob('*')):
     raise ValueError(f"Incomplete dump: missing {layout[part]} files.")
   return d, layout
 raise ValueError('Cannot find hod4M.elf in elf or hod4prog. Choose your extracted Rev A arcade dump.')

def prepare_elf(path, hd_path):
 image=path.read_bytes()
 source_hash=hashlib.sha256(image).hexdigest()
 if source_hash==EXPECTED:
  return image, source_hash
 if source_hash!=ELF_VARIANTS['stock_sha256']:
  unsupported=f'Unsupported hod4M.elf (SHA-256 {source_hash}).'
  if not hd_path.is_file():
   raise ValueError(f'{unsupported} Use the original Rev A (DVP-0003A) dump or a matching hod4Ms_HD.elf alongside hod4M.elf.')
  hd_image=hd_path.read_bytes()
  hd_hash=hashlib.sha256(hd_image).hexdigest()
  if hd_hash!=EXPECTED:
   raise ValueError(f'{unsupported} hod4Ms_HD.elf has SHA-256 {hd_hash}. Expected {EXPECTED}.')
  print('Using verified hod4Ms_HD.elf from your dump.',flush=True)
  return hd_image, hd_hash
 prepared=bytearray(image)
 # Reproduce only the compatibility edits in the known HD variant.
 for patch in ELF_VARIANTS['patches']:
  offset=patch['offset']
  replacement=bytes.fromhex(patch['bytes'])
  prepared[offset:offset+len(replacement)]=replacement
 if hashlib.sha256(prepared).hexdigest()!=EXPECTED:
  raise ValueError('Locally prepared HD ELF failed SHA-256 verification.')
 return prepared, source_hash

def find_operator_elf(dump,layout):
 folder=(dump/layout['elf']).parent
 for name in ('hod4testM_HD.elf','hod4testM.elf'):
  path=folder/name
  if path.is_file() and digest(path)==ELF_VARIANTS['operator_sha256']:
   return path
 print('Warning: verified hod4testM.elf/hod4testM_HD.elf missing; arcade Test Menu will not be available.',flush=True)
 return None

def run(args,cwd=None,stdout=None):
 print('+ '+' '.join(map(str,args)),flush=True)
 subprocess.run(list(map(str,args)),cwd=cwd,stdout=stdout,check=True)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--dump',required=True);ap.add_argument('--output',required=True);ap.add_argument('--toolchain',required=True);ap.add_argument('--jobs',type=int,default=4);ap.add_argument('--validate-only',action='store_true');ap.add_argument('--openxr',action='store_true');a=ap.parse_args()
 dump, layout=find_dump(Path(a.dump))
 image, source_hash=prepare_elf(dump/layout['elf'],dump/layout['hd_elf'])
 print('Verified HOTD4 Rev A arcade dump:',dump,flush=True)
 if source_hash!=EXPECTED:
  print('Prepared and verified the HD ELF locally.',flush=True)
 operator_elf=find_operator_elf(dump,layout)
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
 generator_files=[f for f in manifest['files'] if f['path'].endswith(('.py','.h','.json')) and f['path'].startswith(('source/lindberghrecomp/tools/','source/lindberghrecomp/pcrecomp/tools/','tools/gl-','tools/build.py','tools/elf-variants.json'))]
 signature=hashlib.sha256((EXPECTED+json.dumps(generator_files,sort_keys=True)).encode()).hexdigest()
 marker=gen/'local-build-signature.txt'
 if not marker.exists() or marker.read_text()!=signature:
  with tempfile.TemporaryDirectory(prefix='hotd4-lift-') as directory:
   lift_elf=Path(directory)/'hod4M.elf'
   lift_elf.write_bytes(image)
   run([bin/'python.exe','-m','tools','recomp',lift_elf,gen],cwd=source/'lindberghrecomp')
  thunk=gen/'recomp_gl_thunks_windows.c'
  with thunk.open('w',encoding='utf-8') as f:
   run([bin/'python.exe',source/'lindberghrecomp/tools/gen_gl_thunks.py',gen/'recomp_imports.h',bin.parent/'include/GL/glew.h'],stdout=f)
  s=thunk.read_text(encoding='utf-8');s=s.replace('#include "arbprog.h"','#include "arbprog.h"\n'+(ROOT/'tools/gl-enhancements.h').read_text())
  for name,body in json.loads((ROOT/'tools/gl-overrides.json').read_text()).items():
   s,n=re.subn(r'static void th_'+name+r'\(CPU \*c\)\n\{.*?\n\}',lambda m:body,s,count=1,flags=re.S)
   if n!=1:raise ValueError('GL wrapper generation changed: '+name)
  thunk.write_text(s,encoding='utf-8');marker.write_text(signature)
 if operator_elf:
  opgen=source/'games/hotd4test/generated';opgen.mkdir(parents=True,exist_ok=True)
  opmarker=opgen/'local-build-signature.txt'
  if not opmarker.exists() or opmarker.read_text()!=signature:
   run([bin/'python.exe','-m','tools','recomp',operator_elf,opgen],cwd=source/'lindberghrecomp')
   opthunk=opgen/'recomp_gl_thunks_windows.c'
   with opthunk.open('w',encoding='utf-8') as f:
    run([bin/'python.exe',source/'lindberghrecomp/tools/gen_gl_thunks.py',opgen/'recomp_imports.h',bin.parent/'include/GL/glew.h'],stdout=f)
   text=opthunk.read_text(encoding='utf-8')
   viewport_body = """static void th_glViewport(CPU *c)
{
    int x=(int)A32(0),y=(int)A32(1),w=(int)A32(2),h=(int)A32(3);
    host_viewport_scale(&x,&y,&w,&h);glViewport(x,y,w,h);
}"""
   text,n=re.subn(r'static void th_glViewport\(CPU \*c\)\n\{.*?\n\}',lambda _:viewport_body,text,count=1,flags=re.S)
   if n!=1:raise ValueError('Operator viewport wrapper generation changed.')
   opthunk.write_text(text,encoding='utf-8');opmarker.write_text(signature)
 builds = {}
 for name, folder, game, openxr in [('hotd4-desktop.exe','build','hotd4',False),
                                   ('hotd4-testmenu.exe','build-testmenu','hotd4test',False),
                                   ('hotd4-vr.exe','build-openxr','hotd4',True)]:
  if game=='hotd4test' and not operator_elf:
   continue
  if openxr and not a.openxr:
   continue
  build = ROOT/folder
  run([bin/'cmake.exe','-S',source,'-B',build,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
       '-DCMAKE_C_FLAGS_RELEASE=','-DLINDBERGH_GAMES='+game,
       '-DLINDBERGH_OPENXR='+('ON' if openxr else 'OFF'),'-DLINDBERGH_RENDERER=OPENGL',
       '-DCMAKE_C_COMPILER='+str(bin/'gcc.exe'),'-DCMAKE_MAKE_PROGRAM='+str(bin/'ninja.exe'),
       '-DCMAKE_PREFIX_PATH='+str(bin.parent)])
  run([bin/'cmake.exe','--build',build,'--target',game,'--parallel',max(1,min(a.jobs,16))])
  builds[name] = build/(game+'.exe')
 # Resolve runtime DLLs recursively, including indirect OpenAL/SDL dependencies.
 dlls={};pending=list(builds.values());seen=set();system=Path(os.environ.get('WINDIR','C:/Windows'))/'System32'
 while pending:
  file=pending.pop()
  text=subprocess.check_output([str(bin/'objdump.exe'),'-p',str(file)],text=True,errors='replace')
  for name in re.findall(r'DLL Name:\s*(\S+)',text):
   if name.lower() in seen:continue
   seen.add(name.lower());dependency=bin/name
   if dependency.is_file():dlls[name]=dependency;pending.append(dependency)
   elif not (system/name).is_file() and not name.lower().startswith(('api-ms-','ext-ms-')):raise ValueError('Unresolved DLL: '+name)
 out.mkdir(parents=True,exist_ok=True);app=out/'HOTD4_Recomp';app.mkdir(exist_ok=True)
 for name, executable in builds.items():
  shutil.copy2(executable,app/name)
  run([bin/'strip.exe',app/name])
 for name,p in dlls.items():shutil.copy2(p,app/name)
 # No source game data was packaged: the following copies happen only here.
 localdump=out/'game/disk0';(localdump/'elf').mkdir(parents=True,exist_ok=True)
 for part in ('fs','drv'):
  shutil.copytree(dump/layout[part],localdump/part,dirs_exist_ok=True)
 with tempfile.NamedTemporaryFile(dir=localdump/'elf',prefix='.hod4-',suffix='.tmp',delete=False) as staged:
  stage_path=Path(staged.name)
 try:
  stage_path.write_bytes(image)
  stage_path.replace(localdump/'elf/hod4M.elf')
 finally:
  stage_path.unlink(missing_ok=True)
 if operator_elf:
  shutil.copy2(operator_elf,localdump/'elf/hod4testM.elf')
  for name in ('LucidaConsole_12.tga','LucidaConsole_12.abc','logo.tga'):
   font=operator_elf.parent/name
   if font.is_file():shutil.copy2(font,localdump/'elf'/name)
  run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',ROOT/'tools/operator-font.ps1','-OutputDir',app/'operator-assets'])
 for p in (ROOT/'ui').rglob('*'):
  if p.is_file():
   rel=p.relative_to(ROOT/'ui')
   if p.name=='Play HOTD4 (VR OpenXR).cmd' and not a.openxr:
    continue
   dest=(out if p.name in ('Play HOTD4.cmd', 'Play HOTD4 (Performance Log).cmd', 'Play HOTD4 (VR OpenXR).cmd', 'Model Viewer.cmd') else app)/rel
   if p.name=='lindbergh.ini' and dest.exists():continue
   dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
 compiler=Path(os.environ['SystemRoot'])/'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
 for name in ('Play HOTD4.exe','Model Viewer.exe'):
  run([compiler,'/nologo','/target:winexe','/platform:x64','/reference:System.Windows.Forms.dll',
       '/out:'+str(out/name).replace('/', '\\'),str(ROOT/'tools/windows-launcher.cs').replace('/', '\\')])
 (out/'dump-path.txt').write_text(str(localdump),encoding='utf-8')
 licenses=app/'licenses';licenses.mkdir(exist_ok=True)
 for label,p in [('ports',source/'LICENSE'),('lindberghrecomp',source/'lindberghrecomp/LICENSE'),('pcrecomp',source/'lindberghrecomp/pcrecomp/LICENSE')]:shutil.copy2(p,licenses/(label+'.txt'))
 # Toolchain package license notices for libraries, including indirect DLLs.
 for p in (bin.parent/'share/licenses').glob('*'):
  if p.is_dir():shutil.copytree(p,licenses/'dependencies'/p.name,dirs_exist_ok=True)
 (out/'local-build.json').write_text(json.dumps({'built_locally':True,'elf_sha256':EXPECTED,'source_elf_sha256':source_hash,'generator_signature':signature,'package_manifest_sha256':digest(ROOT/'package-manifest.json'),'executable_sha256':digest(app/'hotd4-desktop.exe'),**({'openxr_executable_sha256':digest(app/'hotd4-vr.exe')} if (app/'hotd4-vr.exe').is_file() else {}),'built_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())},indent=2))
 print('\nBuild complete. Start: '+str(out/'Play HOTD4.exe'),flush=True)
if __name__=='__main__':
 try:main()
 except Exception as e:print('Setup failed: '+str(e),file=sys.stderr);sys.exit(1)
