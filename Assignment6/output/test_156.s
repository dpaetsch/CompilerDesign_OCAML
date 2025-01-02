	.data
	.globl	arr
arr:
	.quad	_global_arr8168
	.data
	.globl	_global_arr8168
_global_arr8168:
	.quad	4
	.quad	1
	.quad	2
	.quad	3
	.quad	4
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
	movq	$5, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	