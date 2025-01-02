	.data
	.globl	_str_arr7201
_str_arr7201:
	.asciz	"ab"
	.text
	.globl	run2
run2:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %r8 
	subq	$8, %rsp
	movq	%rsp, %r9 
	movq	%rdi, (%r8 )
	movq	%rsi, (%r9 )
	movq	(%r8 ), %rdx
	movq	(%r9 ), %rdi
	pushq	%r15
	movq	%rdx, %r15
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rdx
	callq	*%r15
	popq	%rdx
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r15
	movq	(%r8 ), %rdx
	movq	(%r9 ), %rdi
	pushq	%r15
	movq	%rdx, %r15
	pushq	%rdi
	pushq	%rdx
	callq	*%r15
	popq	%rdx
	popq	%rdi
	popq	%r15
	movq	%rbp, %rsp
	popq	%rbp
	retq	
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
	leaq	_str_arr7201(%rip), %rax
	addq	$0, %rax
	addq	$0, %rax
	movq	%rax, %rsi
	pushq	%rsi
	leaq	print_string(%rip), %rdi
	callq	run2
	popq	%rsi
	movq	$0, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	