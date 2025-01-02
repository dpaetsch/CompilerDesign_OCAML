	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	$168, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	