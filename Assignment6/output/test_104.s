	.data
	.globl	_str_arr2868
_str_arr2868:
	.asciz	" "
	.text
	.globl	bubble_sort
bubble_sort:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	subq	$8, %rsp
	movq	%rsp, %r8 
	subq	$8, %rsp
	movq	%rsp, %r10
	subq	$8, %rsp
	movq	%rsp, %rdx
	subq	$8, %rsp
	movq	%rsp, -8(%rbp)
	subq	$8, %rsp
	movq	%rsp, %r9 
	movq	%rdi, (%r8 )
	movq	%rsi, (%r10)
	movq	$0, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r10), %rsi
	subq	$1, %rsi
	movq	%rsi, %rax
	movq	-8(%rbp), %rcx
	movq	%rax, (%rcx)
	jmp	_cond2893
	.text
_body2892:
	movq	$1, %rax
	movq	%r9 , %rcx
	movq	%rax, (%rcx)
	jmp	_cond2901
	.text
_body2900:
	movq	(%r8 ), %r10
	movq	(%r9 ), %rsi
	subq	$1, %rsi
	movq	%r10, %rax
	movq	%rax, %rdi
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	movq	%r10, %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %rsi
	movq	(%rsi), %r11
	movq	(%r8 ), %r10
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	movq	%r10, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	popq	%r11
	movq	%r10, %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %rsi
	movq	(%rsi), %rsi
	cmpq	%rsi, %r11
	setg	%sil
	andq	$1, %rsi
	cmpq	$0, %rsi
	jne	_then2946
	jmp	_else2945
	.text
_cond2893:
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	cmpq	$0, %rsi
	setg	%sil
	andq	$1, %rsi
	cmpq	$0, %rsi
	jne	_body2892
	jmp	_post2891
	.text
_cond2901:
	movq	(%r9 ), %rsi
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rdi
	cmpq	%rdi, %rsi
	setle	%sil
	andq	$1, %rsi
	cmpq	$0, %rsi
	jne	_body2900
	jmp	_post2899
	.text
_else2945:
	jmp	_merge2944
	.text
_merge2944:
	movq	(%r9 ), %rsi
	addq	$1, %rsi
	movq	%rsi, (%r9 )
	jmp	_cond2901
	.text
_post2891:
	movq	%rbp, %rsp
	popq	%rbp
	retq	
	.text
_post2899:
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	subq	$1, %rsi
	movq	%rsi, %rax
	movq	-8(%rbp), %rcx
	movq	%rax, (%rcx)
	jmp	_cond2893
	.text
_then2946:
	movq	(%r8 ), %r10
	movq	(%r9 ), %rsi
	subq	$1, %rsi
	movq	%r10, %rax
	movq	%rax, %rdi
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	movq	%r10, %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %rsi
	movq	(%rsi), %rsi
	movq	%rsi, (%rdx)
	movq	(%r8 ), %r10
	movq	(%r9 ), %rsi
	subq	$1, %rsi
	movq	%r10, %rax
	movq	%rax, %rdi
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	movq	%r10, %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %r11
	movq	(%r8 ), %r10
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	movq	%r10, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	popq	%r11
	movq	%r10, %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %rsi
	movq	(%rsi), %rsi
	movq	%rsi, (%r11)
	movq	(%r8 ), %r10
	movq	-8(%rbp), %rax
	movq	(%rax), %rax
	movq	%rax, %rsi
	movq	%r10, %rax
	movq	%rax, %rdi
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	movq	%r10, %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %rdi
	movq	(%rdx), %rsi
	movq	%rsi, (%rdi)
	jmp	_merge2944
	.text
	.globl	program
program:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	subq	$8, %rsp
	movq	%rsp, %r9 
	subq	$8, %rsp
	movq	%rsp, %rdx
	subq	$8, %rsp
	movq	%rsp, %r8 
	subq	$8, %rsp
	movq	%rsp, %r11
	movq	%rdi, (%r9 )
	movq	%rsi, (%rdx)
	pushq	%r11
	pushq	%r8 
	movq	$8, %rdi
	callq	oat_alloc_array
	popq	%r8 
	popq	%r11
	movq	%rax, %rdx
	movq	%rdx, %rax
	movq	%rax, %r10
	subq	$8, %rsp
	movq	%rsp, %r9 
	movq	$8, %rax
	movq	%r9 , %rcx
	movq	%rax, (%rcx)
	subq	$8, %rsp
	movq	%rsp, %rdx
	movq	%r10, (%rdx)
	movq	$0, %rax
	movq	%r8 , %rcx
	movq	%rax, (%rcx)
	jmp	_cond2811
	.text
_body2810:
	movq	%rdx, %rax
	movq	(%rax), %rax
	movq	%rax, -8(%rbp)
	movq	(%r8 ), %rsi
	movq	-8(%rbp), %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%r10
	pushq	%r9 
	pushq	%r8 
	pushq	%rdi
	pushq	%rsi
	pushq	%rdx
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rsi
	popq	%rdi
	popq	%r8 
	popq	%r9 
	popq	%r10
	popq	%r11
	movq	-8(%rbp), %rax
	addq	$0, %rax
	addq	$8, %rax
	movq	%rax, %rcx
	movq	%rsi, %rax
	imulq	$8, %rax
	addq	%rcx, %rax
	movq	%rax, %rsi
	movq	$0, %rax
	movq	%rsi, %rcx
	movq	%rax, (%rcx)
	movq	(%r8 ), %rsi
	addq	$1, %rsi
	movq	%rsi, (%r8 )
	jmp	_cond2811
	.text
_cond2811:
	movq	(%r8 ), %rsi
	movq	(%r9 ), %rdi
	cmpq	%rdi, %rsi
	setl	%sil
	andq	$1, %rsi
	cmpq	$0, %rsi
	jne	_body2810
	jmp	_post2809
	.text
_post2809:
	movq	%r10, (%r11)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$0, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$0, %rax
	movq	%rax, %rdx
	movq	$121, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$1, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$8, %rax
	movq	%rax, %rdx
	movq	$125, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$2, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$16, %rax
	movq	%rax, %rdx
	movq	$120, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$3, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$24, %rax
	movq	%rax, %rdx
	movq	$111, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$4, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$32, %rax
	movq	%rax, %rdx
	movq	$116, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$5, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$40, %rax
	movq	%rax, %rdx
	movq	$110, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$6, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$48, %rax
	movq	%rax, %rdx
	movq	$117, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdx
	movq	%rdx, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	pushq	%rdx
	movq	$7, %rsi
	callq	oat_assert_array_length
	popq	%rdx
	popq	%rdi
	popq	%r11
	movq	%rdx, %rax
	addq	$0, %rax
	addq	$8, %rax
	addq	$56, %rax
	movq	%rax, %rdx
	movq	$119, %rax
	movq	%rdx, %rcx
	movq	%rax, (%rcx)
	movq	(%r11), %rdi
	pushq	%r11
	callq	string_of_array
	popq	%r11
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	callq	print_string
	popq	%rdi
	popq	%r11
	leaq	_str_arr2868(%rip), %rax
	addq	$0, %rax
	addq	$0, %rax
	movq	%rax, %rdi
	pushq	%r11
	pushq	%rdi
	callq	print_string
	popq	%rdi
	popq	%r11
	movq	(%r11), %rdi
	pushq	%r11
	pushq	%rdi
	movq	$8, %rsi
	callq	bubble_sort
	popq	%rdi
	popq	%r11
	movq	(%r11), %rdi
	callq	string_of_array
	movq	%rax, %rdi
	pushq	%rdi
	callq	print_string
	popq	%rdi
	movq	$-1, %rax
	movq	%rbp, %rsp
	popq	%rbp
	retq	