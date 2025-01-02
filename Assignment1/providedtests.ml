open Assert
open Hellocaml

(* These tests are provided by you -- they will NOT be graded *)

(* You should also add additional test cases here to help you   *)
(* debug your program.                                          *)

let student_provided_tests : suite = [
  Test ("Student-Provided Tests For Problem 1-3", [
    ("case1", assert_eqf (fun () -> 42) prob3_ans );
    ("case2", assert_eqf (fun () -> 25)(prob3_case2 17));
    ("case3", assert_eqf (fun () -> prob3_case3) 64);
  ]);
]

let test4_5 : suite = [
  Test ("Custom Test For Problem 4.5", [
    ("minus times minus is plus", assert_eqf(fun () -> optimize (Mult(Neg(Add(Var "x", Var "y")), Neg(Mult(Var "a", Var "b"))))) (Mult(Add(Var "x", Var "y"),Mult(Var "a", Var "b"))));
    ("double negation", assert_eqf(fun () -> optimize (Neg(Neg(Add(Var "x", Var "y"))))) (Add(Var "x", Var "y")));
    ("subtraction of same var", assert_eqf(fun () -> optimize (Add(Var "x", Neg(Var "x")))) (Const 0L));
    ("hard_case", assert_eqf(fun () -> optimize (Add(Var "x", Neg(Add(Var "x", Neg(Const 1L)))))) (Const 1L));
  ]);
]

let test5 : suite = [

  let c1 = [("x",7L);("y",5L)] in 
  let c2 = [("x",69L);("y",42L)] in

  Test ("Custom Test For Problem 5", [
    ("case1", assert_eqf(fun () -> compile e1) p1);
    ("case2", assert_eqf(fun () -> (interpret c1 e3)) (run c1 (compile e3)));
    ("case2", assert_eqf(fun () -> (interpret c2 e3)) (run c2 (compile e3)));
  ]);
]


let provided_tests : suite =
  student_provided_tests @
  test4_5 @
  test5