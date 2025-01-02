	.text
	.globl	foo
foo:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rcx, %rdx
	movq	16(%rbp), %rdx
	movq	24(%rbp), %rdx
	movq	%r9 , %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	bar
bar:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rcx, %rdx
	movq	16(%rbp), %r10
	movq	24(%rbp), %rdx
	movq	%r10, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	baz
baz:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rcx, %rdx
	movq	16(%rbp), %rdx
	movq	24(%rbp), %r10
	movq	%r10, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	pushq	$8
	pushq	$7
	movq	$6, %r9 
	movq	$5, %r8 
	movq	$4, %rcx
	movq	$3, %rdx
	movq	$2, %rsi
	movq	$1, %rdi
	callq	foo
	addq	$16, %rsp
	movq	%rax, %rdi
	pushq	%rdi
	pushq	$8
	pushq	$7
	movq	$6, %r9 
	movq	$5, %r8 
	movq	$4, %rcx
	movq	$3, %rdx
	movq	$2, %rsi
	movq	$1, %rdi
	callq	bar
	addq	$16, %rsp
	popq	%rdi
	movq	%rax, %rdx
	pushq	%rdi
	pushq	%rdx
	pushq	$8
	pushq	$7
	movq	$6, %r9 
	movq	$5, %r8 
	movq	$4, %rcx
	movq	$3, %rdx
	movq	$2, %rsi
	movq	$1, %rdi
	callq	baz
	addq	$16, %rsp
	popq	%rdx
	popq	%rdi
	movq	%rax, %rsi
	addq	%rdi, %rdx
	addq	%rsi, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	