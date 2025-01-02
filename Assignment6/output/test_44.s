	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %r9 
	subq	$8, %rsp
	movq	%rsp, %r8 
	movq	$8, %rax
	movq	%r9 , %rcx
	movq	%rax, (%rcx)
	movq	$10, %rax
	movq	%r8 , %rcx
	movq	%rax, (%rcx)
	jmp	gcd
	.text
continue_loop:
	movq	(%r9 ), %rsi
	cmpq	%rdi, %rsi
	setg	%dl
	andq	$1, %rdx
	cmpq	$0, %rdx
	jne	if
	jmp	else
	.text
else:
	movq	%rdi, %rdx
	subq	%rsi, %rdx
	movq	%rdx, (%r8 )
	jmp	loop
	.text
gcd:
	movq	(%r9 ), %rdx
	movq	$0, %rax
	cmpq	%rdx, %rax
	sete	%dl
	andq	$1, %rdx
	cmpq	$0, %rdx
	jne	ret_b
	jmp	loop
	.text
if:
	movq	%rsi, %rdx
	subq	%rdi, %rdx
	movq	%rdx, (%r9 )
	jmp	loop
	.text
loop:
	movq	(%r8 ), %rdi
	movq	$0, %rax
	cmpq	%rdi, %rax
	sete	%dl
	andq	$1, %rdx
	cmpq	$0, %rdx
	jne	ret_a
	jmp	continue_loop
	.text
ret_a:
	movq	(%r9 ), %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
ret_b:
	movq	(%r8 ), %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	