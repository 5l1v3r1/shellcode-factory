# Dummy (and suboptimal) example of shell invocation with sys_execve("/bin/sh", NULL, NULL) #

.text
.globl _start
_start:
	call code		# push %eip; jmp code
	.asciz "/bin/sh"
code:
	push $11		# sys_execve
	pop %eax		# 1st arg
	pop %ebx		# 2nd arg: address of '/bin/sh'
	cdq			# 4rd arg: NULL (env)
	movl %edx, %ecx		# 3th arg: NULL (argv)
	int $0x80		# syscall


