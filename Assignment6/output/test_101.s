	.text
	.globl	program
program:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$512, %rsp
	subq	$8, %rsp
	movq	%rsp, -24(%rbp)
	subq	$8, %rsp
	movq	%rsp, -32(%rbp)
	subq	$8, %rsp
	movq	%rsp, %rdx
	subq	$8, %rsp
	movq	%rsp, -304(%rbp)
	subq	$8, %rsp
	movq	%rsp, -8(%rbp)
	subq	$8, %rsp
	movq	%rsp, -40(%rbp)
	subq	$8, %rsp
	movq	%rsp, -208(%rbp)
	subq	$8, %rsp
	movq	%rsp, -224(%rbp)
	subq	$8, %rsp
	movq	%rsp, -240(%rbp)
	subq	$8, %rsp
	movq	%rsp, -256(%rbp)
	subq	$8, %rsp
	movq	%rsp, -272(%rbp)
	subq	$8, %rsp
	movq	%rsp, -288(%rbp)
	subq	$8, %rsp
	movq	%rsp, -456(%rbp)
	subq	$8, %rsp
	movq	%rsp, -472(%rbp)
	subq	$8, %rsp
	movq	%rsp, -488(%rbp)
	subq	$8, %rsp
	movq	%rsp, -504(%rbp)
	subq	$8, %rsp
	movq	%rsp, -512(%rbp)
	subq	$8, %rsp
	movq	%rsp, %r11
	subq	$8, %rsp
	movq	%rsp, %r10
	subq	$8, %rsp
	movq	%rsp, %r9 
	subq	$8, %rsp
	movq	%rsp, %r8 
	movq	%rdi, %rax
	movq	-24(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	%rsi, %rax
	movq	-32(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	$0, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	$0, %rax
	movq	-304(%rbp), %rcx
	movq	%rax, (%rcx)
	jmp	_cond2529
	.text
_body2528:
	movq	$0, %rax
	movq	-8(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -16(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -320(%rbp)
	movq	-16(%rbp), %rax
	addq	-320(%rbp), %rax
	movq	%rax, -64(%rbp)
	movq	-64(%rbp), %rax
	movq	-40(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-40(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -48(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -328(%rbp)
	movq	-48(%rbp), %rax
	addq	-328(%rbp), %rax
	movq	%rax, -72(%rbp)
	movq	-72(%rbp), %rax
	movq	-208(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-208(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -216(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -336(%rbp)
	movq	-216(%rbp), %rax
	addq	-336(%rbp), %rax
	movq	%rax, -80(%rbp)
	movq	-80(%rbp), %rax
	movq	-224(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-224(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -232(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -344(%rbp)
	movq	-232(%rbp), %rax
	addq	-344(%rbp), %rax
	movq	%rax, -88(%rbp)
	movq	-88(%rbp), %rax
	movq	-240(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-240(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -248(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -352(%rbp)
	movq	-248(%rbp), %rax
	addq	-352(%rbp), %rax
	movq	%rax, -96(%rbp)
	movq	-96(%rbp), %rax
	movq	-256(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-256(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -264(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -360(%rbp)
	movq	-264(%rbp), %rax
	addq	-360(%rbp), %rax
	movq	%rax, -104(%rbp)
	movq	-104(%rbp), %rax
	movq	-272(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-272(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -280(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -368(%rbp)
	movq	-280(%rbp), %rax
	addq	-368(%rbp), %rax
	movq	%rax, -112(%rbp)
	movq	-112(%rbp), %rax
	movq	-288(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-288(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -296(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -376(%rbp)
	movq	-296(%rbp), %rax
	addq	-376(%rbp), %rax
	movq	%rax, -120(%rbp)
	movq	-120(%rbp), %rax
	movq	-456(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-456(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -464(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -384(%rbp)
	movq	-464(%rbp), %rax
	addq	-384(%rbp), %rax
	movq	%rax, -128(%rbp)
	movq	-128(%rbp), %rax
	movq	-472(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-472(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -480(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -392(%rbp)
	movq	-480(%rbp), %rax
	addq	-392(%rbp), %rax
	movq	%rax, -136(%rbp)
	movq	-136(%rbp), %rax
	movq	-488(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-488(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -496(%rbp)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -400(%rbp)
	movq	-496(%rbp), %rax
	addq	-400(%rbp), %rax
	movq	%rax, -144(%rbp)
	movq	-144(%rbp), %rax
	movq	-504(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-504(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -408(%rbp)
	movq	%rsi, %rax
	addq	-408(%rbp), %rax
	movq	%rax, -152(%rbp)
	movq	-152(%rbp), %rax
	movq	-512(%rbp), %rcx
	movq	%rax, (%rcx)
	movq	-512(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -416(%rbp)
	movq	%rsi, %rax
	addq	-416(%rbp), %rax
	movq	%rax, -160(%rbp)
	movq	-160(%rbp), %rax
	movq	%r11, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rsi
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -424(%rbp)
	movq	%rsi, %rax
	addq	-424(%rbp), %rax
	movq	%rax, -168(%rbp)
	movq	-168(%rbp), %rax
	movq	%r10, %rcx
	movq	%rax, (%rcx)
	movq	(%r10), %rsi
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -432(%rbp)
	movq	%rsi, %rax
	addq	-432(%rbp), %rax
	movq	%rax, -176(%rbp)
	movq	-176(%rbp), %rax
	movq	%r9 , %rcx
	movq	%rax, (%rcx)
	movq	(%r9 ), %rsi
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -440(%rbp)
	movq	%rsi, %rax
	addq	-440(%rbp), %rax
	movq	%rax, -184(%rbp)
	movq	-184(%rbp), %rax
	movq	%r8 , %rcx
	movq	%rax, (%rcx)
	movq	(%rdx), %rsi
	movq	(%r8 ), %rdi
	movq	%rsi, %rax
	addq	%rdi, %rax
	movq	%rax, -192(%rbp)
	movq	-192(%rbp), %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -448(%rbp)
	movq	-448(%rbp), %rax
	addq	$1, %rax
	movq	%rax, -200(%rbp)
	movq	-200(%rbp), %rax
	movq	-304(%rbp), %rcx
	movq	%rax, (%rcx)
	jmp	_cond2529
	.text
_cond2529:
	movq	-304(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, -312(%rbp)
	movq	-312(%rbp), %rax
	cmpq	$10000000, %rax
	setl	-56(%rbp)
	andq	$1, -56(%rbp)
	cmpq	$0, -56(%rbp)
	jne	_body2528
	jmp	_post2527
	.text
_post2527:
	movq	(%rdx), %rdx
	movq	%rdx, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	