import importlib.util
from pathlib import Path
import struct
import unittest
from capstone.x86 import X86_REG_EDX

path = Path(__file__).resolve().parents[1] / 'source/lindberghrecomp/pcrecomp/tools/lift/lift32_cpu.py'
spec = importlib.util.spec_from_file_location('switch_lifter', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.IMAGE_BASE = 0x400000

class SwitchRangeTests(unittest.TestCase):
    def slots(self, code):
        lifter = module.Lifter(None, 0x10000)
        return lifter.switch_slots(list(lifter.md.disasm(bytes.fromhex(code), 0x401000)), X86_REG_EDX)

    def test_negative_first_slot(self):
        self.assertEqual(self.slots('8d4a01 83f903 7721'), (-1, 4))

    def test_positive_first_slot(self):
        self.assertEqual(self.slots('8d4afb 83f903 7721'), (5, 4))

    def test_zero_first_slot(self):
        self.assertEqual(self.slots('83fa03 7721'), (0, 4))

    def test_unreasonable_bias_rejected(self):
        self.assertIsNone(self.slots('8d8a56341200 83f903 7721'))

    def test_negative_case_is_emitted_as_local_branch(self):
        # Independently assembled four-case switch for indices -1 through 2.
        # Its first table entry lies before the instruction's displacement.
        start, table = 0x401000, 0x402000
        code = bytes.fromhex('8d4a01 83f903 7721 8b049504204000 ffe0')
        targets = [start + len(code) + i * 6 for i in range(4)]
        for result in (10, 20, 30, 40):
            code += b'\xb8' + struct.pack('<I', result) + b'\xc3'
        code += bytes.fromhex('31c0 c3')
        entries = struct.pack('<4I', *targets)
        def read(va, size):
            for base, data in ((start, code), (table, entries)):
                if base <= va and va + size <= base + len(data):
                    return data[va-base:va-base+size]
            raise ValueError('Outside synthetic image')
        lifter = module.Lifter(None, 0x10000, read_va=read)
        lifted = lifter.lift_function(code, start)
        label = 'L_%08X' % targets[0]
        self.assertIn('goto ' + label, lifted)
        self.assertIn(label + ':', lifted)

if __name__ == '__main__':
    unittest.main()
