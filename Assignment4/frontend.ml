open Ll
open Llutil
open Ast


let debug = false

(* instruction streams ------------------------------------------------------ *)

(* As in the last project, we'll be working with a flattened representation
   of LLVMlite programs to make emitting code easier. This version
   additionally makes it possible to emit elements will be gathered up and
   "hoisted" to specific parts of the constructed CFG
   - G of gid * Ll.gdecl: allows you to output global definitions in the middle
     of the instruction stream. You will find this useful for compiling string
     literals
   - E of uid * insn: allows you to emit an instruction that will be moved up
     to the entry block of the current function. This will be useful for 
     compiling local variable declarations
*)

type elt = 
  | L of Ll.lbl             (* block labels *)
  | I of uid * Ll.insn      (* instruction *)
  | T of Ll.terminator      (* block terminators *)
  | G of gid * Ll.gdecl     (* hoisted globals (usually strings) *)
  | E of uid * Ll.insn      (* hoisted entry block instructions *)

type stream = elt list
let ( >@ ) x y = y @ x (* append reversed lists *)
let ( >:: ) x y = y :: x (* cons onto a list *)

(* Lift a list of instructions to a stream *)
let lift : (uid * insn) list -> stream = List.rev_map (fun (x,i) -> I (x,i))

(* Added: *)
(* Helper function to print the stream *)
let rec print_stream_helper (s:stream) : unit = 
  match s with
  | [] -> ()
  | (L l)::t -> Printf.printf "L %s\n" l; print_stream t
  | (I (u, i))::t -> Printf.printf "I %s: %s\n" u (Llutil.string_of_insn i); print_stream t
  | (T t)::ts -> Printf.printf "T %s\n" (Llutil.string_of_terminator t); print_stream ts
  | (G (g, gd))::ts -> Printf.printf "G %s: %s\n" g (Llutil.string_of_gdecl gd); print_stream ts
  | (E (u, i))::ts -> Printf.printf "E %s: %s\n" u (Llutil.string_of_insn i); print_stream ts

let print_stream (s: stream) : unit =
  print_stream_helper List.rev s
  
(* *)

(* Build a CFG and collection of global variable definitions from a stream *)
let cfg_of_stream (code:stream) : Ll.cfg * (Ll.gid * Ll.gdecl) list  =
    let gs, einsns, insns, term_opt, blks = List.fold_left
      (fun (gs, einsns, insns, term_opt, blks) e ->
        match e with
        | L l ->
           begin match term_opt with
           | None -> 
              if (List.length insns) = 0 then (gs, einsns, [], None, blks)
              else failwith @@ Printf.sprintf "build_cfg: block labeled %s has\
                                               no terminator" l
           | Some term ->
              (gs, einsns, [], None, (l, {insns; term})::blks)
           end
        | T t  -> (gs, einsns, [], Some (Llutil.Parsing.gensym "tmn", t), blks)
        | I (uid,insn)  -> (gs, einsns, (uid,insn)::insns, term_opt, blks)
        | G (gid,gdecl) ->  ((gid,gdecl)::gs, einsns, insns, term_opt, blks)
        | E (uid,i) -> (gs, (uid, i)::einsns, insns, term_opt, blks)
      ) ([], [], [], None, []) code
    in
    match term_opt with
    | None -> failwith "build_cfg: entry block has no terminator" 
    | Some term -> 
       let insns = einsns @ insns in
       ({insns; term}, blks), gs


(* compilation contexts ----------------------------------------------------- *)

(* To compile OAT variables, we maintain a mapping of source identifiers to the
   corresponding LLVMlite operands. Bindings are added for global OAT variables
   and local variables that are in scope. *)

module Ctxt = struct

  type t = (Ast.id * (Ll.ty * Ll.operand)) list
  let empty = []

  (* Add a binding to the context *)
  let add (c:t) (id:id) (bnd:Ll.ty * Ll.operand) : t = (id,bnd)::c

  (* Lookup a binding in the context *)
  let lookup (id:Ast.id) (c:t) : Ll.ty * Ll.operand =
    List.assoc id c

  (* Lookup a function, fail otherwise *)
  let lookup_function (id:Ast.id) (c:t) : Ll.ty * Ll.operand =
    match List.assoc id c with
    | Ptr (Fun (args, ret)), g -> Ptr (Fun (args, ret)), g
    | _ -> failwith @@ id ^ " not bound to a function"

  let lookup_function_option (id:Ast.id) (c:t) : (Ll.ty * Ll.operand) option =
    try Some (lookup_function id c) with _ -> None

  (* Added:*)
  (* Print the context for debug *)
  let print_ctxt (c: t) : unit =
    let rec print_ctxt' (c: t) : unit =
      match c with
      | [] -> ()
      | (id, (ty, op))::t -> Printf.printf "%s: %s\n" id (Llutil.string_of_ty ty); print_ctxt' t
    in
    print_ctxt' c;
    flush stdout;
  (* *)
  
end

(* compiling OAT types ------------------------------------------------------ *)

(* The mapping of source types onto LLVMlite is straightforward. Booleans and ints
   are represented as the corresponding integer types. OAT strings are
   pointers to bytes (I8). Arrays are the most interesting type: they are
   represented as pointers to structs where the first component is the number
   of elements in the following array.

   The trickiest part of this project will be satisfying LLVM's rudimentary type
   system. Recall that global arrays in LLVMlite need to be declared with their
   length in the type to statically allocate the right amount of memory. The 
   global strings and arrays you emit will therefore have a more specific type
   annotation than the output of cmp_rty. You will have to carefully bitcast
   gids to satisfy the LLVM type checker.
*)

let rec cmp_ty : Ast.ty -> Ll.ty = function
  | Ast.TBool  -> I1
  | Ast.TInt   -> I64
  | Ast.TRef r -> Ptr (cmp_rty r)

and cmp_rty : Ast.rty -> Ll.ty = function
  | Ast.RString  -> I8
  | Ast.RArray u -> Struct [I64; Array(0, cmp_ty u)]
  | Ast.RFun (ts, t) -> 
      let args, ret = cmp_fty (ts, t) in
      Fun (args, ret)

and cmp_ret_ty : Ast.ret_ty -> Ll.ty = function
  | Ast.RetVoid  -> Void
  | Ast.RetVal t -> cmp_ty t

and cmp_fty (ts, r) : Ll.fty =
  List.map cmp_ty ts, cmp_ret_ty r

let typ_of_binop : Ast.binop -> Ast.ty * Ast.ty * Ast.ty = function
  | Add | Mul | Sub | Shl | Shr | Sar | IAnd | IOr -> (TInt, TInt, TInt)
  | Eq | Neq | Lt | Lte | Gt | Gte -> (TInt, TInt, TBool)
  | And | Or -> (TBool, TBool, TBool)

let typ_of_unop : Ast.unop -> Ast.ty * Ast.ty = function
  | Neg | Bitnot -> (TInt, TInt)
  | Lognot       -> (TBool, TBool)

(* Compiler Invariants

   The LLVM IR type of a variable (whether global or local) that stores an Oat
   array value (or any other reference type, like "string") will always be a
   double pointer.  In general, any Oat variable of Oat-type t will be
   represented by an LLVM IR value of type Ptr (cmp_ty t).  So the Oat variable
   x : int will be represented by an LLVM IR value of type i64*, y : string will
   be represented by a value of type i8**, and arr : int[] will be represented
   by a value of type {i64, [0 x i64]}**.  Whether the LLVM IR type is a
   "single" or "double" pointer depends on whether t is a reference type.

   We can think of the compiler as paying careful attention to whether a piece
   of Oat syntax denotes the "value" of an expression or a pointer to the
   "storage space associated with it".  This is the distinction between an
   "expression" and the "left-hand-side" of an assignment statement.  Compiling
   an Oat variable identifier as an expression ("value") does the load, so
   cmp_exp called on an Oat variable of type t returns (code that) generates a
   LLVM IR value of type cmp_ty t.  Compiling an identifier as a left-hand-side
   does not do the load, so cmp_lhs called on an Oat variable of type t returns
   and operand of type (cmp_ty t)*.  Extending these invariants to account for
   array accesses: the assignment e1[e2] = e3; treats e1[e2] as a
   left-hand-side, so we compile it as follows: compile e1 as an expression to
   obtain an array value (which is of pointer of type {i64, [0 x s]}* ).
   compile e2 as an expression to obtain an operand of type i64, generate code
   that uses getelementptr to compute the offset from the array value, which is
   a pointer to the "storage space associated with e1[e2]".

   On the other hand, compiling e1[e2] as an expression (to obtain the value of
   the array), we can simply compile e1[e2] as a left-hand-side and then do the
   load.  So cmp_exp and cmp_lhs are mutually recursive.  [[Actually, as I am
   writing this, I think it could make sense to factor the Oat grammar in this
   way, which would make things clearer, I may do that for next time around.]]

 
   Consider globals7.oat

   /--------------- globals7.oat ------------------ 
   global arr = int[] null;

   int foo() { 
     var x = new int[3]; 
     arr = x; 
     x[2] = 3; 
     return arr[2]; 
   }
   /------------------------------------------------

   The translation (given by cmp_ty) of the type int[] is {i64, [0 x i64}* so
   the corresponding LLVM IR declaration will look like:

   @arr = global { i64, [0 x i64] }* null

   This means that the type of the LLVM IR identifier @arr is {i64, [0 x i64]}**
   which is consistent with the type of a locally-declared array variable.

   The local variable x would be allocated and initialized by (something like)
   the following code snippet.  Here %_x7 is the LLVM IR uid containing the
   pointer to the "storage space" for the Oat variable x.

   %_x7 = alloca { i64, [0 x i64] }*                              ;; (1)
   %_raw_array5 = call i64*  @oat_alloc_array(i64 3)              ;; (2)
   %_array6 = bitcast i64* %_raw_array5 to { i64, [0 x i64] }*    ;; (3)
   store { i64, [0 x i64]}* %_array6, { i64, [0 x i64] }** %_x7   ;; (4)

   (1) note that alloca uses cmp_ty (int[]) to find the type, so %_x7 has 
       the same type as @arr 

   (2) @oat_alloc_array allocates len+1 i64's 

   (3) we have to bitcast the result of @oat_alloc_array so we can store it
        in %_x7 

   (4) stores the resulting array value (itself a pointer) into %_x7 

  The assignment arr = x; gets compiled to (something like):

  %_x8 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_x7     ;; (5)
  store {i64, [0 x i64] }* %_x8, { i64, [0 x i64] }** @arr       ;; (6)

  (5) load the array value (a pointer) that is stored in the address pointed 
      to by %_x7 

  (6) store the array value (a pointer) into @arr 

  The assignment x[2] = 3; gets compiled to (something like):

  %_x9 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** %_x7      ;; (7)
  %_index_ptr11 = getelementptr { i64, [0 x  i64] }, 
                  { i64, [0 x i64] }* %_x9, i32 0, i32 1, i32 2   ;; (8)
  store i64 3, i64* %_index_ptr11                                 ;; (9)

  (7) as above, load the array value that is stored %_x7 

  (8) calculate the offset from the array using GEP

  (9) store 3 into the array

  Finally, return arr[2]; gets compiled to (something like) the following.
  Note that the way arr is treated is identical to x.  (Once we set up the
  translation, there is no difference between Oat globals and locals, except
  how their storage space is initially allocated.)

  %_arr12 = load { i64, [0 x i64] }*, { i64, [0 x i64] }** @arr    ;; (10)
  %_index_ptr14 = getelementptr { i64, [0 x i64] },                
                 { i64, [0 x i64] }* %_arr12, i32 0, i32 1, i32 2  ;; (11)
  %_index15 = load i64, i64* %_index_ptr14                         ;; (12)
  ret i64 %_index15

  (10) just like for %_x9, load the array value that is stored in @arr 

  (11)  calculate the array index offset

  (12) load the array value at the index 

*)

(* Global initialized arrays:

  There is another wrinkle: To compile global initialized arrays like in the
  globals4.oat, it is helpful to do a bitcast once at the global scope to
  convert the "precise type" required by the LLVM initializer to the actual
  translation type (which sets the array length to 0).  So for globals4.oat,
  the arr global would compile to (something like):

  @arr = global { i64, [0 x i64] }* bitcast 
           ({ i64, [4 x i64] }* @_global_arr5 to { i64, [0 x i64] }* ) 
  @_global_arr5 = global { i64, [4 x i64] } 
                  { i64 4, [4 x i64] [ i64 1, i64 2, i64 3, i64 4 ] }

*) 



(* Some useful helper functions *)

(* Generate a fresh temporary identifier. Since OAT identifiers cannot begin
   with an underscore, these should not clash with any source variables *)
let gensym : string -> string =
  let c = ref 0 in
  fun (s:string) -> incr c; Printf.sprintf "_%s%d" s (!c)

(* Amount of space an Oat type takes when stored in the satck, in bytes.  
   Note that since structured values are manipulated by reference, all
   Oat values take 8 bytes on the stack.
*)
let size_oat_ty (t : Ast.ty) = 8L

(* Generate code to allocate a zero-initialized array of source type TRef (RArray t) of the
   given size. Note "size" is an operand whose value can be computed at
   runtime *)
let oat_alloc_array (t:Ast.ty) (size:Ll.operand) : Ll.ty * operand * stream =
  let ans_id, arr_id = gensym "array", gensym "raw_array" in
  let ans_ty = cmp_ty @@ TRef (RArray t) in
  let arr_ty = Ptr I64 in
  ans_ty, Id ans_id, lift
    [ arr_id, Call(arr_ty, Gid "oat_alloc_array", [I64, size])
    ; ans_id, Bitcast(arr_ty, Id arr_id, ans_ty) ]



(* Added: *)
let str_arr_ty s = Array(1 + String.length s, I8)
(* *)

(* Compiles an expression exp in context c, outputting the Ll operand that will
   recieve the value of the expression, and the stream of instructions
   implementing the expression. 

   Tips:
   - use the provided cmp_ty function!

   - string literals (CStr s) should be hoisted. You'll need to make sure
     either that the resulting gid has type (Ptr I8), or, if the gid has type
     [n x i8] (where n is the length of the string), convert the gid to a 
     (Ptr I8), e.g., by using getelementptr.

   - use the provided "oat_alloc_array" function to implement literal arrays
     (CArr) and the (NewArr) expressions

*)



(* Added: *)

let map_binop (bnp : Ast.binop) : Ll.bop  =
  match bnp with
  | Ast.Add  -> Ll.Add
  | Ast.Sub  -> Ll.Sub
  | Ast.Mul  -> Ll.Mul
  | Ast.And  -> Ll.And
  | Ast.Or   -> Ll.Or
  | Ast.IAnd -> Ll.And
  | Ast.IOr  -> Ll.Or
  | Ast.Shl  -> Ll.Shl
  | Ast.Shr  -> Ll.Lshr
  | Ast.Sar  -> Ll.Ashr
  | _ -> failwith "cant reach here in map_binop"

let map_cnd (cnd : Ast.binop) : Ll.cnd  =
  match cnd with
  | Ast.Eq   -> Ll.Eq
  | Ast.Neq  -> Ll.Ne
  | Ast.Lt   -> Ll.Slt
  | Ast.Lte  -> Ll.Sle
  | Ast.Gt   -> Ll.Sgt
  | Ast.Gte  -> Ll.Sge
  | _ -> failwith "cant reach here in map_cnd"


let is_cnd bnp : bool =
   begin match bnp with
     | Ast.Eq | Ast.Neq | Ast.Lt | Ast.Lte | Ast.Gt | Ast.Gte -> true
     | _ -> false
   end

(**)






let rec cmp_exp (c:Ctxt.t) (exp:Ast.exp node) : Ll.ty * Ll.operand * stream =

  if debug then begin
    Printf.printf "-------- Compiling expression: -----------\n";
    Astlib.print_exp exp;
  end;

  (* Added: *)
  match exp.elt with
  | Ast.CInt i  -> I64, Const i, []
  | Ast.CNull t -> Ptr (cmp_rty t), Null, []               
  | Ast.Bop (bin_op, exp_n1, exp_n2) ->
    (* 1. Return Ll.ty *)
    let _, _, ret_ty = typ_of_binop bin_op in
    let ll_ret_ty = cmp_ty ret_ty in
    (* 2. Return Ll.operand *)
    let ret_id = gensym "bop" in
    let ll_op = Ll.Id ret_id in
  
    (* 3. Return stream *)
    let ty1, op1, stream1 = cmp_exp c exp_n1 in
    let ty2, op2, stream2 = cmp_exp c exp_n2 in
    
    let insn = if (is_cnd bin_op) 
    then (Ll.Icmp ((map_cnd bin_op), ty1, op1, op2))
    else (Ll.Binop (map_binop bin_op, ty1, op1, op2)) in
  
    let stream3 = [I(ret_id, insn)] in
    let stream: stream = stream3 @ stream2 @ stream1 in
    (*returns a treble*)
    ll_ret_ty, ll_op, stream 
     
  | Ast.Uop (unop, exp_n) ->
    (*1. Return Ll.t*)
    let _, ret_ty = typ_of_unop unop in
    let ll_ret_ty: Ll.ty = cmp_ty ret_ty in
    (* 2. Return Ll.operand *)
    let ret_id = gensym "uop" in
    let ll_opnd: Ll.operand = Ll.Id ret_id in
    (* 3. Return stream *)
    let _ , opnd, stream1 = cmp_exp c exp_n in
    let stream2 = match unop with
      | Ast.Neg    -> [I (ret_id, Binop (Mul, I64, Ll.Const (Int64.of_int (-1)), opnd))]
      | Ast.Lognot -> [I (ret_id, Icmp  (Eq, I1, opnd, Ll.Const 0L))]
      | Ast.Bitnot ->  [I (ret_id, Binop (Xor, I64, opnd, Ll.Const (Int64.of_int (-1))))] in
    let stream = stream2 @ stream1 in
    ll_ret_ty, ll_opnd, stream
  | Ast.Id id ->
    let ty, op = Ctxt.lookup id c in
    let uid = gensym "uid" in
    begin match ty with
    | Ptr (Array (n, ty)) -> Ptr (ty), Id(uid), [I(uid, Bitcast (Ptr (Array (n, ty)), op, Ptr(ty)))]
    | Ptr t -> t, Ll.Id uid, [I (uid, Ll.Load (ty, op))]
    | _ -> ty, op, []
    end
  | Ast.Index (e1, e2) -> 
    let arr_ty, arr_op, arr_stream = cmp_exp c e1 in 
    let _, idx_op, idx_stream = cmp_exp c e2 in 
    begin match arr_ty with
    | Ptr(Struct [_; Array(_, ty)]) ->
      let id = gensym "gep" in
      let ptr_id = gensym "ptr" in
      ty, Ll.Id id, arr_stream >@ idx_stream >@ [I (ptr_id, Ll.Gep (arr_ty, arr_op, [Ll.Const 0L; Ll.Const 1L; idx_op]))] >@ [I (id, Load(Ptr(ty), Id ptr_id))]
    | _ -> failwith (Printf.sprintf "unexpected type %s" (Llutil.string_of_ty arr_ty))
    end                                                                                                               
  | Ast.CBool b -> Ll.I1, Ll.Const (if b then 1L else 0L), []
  | Ast.CStr s ->
    let ret_ty = cmp_ty (TRef (RString)) in
    let gid = gensym "str" in
    let uid = gensym "wow" in
    let ty = str_arr_ty s in
    let gdecl = ty, GString s in
    let strm = [I (uid, Bitcast (Ll.Ptr ty, Gid gid, Ll.Ptr I8))] >@ [G (gid, gdecl)] in
    ret_ty, Ll.Id uid, strm
  | Ast.Call(exp_node, exp_node_lst) -> cmp_call c exp_node exp_node_lst
  | Ast.NewArr (t, e) -> 
    let _, e_opnd, e_stream = cmp_exp c e in
    let arr_ty, arr_opnd, arr_stream = oat_alloc_array t e_opnd in
    arr_ty, arr_opnd, e_stream >@ arr_stream
  | Ast.CArr (t, e_list) ->
    let size = List.length e_list in
    let size_op = Const (Int64.of_int size) in
    let (array_ty, array_op, array_s) = oat_alloc_array t size_op in
    let rec cmp_elements (els : Ast.exp node list) (i : int) : stream =
      match els with
      | [] -> []
      | e :: rest ->
        let (element_ty, element_op, element_s) = cmp_exp c e in
        let index = Const (Int64.of_int i) in
        let gep_var = gensym "gep_idx" in
        let gep_idx_ins = [I (gep_var, Gep (array_ty, array_op, [Const 0L; Const 1L; index]))] in
        let var = gensym "idx_carr" in
        let store = [I (var, (Store (element_ty, element_op, Ll.Id gep_var)))] in
        element_s >@ gep_idx_ins >@ store >@ cmp_elements rest (i + 1)
    in
    array_ty, array_op, array_s >@ cmp_elements e_list 0

  (* *)

(* Added: *)
and cmp_call (c:Ctxt.t) (exp_node:Ast.exp node) (exp_node_lst:Ast.exp node list) : Ll.ty * Ll.operand * stream =
  let id = match exp_node.elt with
    | Id(id') -> id'
    | _ -> "can only have expressions of type ID here" in
  let ptr_to_func, opnd = Ctxt.lookup id c in
  begin match ptr_to_func with
  | Ptr Fun(t_lst, ret_typ) ->
    let args_lst = ref [] in
    let stream_fin = ref [] in
    for i = 0 to (List.length exp_node_lst - 1) do
      let cur_arg = List.nth exp_node_lst i in
      let ty, op, stream = cmp_exp c cur_arg in
      args_lst := !args_lst @  [(ty, op)];
      stream_fin := !stream_fin @ stream;
    done;
    let id = gensym "call" in
    ret_typ, Id id, !stream_fin >@ [I(id, Call(ret_typ, opnd, !args_lst))]
  | _ -> failwith "need a pointer to a function for call"
  end

(* *)


(* Compile a statement in context c with return typ rt. Return a new context, 
   possibly extended with new local bindings, and the instruction stream
   implementing the statement.

   Left-hand-sides of assignment statements must either be OAT identifiers,
   or an index into some arbitrary expression of array type. Otherwise, the
   program is not well-formed and your compiler may throw an error.

   Tips:
   - for local variable declarations, you will need to emit Allocas in the
     entry block of the current function using the E() constructor.

   - don't forget to add a bindings to the context for local variable 
     declarations
   
   - you can avoid some work by translating For loops to the corresponding
     While loop, building the AST and recursively calling cmp_stmt

   - you might find it helpful to reuse the code you wrote for the Call
     expression to implement the SCall statement

   - compiling the left-hand-side of an assignment is almost exactly like
     compiling the Id or Index expression. Instead of loading the resulting
     pointer, you just need to store to it!

 *)

let rec cmp_stmt (c:Ctxt.t) (rt:Ll.ty) (stmt:Ast.stmt node) : Ctxt.t * stream =

  (* Added: *)
  if debug then begin
    Printf.printf "-------- Compiling statement: -----------\n";
    Astlib.print_stmt stmt;
  end;
  (* Added: *)
  match stmt.elt with
  | Ast.Ret r -> 
    begin match r with
    | None -> c, [T (Ret(Void, None))]
    | Some s -> 
      let ty, op, stream = cmp_exp c s in
      c, T(Ret (rt, Some op)) :: stream 
    end
  | Ast.Decl vdecl -> 
    let id, exp_node = vdecl in
    let ty, opnd, stream = cmp_exp c exp_node in
    let uid = gensym id in
    let c' = Ctxt.add c id (Ptr ty, Ll.Id uid) in
    (c', stream >@ [E (uid, Ll.Alloca ty)] >@ [I ("", Ll.Store (ty, opnd, Ll.Id uid))])
  | Ast.If (e, stmt_lst_1, stmt_lst_2) ->
    begin
      let lbl1 = gensym "then" in
      let lbl2 = gensym "else" in
      let lbl3 = gensym "end" in
      let c', op, stream = cmp_exp c e in
      let c, then_s = cmp_block c rt stmt_lst_1 in
      let c, else_s = cmp_block c rt stmt_lst_2 in
      let cnd_stream = [T (Cbr (op, lbl1, lbl2))] in
      let end_s =  [T(Br lbl3)] in
      let then_s' =  end_s @ then_s @ [L (lbl1)] in
      let else_s' = end_s @ else_s @ [L (lbl2)] in
      let cmb_stream =  [L(lbl3)] @ else_s' @ then_s' @ cnd_stream @ stream in
      c, cmb_stream
    end 
  | Ast.Assn(exp_node1, exp_node2) ->
    let ty2, opnd2, stream2 = cmp_exp c exp_node2 in
    let exp1 = exp_node1.elt in
    begin match exp1 with
    | Id(id) -> 
      let _, opnd = Ctxt.lookup id c in
      c, stream2 >@ [I("", Store(ty2, opnd2, opnd))]
    | Index(e1, e2) ->
      let arr_ty, arr_opnd, arr_strm = cmp_exp c e1 in
      let _, idx_opnd, idx_strm = cmp_exp c e2 in
      begin match arr_ty with
      | Ptr(Struct [_; Array (_,ty)]) ->
          let uid = gensym "" in
          let gep_ins = Gep(arr_ty, arr_opnd, [Const 0L; Const 1L; idx_opnd]) in
          let store_ins = Store(ty2, opnd2, Id uid) in
          c, stream2 >@ arr_strm >@ idx_strm >:: I(uid, gep_ins) >:: I(gensym "", store_ins)
      | _ -> failwith "expected a Ptr to an Array"
      end
    | _ -> failwith "assignment cannot take this type"
    end
  | Ast.While (exp_node, stmt_node_lst) ->
    let while_stmt = gensym "is_true" in
    let do_stmt = gensym "do_sth" in
    let end_stmt = gensym "end" in
    let ty, opnd, cond_stream = cmp_exp c exp_node in
    let c, do_stream = cmp_block c rt stmt_node_lst  in
    let start_str = [T (Br while_stmt)] in
    let while_str = [L while_stmt] >@ cond_stream in
    let branch_str = [ T (Cbr (opnd, do_stmt, end_stmt))] in
    let do_str = [L do_stmt] >@ do_stream  >:: T (Br while_stmt) in
    let end_str = [L end_stmt] in
    let combined = start_str >@ while_str >@ branch_str >@ do_str >@ end_str in
    c, combined
  | Ast.SCall (e_node, e_node_lst) ->
    let _, _, stream = cmp_call c e_node e_node_lst in
    c, stream
  | Ast.For (vdecl_lst, e_node_opt, stmt_node_opt, stmt_node_lst) ->
    let e_node_opt =
      match e_node_opt with
      | Some e -> e
      | None -> no_loc (CBool true)
    in
    let stmt_node_opt =
      match stmt_node_opt with
      | Some stmt -> [stmt]
      | None -> []
    in
    let vd = List.map (fun x -> no_loc (Decl x)) vdecl_lst in
    let c, v_strm = cmp_block c rt vd in
    let c, main_strm = cmp_stmt c rt {elt = (While(e_node_opt, (stmt_node_lst @ stmt_node_opt))); loc = stmt.loc} in
    c, v_strm >@ main_strm
  (* *)


(* Compile a series of statements *)
and cmp_block (c:Ctxt.t) (rt:Ll.ty) (stmts:Ast.block) : Ctxt.t * stream =
  List.fold_left (fun (c, code) s -> 
      let c, stmt_code = cmp_stmt c rt s in
      c, code >@ stmt_code
    ) (c,[]) stmts



(* Adds each function identifer to the context at an
   appropriately translated type.  

   NOTE: The Gid of a function is just its source name
*)
let cmp_function_ctxt (c:Ctxt.t) (p:Ast.prog) : Ctxt.t =
    List.fold_left (fun c -> function
      | Ast.Gfdecl { elt={ frtyp; fname; args } } ->
         let ft = TRef (RFun (List.map fst args, frtyp)) in
         Ctxt.add c fname (cmp_ty ft, Gid fname)
      | _ -> c
    ) c p 

(* Populate a context with bindings for global variables 
   mapping OAT identifiers to LLVMlite gids and their types.

   Only a small subset of OAT expressions can be used as global initializers
   in well-formed programs. (The constructors starting with C). 
*)
let cmp_global_ctxt (c:Ctxt.t) (p:Ast.prog) : Ctxt.t =
  (* Added: *)
  List.fold_left (fun c -> function
  | Ast.Gvdecl { elt= {name; init} } ->
     let cmpd_ty = match init.elt with
       | CBool _ -> cmp_ty Ast.TBool (* returns I1 *)
       | CInt _ -> cmp_ty Ast.TInt (* returns I64 *)
       | CStr _ -> cmp_ty (Ast.TRef RString) (* returns Ptr I8 *)
       | CNull n -> cmp_ty (Ast.TRef n)
       | CArr (ty, cs) -> cmp_ty (TRef (RArray ty)) (*Ptr (Struct [I64; Array(0, cmp_ty ty)])*)
       | _ -> failwith "expression cannot be used as a global initializer" in
      if debug then begin 
        Printf.printf "Global variable %s has type %s\n" name (Llutil.string_of_ty cmpd_ty);
        flush stdout
      end;
      Ctxt.add c name (Ptr(cmpd_ty), Gid name)
  | _ -> c) c p
  (* *)

(* Compile a function declaration in global context c. Return the LLVMlite cfg
   and a list of global declarations containing the string literals appearing
   in the function.

   You will need to
   1. Allocate stack space for the function parameters using Alloca
   2. Store the function arguments in their corresponding alloca'd stack slot
   3. Extend the context with bindings for function variables
   4. Compile the body of the function using cmp_block
   5. Use cfg_of_stream to produce a LLVMlite cfg from 
 *)


let cmp_fdecl (c:Ctxt.t) (f:Ast.fdecl node) : Ll.fdecl * (Ll.gid * Ll.gdecl) list =
  (* Added: *)
  (* Allocate stack space for the function parameters using Alloca *)
  let ctxt, arg_code = 
  List.fold_left (fun (ctxt, code) (ty, id) ->
    let alloca_id = gensym "alloca_fdecl" in
    let alloca_inst = (alloca_id, Ll.Alloca (cmp_ty ty)) in
    let operand = Ll.Id id in
    let alloca_operand = Ll.Id alloca_id in
    let store_inst = (gensym "store_fdecl", Ll.Store (cmp_ty ty, operand, alloca_operand)) in
    let new_ctxt = Ctxt.add ctxt id (Ptr(cmp_ty ty), Ll.Id alloca_id) in
    (new_ctxt, code >@ lift (alloca_inst :: [store_inst]))
  ) (c, []) f.elt.args
in
  
  (* Compile the body of the function using cmp_block *)
  let ctxt, body_code = cmp_block ctxt (cmp_ret_ty f.elt.frtyp) f.elt.body in

  (* Combine store_params with body_code *)
  let full_body_code = arg_code >@ body_code in

  (* Use cfg_of_stream to produce a LLVMlite cfg and globals from full_body_code *)
  let f_cfg, globals_vars = cfg_of_stream full_body_code in

  (* Compile function type and parameter list *)
  let arg_types = List.map fst f.elt.args in
  let f_ty = cmp_fty (arg_types, f.elt.frtyp) in
  let f_param = List.map snd f.elt.args in

  { f_ty; f_param; f_cfg }, globals_vars
  (* *)

(* Compile a global initializer, returning the resulting LLVMlite global
   declaration, and a list of additional global declarations.

   Tips:
   - Only CNull, CBool, CInt, CStr, and CArr can appear as global initializers
     in well-formed OAT programs. Your compiler may throw an error for the other
     cases

   - OAT arrays are always handled via pointers. A global array of arrays will
     be an array of pointers to arrays emitted as additional global declarations.
*)

let rec cmp_gexp c (e:Ast.exp node) : Ll.gdecl * (Ll.gid * Ll.gdecl) list =
  (* Added: *)
  match e.elt with
  | CNull t -> (cmp_ty (Ast.TRef t), GNull), [] 
  | CStr s ->
    let gid = gensym "global_str" in
    let ll_ty = str_arr_ty s in
    let cast = GBitcast (Ptr ll_ty, GGid gid, Ptr I8) in
    (Ptr I8, cast), [gid, (ll_ty, GString s)]
    (*(Array(1 + (String.length s), I8), GString s), []*)
  | CBool b -> (Ll.I1, GInt(if b then 1L else 0L)), []
  | CInt i -> (Ll.I64, Ll.GInt i),[]
  | CArr (t, exp_list) ->
    let gid = gensym "global_arr" in
    let ty = Array(List.length exp_list, cmp_ty t) in
    let el_ty = cmp_ty (TRef (RArray t)) in
    let comp_exp_list = List.map (fun exp_node -> cmp_gexp c exp_node) exp_list in
    let ginit = List.map fst comp_exp_list in
    let cast = GBitcast (Ptr (Struct [I64; ty]), GGid gid, el_ty) in
    (el_ty, cast), [gid, (Struct[I64; ty], GStruct [I64, GInt (Int64.of_int (List.length exp_list)); ty, GArray ginit])]
  | _ -> failwith "this cannot appear as a global initializer"
  (* *)



(* Oat internals function context ------------------------------------------- *)
let internals = [
    "oat_alloc_array",         Ll.Fun ([I64], Ptr I64)
  ]

(* Oat builtin function context --------------------------------------------- *)
let builtins =
  [ "array_of_string",  cmp_rty @@ RFun ([TRef RString], RetVal (TRef(RArray TInt)))
  ; "string_of_array",  cmp_rty @@ RFun ([TRef(RArray TInt)], RetVal (TRef RString))
  ; "length_of_string", cmp_rty @@ RFun ([TRef RString],  RetVal TInt)
  ; "string_of_int",    cmp_rty @@ RFun ([TInt],  RetVal (TRef RString))
  ; "string_cat",       cmp_rty @@ RFun ([TRef RString; TRef RString], RetVal (TRef RString))
  ; "print_string",     cmp_rty @@ RFun ([TRef RString],  RetVoid)
  ; "print_int",        cmp_rty @@ RFun ([TInt],  RetVoid)
  ; "print_bool",       cmp_rty @@ RFun ([TBool], RetVoid)
  ]

(* Compile a OAT program to LLVMlite *)
let cmp_prog (p:Ast.prog) : Ll.prog =
  (* Added: *)

  (* compile the program *)

  (* add built-in functions to context *)
  let init_ctxt = 
    List.fold_left (fun c (i, t) -> Ctxt.add c i (Ll.Ptr t, Gid i))
      Ctxt.empty builtins
  in

  let fc = cmp_function_ctxt init_ctxt p in

  (* build global variable context *)
  let c = cmp_global_ctxt fc p in

  (* Print the global context *)
  if debug then begin
    Printf.printf "-------- Global context: -----------\n";
    Ctxt.print_ctxt c;
  end;

  (* compile functions and global variables *)
  let fdecls, gdecls = 
    List.fold_right (fun d (fs, gs) ->
        match d with
        | Ast.Gvdecl { elt=gd } -> 
           let ll_gd, gs' = cmp_gexp c gd.init in
           (fs, (gd.name, ll_gd)::gs' @ gs)
        | Ast.Gfdecl fd ->
           let fdecl, gs' = cmp_fdecl c fd in
           (fd.elt.fname,fdecl)::fs, gs' @ gs
      ) p ([], [])
  in

  (* gather external declarations *)
  let edecls = internals @ builtins in
  { tdecls = []; gdecls; fdecls; edecls }
