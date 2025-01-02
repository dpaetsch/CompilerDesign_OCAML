	.text
	.globl	gcd
gcd:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %r9 
	subq	$8, %rsp
	movq	%rsp, %r8 
	subq	$8, %rsp
	movq	%rsp, %rdx
	movq	%rdi, (%r9 )
	movq	%rsi, (%r8 )
	jmp	_cond6229
	.text
_body6228:
	movq	(%r8 ), %rsi
	movq	%rsi, (%rdx)
	movq	(%r8 ), %rsi
	movq	(%r9 ), %rdi
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rdx
	callq	mod
	popq	%rdx
	popq	%rdi
	popq	%r8 
	popq	%r9 
	movq	%rax, %rsi
	movq	%rsi, (%r8 )
	movq	(%rdx), %rsi
	movq	%rsi, (%r9 )
	jmp	_cond6229
	.text
_cond6229:
	movq	(%r8 ), %rsi
	cmpq	$0, %rsi
	setne	%sil
	andq	$1, %rsi
	cmpq	$0, %rsi
	jne	_body6228
	jmp	_post6227
	.text
_post6227:
	movq	(%r9 ), %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	mod
mod:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %rdx
	subq	$8, %rsp
	movq	%rsp, %r9 
	subq	$8, %rsp
	movq	%rsp, %r8 
	movq	%rdi, (%rdx)
	movq	%rsi, (%r9 )
	movq	(%rdx), %rdx
	movq	%rdx, (%r8 )
	jmp	_cond6213
	.text
_body6212:
	movq	(%r8 ), %rdx
	movq	(%r9 ), %rsi
	subq	%rsi, %rdx
	movq	%rdx, (%r8 )
	jmp	_cond6213
	.text
_cond6213:
	movq	(%r8 ), %rdx
	movq	(%r9 ), %rsi
	subq	%rsi, %rdx
	cmpq	$0, %rdx
	setge	%dl
	andq	$1, %rdx
	cmpq	$0, %rdx
	jne	_body6212
	jmp	_post6211
	.text
_post6211:
	movq	(%r8 ), %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
	.globl	program
program:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	%rsp, %r9 
	subq	$8, %rsp
	movq	%rsp, %r8 
	subq	$8, %rsp
	movq	%rsp, %r10
	subq	$8, %rsp
	movq	%rsp, %rdx
	movq	%rdi, (%r9 )
	movq	%rsi, (%r8 )
	movq	$64, %rax
	movq	%r10, %rcx
	movq	%rax, (%rcx)
	movq	$48, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%rdx), %rsi
	movq	(%r10), %rdi
	pushq	%rdi
	pushq	%rsi
	callq	gcd
	popq	%rsi
	popq	%rdi
	movq	%rax, %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	