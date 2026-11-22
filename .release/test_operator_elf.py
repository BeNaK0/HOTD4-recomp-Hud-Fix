import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import sys
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
spec=importlib.util.spec_from_file_location('local_builder',Path(__file__).resolve().parents[1]/'tools/build.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

class OperatorDiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);(self.root/'elf').mkdir()
        self.layout={'elf':'elf/hod4M.elf'}
        self.fixture=b'asset-free operator discovery fixture'
        self.expected=hashlib.sha256(self.fixture).hexdigest()
        self.patch=patch.dict(builder.ELF_VARIANTS,operator_sha256=self.expected)
        self.patch.start();self.addCleanup(self.patch.stop)
    def put(self,name,data=None):
        p=self.root/'elf'/name;p.write_bytes(self.fixture if data is None else data);return p
    def test_verified_hd_preferred(self):
        self.put('hod4testM.elf');hd=self.put('hod4testM_HD.elf')
        self.assertEqual(builder.find_operator_elf(self.root,self.layout),hd)
    def test_unverified_hd_does_not_hide_valid_standard(self):
        self.put('hod4testM_HD.elf',b'unrecognized fixture');standard=self.put('hod4testM.elf')
        self.assertEqual(builder.find_operator_elf(self.root,self.layout),standard)
    def test_unsupported_operator_remains_optional(self):
        self.put('hod4testM.elf',b'unrecognized fixture')
        with contextlib.redirect_stdout(io.StringIO()) as warning:
            self.assertIsNone(builder.find_operator_elf(self.root,self.layout))
        self.assertIn('Test Menu will not be available',warning.getvalue())
    def test_hod4prog_layout(self):
        folder=self.root/'hod4prog';folder.mkdir();op=folder/'hod4testM.elf';op.write_bytes(self.fixture)
        self.assertEqual(builder.find_operator_elf(self.root,{'elf':'hod4prog/hod4M.elf'}),op)

if __name__=='__main__':unittest.main()
