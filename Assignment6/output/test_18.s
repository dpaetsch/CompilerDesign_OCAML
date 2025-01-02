	.data
	.globl	gbl
gbl:
	.quad	12
	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	gbl(%rip), %rax
	movq	(%rax), %rax
	movq	%rax, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	