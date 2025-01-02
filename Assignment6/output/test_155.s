	.data
	.globl	arr
arr:
	.quad	0
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