	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	$45, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	