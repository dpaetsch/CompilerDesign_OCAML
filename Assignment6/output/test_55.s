	.text
	.globl	foo
foo:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	$42, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	bar
bar:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	$0, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %rsi
	subq	$8, %rsp
	movq	%rsp, %rdx
	movq	$0, %rax
	movq	%rsi, %rcx
	movq	%rax, (%rcx)
	movq	$100, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%rdx), %rdx
	cmpq	$0, %rdx
	setne	%dl
	andq	$1, %rdx
	cmpq	$0, %rdx
	jne	then
	jmp	else
	.text
else:
	pushq	%rsi
	callq	bar
	popq	%rsi
	movq	%rax, %rdx
	movq	%rdx, (%rsi)
	jmp	end
	.text
end:
	movq	(%rsi), %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
then:
	pushq	%rsi
	callq	foo
	popq	%rsi
	movq	%rax, %rdx
	movq	%rdx, (%rsi)
	jmp	end