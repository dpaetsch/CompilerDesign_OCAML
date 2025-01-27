open Ast
open Astlib
open Tctxt

(* Error Reporting ---------------------------------------------------------- *)
(* NOTE: Use type_error to report error messages for ill-typed programs. *)

exception TypeError of string

let type_error (l : 'a node) err = 
  let (_, (s, e), _) = l.loc in
  raise (TypeError (Printf.sprintf "[%d, %d] %s" s e err))


(* initial context: G0 ------------------------------------------------------ *)
(* The Oat types of the Oat built-in functions *)
let builtins =
  [ "array_of_string",  ([TRef RString],  RetVal (TRef(RArray TInt)))
  ; "string_of_array",  ([TRef(RArray TInt)], RetVal (TRef RString))
  ; "length_of_string", ([TRef RString],  RetVal TInt)
  ; "string_of_int",    ([TInt], RetVal (TRef RString))
  ; "string_cat",       ([TRef RString; TRef RString], RetVal (TRef RString))
  ; "print_string",     ([TRef RString],  RetVoid)
  ; "print_int",        ([TInt], RetVoid)
  ; "print_bool",       ([TBool], RetVoid)
  ]

(* binary operation types --------------------------------------------------- *)
let typ_of_binop : Ast.binop -> Ast.ty * Ast.ty * Ast.ty = function
  | Add | Mul | Sub | Shl | Shr | Sar | IAnd | IOr -> (TInt, TInt, TInt)
  | Lt | Lte | Gt | Gte -> (TInt, TInt, TBool)
  | And | Or -> (TBool, TBool, TBool)
  | Eq | Neq -> failwith "typ_of_binop called on polymorphic == or !="

(* unary operation types ---------------------------------------------------- *)
let typ_of_unop : Ast.unop -> Ast.ty * Ast.ty = function
  | Neg | Bitnot -> (TInt, TInt)
  | Lognot       -> (TBool, TBool)

(* subtyping ---------------------------------------------------------------- *)
(* Decides whether H |- t1 <: t2 
    - assumes that H contains the declarations of all the possible struct types

    - you will want to introduce addition (possibly mutually recursive) 
      helper functions to implement the different judgments of the subtyping
      relation. We have included a template for subtype_ref to get you started.
      (Don't forget about OCaml's 'and' keyword.)
*)
let rec subtype (c : Tctxt.t) (t1 : Ast.ty) (t2 : Ast.ty) : bool =
  (* failwith "todo: subtype" *)
  (* Added: *)
  match t1, t2 with 
  | TInt, TInt -> true 
  | TBool, TBool -> true 
  | TNullRef x, TNullRef y 
  | TRef x, TNullRef y 
  | TRef x, TRef y -> subtype_ref c x y 
  | _, _ -> false
  (* *)




(* Decides whether H |-r ref1 <: ref2 *)
and subtype_ref (c : Tctxt.t) (t1 : Ast.rty) (t2 : Ast.rty) : bool =
  (* failwith "todo: subtype_ref" *)
  (* Added: *)
  match t1, t2 with 
  | RString, RString -> true 
  | RArray at1, RArray at2 -> at1 = at2 
  | RFun (ts1, rt1), RFun (ts2, rt2) -> subtype_list c ts2 ts1 && subtype_ret c rt1 rt2 
  | RStruct id1, RStruct id2 -> id1 = id2 || subtype_fields c id1 id2 
  | _, _ -> false
and subtype_ret (c : Tctxt.t) (t1 : Ast.ret_ty) (t2 : Ast.ret_ty) : bool = 
  match t1, t2 with 
  | RetVoid, RetVoid -> true 
  | RetVal v1, RetVal v2 -> subtype c v1 v2 
  | _, _ -> false 
  
and subtype_list c l1 l2 : bool = 
  if List.length l1 != List.length l2 then false 
  else List.fold_left2 (fun a x y -> a && subtype c x y) true l1 l2 
  
(* fields n1 are a subtype of n2 if n2 is a prefix of n1 *) 
and subtype_fields c n1 n2 : bool = 
  let fields1 = Tctxt.lookup_struct n1 c in 
  let fields2 = Tctxt.lookup_struct n2 c in 
  let rec helper l1 l2 = 
    match (l1, l2) with 
    | _, [] -> true 
    | [], _ -> false 
    | f1::t1, f2::t2 -> f1.fieldName = f2.fieldName && f1.ftyp = f2.ftyp && helper t1 t2 in 
  helper fields1 fields2 
(* *)







(* well-formed types -------------------------------------------------------- *)
(* Implement a (set of) functions that check that types are well formed according
   to the H |- t and related inference rules

    - the function should succeed by returning () if the type is well-formed
      according to the rules

    - the function should fail using the "type_error" helper function if the 
      type is not well-formed

    - l is just an ast node that provides source location information for
      generating error messages (it's only needed for the type_error generation)

    - tc contains the structure definition context
 *)
let rec typecheck_ty (l : 'a Ast.node) (tc : Tctxt.t) (t : Ast.ty) : unit =
  (* failwith "todo: implement typecheck_ty" *)
  (* Added: *)
  begin match t with 
  | TBool -> () 
  | TInt -> () 
  | TNullRef r 
  | TRef r -> typecheck_ref l tc r end

  and typecheck_ref l tc (r:Ast.rty) : unit = 
    begin match r with 
    | RString -> () 
    | RStruct id -> if Tctxt.lookup_struct_option id tc = None then type_error l "Unbound struct type" else ()
    | RArray t -> typecheck_ty l tc t
    | RFun (tl, rt) -> (typecheck_ret l tc rt); List.iter (typecheck_ty l tc) tl
    end
  and typecheck_ret l tc (rt:Ast.ret_ty) : unit =
    begin match (rt:Ast.ret_ty) with
    | RetVoid -> ()
    | RetVal t -> typecheck_ty l tc t
    end
    
  (* *)



(* typechecking expressions ------------------------------------------------- *)
(* Typechecks an expression in the typing context c, returns the type of the
   expression.  This function should implement the inference rules given in the
   oad.pdf specification.  There, they are written:

       H; G; L |- exp : t

   See tctxt.ml for the implementation of the context c, which represents the
   four typing contexts: H - for structure definitions G - for global
   identifiers L - for local identifiers

   Returns the (most precise) type for the expression, if it is type correct
   according to the inference rules.

   Uses the type_error function to indicate a (useful!) error message if the
   expression is not type correct.  The exact wording of the error message is
   not important, but the fact that the error is raised, is important.  (Our
   tests also do not check the location information associated with the error.)

   Notes: - Structure values permit the programmer to write the fields in any
   order (compared with the structure definition).  This means that, given the
   declaration struct T { a:int; b:int; c:int } The expression new T {b=3; c=4;
   a=1} is well typed.  (You should sort the fields to compare them.)

*)
let rec typecheck_exp (c : Tctxt.t) (e : Ast.exp node) : Ast.ty =
  (* failwith "todo: implement typecheck_exp" *)
  (* Added: *)
  match e.elt with
  | CNull r -> TNullRef r
  | CBool b -> TBool
  | CInt i -> TInt
  | CStr s -> TRef RString
  | Id i ->
    begin match Tctxt.lookup_option i c with
    | Some x -> x
    | None -> type_error e ("Unbound identifier " ^ i)
    end

  | CArr (t, l) -> typecheck_ty e c t;
    let types_of = List.map (typecheck_exp c) l in
      if List.for_all (fun u -> subtype c u t) types_of then TRef (RArray t)
      else type_error e "Mismatched array type"

  | NewArr (t, e1, id, e2) -> typecheck_ty e c t;
    let size_type = typecheck_exp c e1 in
    if size_type = TInt then let tc' =
      if List.exists (fun x -> fst x = id) c.locals
      then type_error e1 "Cannot redeclare variable"
      else Tctxt.add_local c id TInt
      in
      let t' = typecheck_exp tc' e2 in
      if subtype c t' t then TRef (RArray t)
      else type_error e2 "Initializer has incorrect type"
    else type_error e1 "Array size not an int"

  | Bop (b, l, r) ->
    let ltyp = typecheck_exp c l in
    let rtyp = typecheck_exp c r in
    begin match b with
      | Eq | Neq -> if (subtype c ltyp rtyp) && (subtype c rtyp ltyp) then TBool
                    else type_error e "== or != used with non type-compatible arguments"
      | _ -> let (bl, br, bres) = typ_of_binop b in
             if bl = ltyp then
             if br = rtyp then bres
             else type_error r "Incorrect type in binary expression"
             else type_error l "Incorrect type in binary expression"
      end

  | Uop (u, e) ->
    let t = typecheck_exp c e in
    let (us, ures) = typ_of_unop u in
    if us = t then ures else type_error e "Incorrect type for unary operator"

  | Index (e1, e2) ->
    let arr_t = typecheck_exp c e1 in
    let ind_t = typecheck_exp c e2 in
    if ind_t = TInt then
      match arr_t with
      | TRef (RArray t) -> t
      | _ -> type_error e1 ("Tried to compute index into type " ^ (Astlib.string_of_ty arr_t))
    else type_error e2 "Index of array index operator not an int"

  | Proj (s, id) ->
    let str_t = typecheck_exp c s in
    (match str_t with
      | TRef (RStruct sn) -> 
        (match Tctxt.lookup_field_option sn id c with
          | None -> type_error e (id ^ " not member of struct " ^ sn)
          | Some t -> t)
      | _ -> type_error s "Cannot project from non-struct")
  | CStruct (id, l) ->
      (match Tctxt.lookup_struct_option id c with
      | None -> type_error e (id ^ "not a struct type")
      | Some x ->
        let tc_field (id, node) = id, typecheck_exp c node in
        let field_types = List.map tc_field l in
        let struct_names = List.sort compare (List.map (fun x -> x.fieldName) x)
        in
          let local_names = List.sort compare (List.map fst field_types) in
          if struct_names <> local_names
          then type_error e "Mismatch of fields between struct definition and local declaration";
          List.iter (fun (id, ft) ->
            let t = (List.find (fun i -> i.fieldName = id) x).ftyp in
            if not (subtype c ft t) then type_error e (id ^ " field of struct incorrect")
            else ()) field_types;
          TRef (RStruct id))
  | Length l ->
      let t = typecheck_exp c l in
      (match t with
      | TRef (RArray t) -> TInt
      | _ -> type_error l "Cannot take length of non-array")
  | Call (f, args) ->
      let argtyps = List.map (typecheck_exp c) args in
      match (typecheck_exp c f) with
      | TRef (RFun (l, RetVal r)) ->
        if List.length l <> List.length argtyps
        then type_error e "Incorrect number of arguments"
        else List.iter2
            (fun arg l ->
              if not (subtype c arg l) then type_error e "Incorrect type of argument")
            argtyps l;
          r
      | _ -> type_error e "Need function argument for function call"

(* *)


(* statements --------------------------------------------------------------- *)

(* Typecheck a statement 
   This function should implement the statement typechecking rules from oat.pdf.  

   Inputs:
    - tc: the type context
    - s: the statement node
    - to_ret: the desired return type (from the function declaration)

   Returns:
     - the new type context (which includes newly declared variables in scope
       after this statement
     - A boolean indicating the return behavior of a statement:
        false:  might not return
        true: definitely returns 

        in the branching statements, both branches must definitely return

        Intuitively: if one of the two branches of a conditional does not 
        contain a return statement, then the entier conditional statement might 
        not return.
  
        looping constructs never definitely return 

   Uses the type_error function to indicate a (useful!) error message if the
   statement is not type correct.  The exact wording of the error message is
   not important, but the fact that the error is raised, is important.  (Our
   tests also do not check the location information associated with the error.)

   - You will probably find it convenient to add a helper function that implements the 
     block typecheck rules.
*)
let rec typecheck_stmt (tc : Tctxt.t) (s:Ast.stmt node) (to_ret:ret_ty) : Tctxt.t * bool =
  (* failwith "todo: implement typecheck_stmt" *)
  (* Added: *)
  match s.elt with
    | Assn (e1, e2) ->
      let () = 
        begin match e1.elt with
          | Id x ->
            begin match Tctxt.lookup_local_option x tc with
              | Some _ -> ()
              | None ->
                begin match Tctxt.lookup_global_option x tc with
                  | Some TRef (RFun _) -> type_error s ("cannot assign to global function " ^ x)
                  | _ -> ()
                end
            end
          | _ -> ()
        end
        in
        let assn_to = typecheck_exp tc e1 in
        let assn_from = typecheck_exp tc e2 in
        if subtype tc assn_from assn_to then tc, false
        else type_error s "Mismatched types in assignment"

    | Decl (id, exp) ->
      let exp_type = typecheck_exp tc exp in
      if List.exists (fun x -> fst x = id) tc.locals then type_error s "Cannot redeclare variable"
      else Tctxt.add_local tc id exp_type, false

    | Ret r ->
      (match r, to_ret with
        | None, RetVoid -> tc, true
        | Some r, RetVal to_ret ->
          let t = typecheck_exp tc r in
          if subtype tc t to_ret then tc, true
          else type_error s "Returned incorrect type"   
        | None, RetVal to_ret -> type_error s "Returned void in non-void function"
        | Some r, RetVoid -> type_error s "Returned non-void in void function")

    | SCall (f, args) ->
      let argtyps = List.map (typecheck_exp tc) args in
      (match (typecheck_exp tc f) with
        | TNullRef (RFun (l, RetVoid)) | TRef (RFun (l, RetVoid)) ->
          if List.length l <> List.length argtyps then type_error s "Incorrect number of arguments"
          else List.iter2
              (fun arg l -> if not (subtype tc arg l) then type_error s "Incorrect type of argument") 
              argtyps l;
          tc, false
        | _ -> type_error s "Need function argument for function call")

      | If (e, b1, b2) ->
        let guard_type = typecheck_exp tc e in
        if guard_type <> TBool then type_error e "Incorrect type for guard"
        else
          let lft_ret = typecheck_block tc b1 to_ret in
          let rgt_ret = typecheck_block tc b2 to_ret in
          tc, lft_ret && rgt_ret

      | Cast (r, id, exp, b1, b2) ->
        let exp_type = typecheck_exp tc exp in
        begin match exp_type with
          | TNullRef r' ->
            if subtype_ref tc r' r then
              let lft_ret = typecheck_block (Tctxt.add_local tc id (TRef r)) b1 to_ret in
              let rgt_ret = typecheck_block tc b2 to_ret in
              tc, lft_ret && rgt_ret
            else type_error exp "if? expression not a subtype of declared type"
          | _ -> type_error exp "if? expression has non-? type"
          end
          
      | While (b, bl) ->
        let guard_type = typecheck_exp tc b in
        if guard_type <> TBool then type_error b "Incorrect type for guard"
        else
          let _ = typecheck_block tc bl to_ret in
          tc, false

      | For (vs, guard, s, b) ->
        let updated_context =
          List.fold_left (fun c (id, e) ->
            let t = typecheck_exp c e in
            Tctxt.add_local c id t) tc vs in
            let _ =
              begin match guard with
                | None -> ()
                | Some b ->
                  if TBool <> typecheck_exp updated_context b then type_error b "Incorrect type for guard"
                  else ()
              end in
            let _ =
              begin match s with
                | None -> ()
                | Some s ->
                  let (nc, rt) = typecheck_stmt updated_context s to_ret in
                    if rt then type_error s "Cannot return in for loop increment"
              end in
          let _ = typecheck_block updated_context b to_ret in
          tc, false
(* *)

(* Added helper: *)
and typecheck_block (tc : Tctxt.t) (b : Ast.block) (to_ret : Ast.ret_ty) : bool =
  match b with
    | [] -> false
    | [h] -> let c, r = typecheck_stmt tc h to_ret in r
    | h1 :: h2 :: t ->
        let new_context, r = typecheck_stmt tc h1 to_ret in
        if r then type_error h2 "Dead code"
        else typecheck_block new_context (h2 :: t) to_ret
(* *)



(* struct type declarations ------------------------------------------------- *)
(* Here is an example of how to implement the TYP_TDECLOK rule, which is 
   is needed elswhere in the type system.
 *)

(* Helper function to look for duplicate field names *)
let rec check_dups fs =
  match fs with
  | [] -> false
  | h :: t -> (List.exists (fun x -> x.fieldName = h.fieldName) t) || check_dups t

let typecheck_tdecl (tc : Tctxt.t) id fs  (l : 'a Ast.node) : unit =
  if check_dups fs
  then type_error l ("Repeated fields in " ^ id) 
  else List.iter (fun f -> typecheck_ty l tc f.ftyp) fs

(* function declarations ---------------------------------------------------- *)
(* typecheck a function declaration 
    - extends the local context with the types of the formal parameters to the 
      function
    - typechecks the body of the function (passing in the expected return type
    - checks that the function actually returns
*)
let typecheck_fdecl (tc : Tctxt.t) (f : Ast.fdecl) (l : 'a Ast.node) : unit =
  (* failwith "todo: typecheck_fdecl" *)
  (* Added: *)
  let updated = List.fold_left (fun c (t, i) -> Tctxt.add_local c i t) tc f.args in 
  let returned = typecheck_block updated f.body f.frtyp in 
  if not returned then type_error l "Need return statement"
  (* *)  

(* creating the typchecking context ----------------------------------------- *)

(* The following functions correspond to the
   judgments that create the global typechecking context.

   create_struct_ctxt: - adds all the struct types to the struct 'H'
   context (checking to see that there are no duplicate fields

     H |-s prog ==> H'


   create_function_ctxt: - adds the the function identifiers and their
   types to the 'G' context (ensuring that there are no redeclared
   function identifiers)

     H ; G1 |-f prog ==> G2


   create_global_ctxt: - typechecks the global initializers and adds
   their identifiers to the 'G' global context

     H ; G1 |-g prog ==> G2    


   NOTE: global initializers may mention function identifiers as
   constants, but can't mention other global values *)

let create_struct_ctxt (p:Ast.prog) : Tctxt.t =
  (* failwith "todo: create_struct_ctxt" *)
  (* Added: *)
  List.fold_left (fun c d ->
    match d with
      | Gtdecl ({elt=(id, fs)} as l) ->
        if List.exists (fun x -> id = fst x) c.structs then type_error l ("Redeclaration of struct " ^ id)
        else Tctxt.add_struct c id fs
      | _ -> c) Tctxt.empty p
  (* *)

let create_function_ctxt (tc:Tctxt.t) (p:Ast.prog) : Tctxt.t =
  (* failwith "todo: create_function_ctxt" *)
  (* Added: *)
  let builtins_context =
    List.fold_left
      (fun c (id, (args, ret)) -> Tctxt.add_global c id (TRef (RFun(args,ret))))
      tc builtins
    in
      List.fold_left (fun c d ->
        match d with
          | Gfdecl ({elt=f} as l) ->
            if List.exists (fun x -> fst x = f.fname) c.globals
            then type_error l ("Redeclaration of " ^ f.fname)
            else Tctxt.add_global c f.fname (TRef (RFun(List.map fst f.args, f.frtyp)))
          | _ -> c) builtins_context p
  (*  *)

let create_global_ctxt (tc:Tctxt.t) (p:Ast.prog) : Tctxt.t =
  (* failwith "todo: create_function_ctxt" *)
  (* Added: *)
  List.fold_left (fun c d ->
    match d with
    | Gvdecl ({elt=decl} as l) ->
      let e = typecheck_exp tc decl.init in
      if List.exists (fun x -> fst x = decl.name) c.globals
      then type_error l ("Redeclaration of " ^ decl.name)
      else Tctxt.add_global c decl.name e
    | _ -> c) tc p

  (*  *)

(* This function implements the |- prog and the H ; G |- prog 
   rules of the oat.pdf specification.   
*)
let typecheck_program (p:Ast.prog) : unit =
  let sc = create_struct_ctxt p in
  let fc = create_function_ctxt sc p in
  let tc = create_global_ctxt fc p in
  List.iter (fun p ->
    match p with
    | Gfdecl ({elt=f} as l) -> typecheck_fdecl tc f l
    | Gtdecl ({elt=(id, fs)} as l) -> typecheck_tdecl tc id fs l 
    | _ -> ()) p
