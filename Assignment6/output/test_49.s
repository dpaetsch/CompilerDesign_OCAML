	.text
	.globl	one_iteration
one_iteration:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	%rdi, %rax
	movq	$1, %rcx
	shlq	%cl, %rax
	movq	%rax, %rdx
	movq	%rdi, %rsi
	xorq	%rdx, %rsi
	movq	%rdx, %rax
	movq	$2, %rcx
	shlq	%cl, %rax
	movq	%rax, %rdx
	xorq	%rdx, %rsi
	movq	%rdx, %rax
	movq	$1, %rcx
	shlq	%cl, %rax
	movq	%rax, %rdx
	xorq	%rdx, %rsi
	movq	%rsi, %rax
	movq	$63, %rcx
	shrq	%cl, %rax
	movq	%rax, %rdx
	andq	$1, %rdx
	orq	%rsi, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %rdx
	movq	$1, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	jmp	loop
	.text
end:
	movq	%rdi, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
loop:
	movq	(%rdx), %rdi
	movq	%rdi, %rsi
	addq	$1, %rsi
	movq	%rsi, (%rdx)
	pushq	%rsi
	pushq	%rdx
	callq	one_iteration
	popq	%rdx
	popq	%rsi
	movq	%rax, %rdi
	cmpq	$5, %rsi
	sete	%sil
	andq	$1, %rsi
	cmpq	$0, %rsi
	jne	end
	jmp	loop