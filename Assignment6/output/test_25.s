	.text
	.globl	baz
baz:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rdi, %r10
	pushq	16(%rbp)
	popq	-8(%rbp)
	movq	24(%rbp), %r11
	movq	%rsi, %rdi
	movq	%rdx, %rsi
	movq	%rcx, %rdx
	addq	%r10, %rdi
	addq	%rdi, %rsi
	addq	%rsi, %rdx
	addq	%r8 , %rdx
	addq	%r9 , %rdx
	addq	-8(%rbp), %rdx
	addq	%r11, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	bar
bar:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rdi, %r10
	pushq	16(%rbp)
	popq	-8(%rbp)
	movq	24(%rbp), %r11
	movq	%rsi, %rdi
	movq	%rdx, %rsi
	movq	%rcx, %rdx
	addq	%r10, %rdi
	addq	%rdi, %rsi
	movq	%rsi, %r10
	addq	%rdx, %r10
	movq	%r10, %rdx
	addq	%r8 , %rdx
	pushq	%r11
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rdx
	pushq	%r11
	pushq	-8(%rbp)
	movq	%rdx, %rcx
	movq	%r10, %rdx
	callq	baz
	addq	$16, %rsp
	popq	%rdx
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	popq	%r11
	movq	%rax, %rsi
	addq	%r9 , %rdx
	addq	-8(%rbp), %rdx
	addq	%r11, %rdx
	addq	%rsi, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	foo
foo:
	pushq	%rbp
	movq	%rsp, %rbp
	pushq	%rdi
	pushq	%rdi
	pushq	%rdi
	movq	%rdi, %r9 
	movq	%rdi, %r8 
	movq	%rdi, %rcx
	movq	%rdi, %rdx
	movq	%rdi, %rsi
	callq	bar
	addq	$16, %rsp
	popq	%rdi
	movq	%rax, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	$1, %rdi
	callq	foo
	movq	%rax, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	