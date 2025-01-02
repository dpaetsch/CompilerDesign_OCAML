	.data
	.globl	y
y:
	.quad	1
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
	leaq	y(%rip), %rax
	movq	(%rax), %rax
	movq	%rax, %rdx
	cmpq	$0, %rdx
	jne	_then8155
	jmp	_else8154
	.text
_else8154:
	jmp	_merge8153
	.text
_merge8153:
	movq	$15, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
_then8155:
	movq	$17, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	