	.data
	.globl	s
s:
	.quad	_str8175
	.data
	.globl	_str8175
_str8175:
	.asciz	"hello!"
	.text
	.globl	program
program:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %r8 
	subq	$8, %rsp
	movq	%rsp, %rdx
	movq	%rdi, (%r8 )
	movq	%rsi, (%rdx)
	movq	$17, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	