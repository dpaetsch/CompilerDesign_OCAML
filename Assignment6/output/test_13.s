	.text
	.globl	main
main:
	pushq	%rbp
	movq	%rsp, %rbp
	jmp	then
	.text
else:
	movq	$9, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
then:
	movq	$7, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	