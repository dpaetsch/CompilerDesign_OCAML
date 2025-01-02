%{
open Ast

let loc (startpos:Lexing.position) (endpos:Lexing.position) (elt:'a) : 'a node =
  { elt ; loc=Range.mk_lex_range startpos endpos }

%}

/* Declare your tokens here. */
%token EOF
%token <int64>  INT
%token NULL
%token <string> STRING
%token <string> IDENT

%token TINT     /* int */
%token TVOID    /* void */
%token TSTRING  /* string */
%token IF       /* if */
%token ELSE     /* else */
%token WHILE    /* while */
%token RETURN   /* return */
%token VAR      /* var */
%token SEMI     /* ; */
%token COMMA    /* , */
%token LBRACE   /* { */
%token RBRACE   /* } */
%token PLUS     /* + */
%token DASH     /* - */
%token STAR     /* * */
%token EQEQ     /* == */
%token EQ       /* = */
%token LPAREN   /* ( */
%token RPAREN   /* ) */
%token LBRACKET /* [ */
%token RBRACKET /* ] */
%token TILDE    /* ~ */
%token BANG     /* ! */
%token GLOBAL   /* global */

/* Added: */
%token FOR     /* for */
%token TRUE    /* true */ /*avoids conflict with the token TRUE */
%token FALSE   /* false */ /*avoids conflict with the token FALSE */
%token TBOOL   /* bool */
%token NOTE    /* != */
%token LT      /* < */
%token LTEQ    /* <= */
%token GT      /* > */
%token GTEQ    /* >= */
%token LSHIFT  /* << */
%token RSHIFT  /* >> */
%token ARSHIFT /* >>> */
%token AMP     /* & */
%token PIPE    /* | */
%token BITAND  /* [&] */
%token BITOR   /* [|] */
%token NEW     /* new  */


/* Added: Associativity and precedence of operators */
%left BITOR                 /* Bit-wise OR           , precedence 20 */
%left BITAND                /* Bit-wise AND          , precedence 30 */
%left PIPE                  /* Logical OR            , precedence 40 */
%left AMP                   /* Logical AND           , precedence 50 */
%left EQEQ NOTE             /* ==, !=                , precedence 60 */
%left LT LTEQ GT GTEQ       /* <, <=, >, >=          , precedence 70 */
%left LSHIFT RSHIFT ARSHIFT /* Shift operators       , precedence 80 */
%left PLUS DASH             /* Addition, subtraction , precedence 90 */
%left STAR                  /* Multiplication        , precedence 100 */

%nonassoc BANG     /* Logical NOT */
%nonassoc TILDE    /* Bit-wise NOT */
%nonassoc LBRACKET /* Array indexing */
%nonassoc LPAREN   /* Function call or grouping */
/* ---------------------------------------------------------------------- */

%start prog
%start exp_top
%start stmt_top
%type <Ast.exp Ast.node> exp_top
%type <Ast.stmt Ast.node> stmt_top

%type <Ast.prog> prog
%type <Ast.exp Ast.node> exp
%type <Ast.stmt Ast.node> stmt
%type <Ast.block> block
%type <Ast.ty> ty


(* End of declaration section of parser *)
%% 
(* Start of rules section of parser *)

(*Starting Points*)
exp_top: 
  | e=exp EOF { e }

stmt_top: 
  | s=stmt EOF { s }

prog: 
  | p=list(decl) EOF { p }


// Moved
%inline ret_ty:
  | TVOID  { RetVoid }
  | t=ty   { RetVal t }

decl:
  | GLOBAL name=IDENT EQ init=gexp SEMI  (* Declaration *)
      { Gvdecl (loc $startpos $endpos { name; init }) }       
  | frtyp=ret_ty fname=IDENT LPAREN args=arglist RPAREN body=block (* Function Declaration *)
      { Gfdecl (loc $startpos $endpos { frtyp; fname; args; body }) }

arglist:
  | l=separated_list(COMMA, pair(ty, IDENT)) { l }

// Moved
%inline rty:
  | TSTRING { RString }
  | t=ty LBRACKET RBRACKET { RArray t }

ty:
  | TINT   { TInt }
  | TBOOL  { TBool }
  | r=rty { TRef r } 


%inline bop:
  | PLUS   { Add }
  | DASH   { Sub }
  | STAR   { Mul }
  | EQEQ   { Eq }
   /* Added: */
  | NOTE   { Neq } /* Not equal */
  | LT     { Lt }  /* Less than */
  | LTEQ   { Lte } /* Less than or equal */
  | GT     { Gt }  /* Greater than */
  | GTEQ   { Gte } /* Greater than or equal */
  | AMP    { And } /* Logical And */
  | PIPE   { Or }  /* Logical Or */
  | BITAND { IAnd} /* Bitwise And */
  | BITOR  { IOr } /* Bitwise Or */
  | LSHIFT { Shl } /* Left Shift */
  | RSHIFT { Shr } /* Right Shift */
  | ARSHIFT{ Sar } /* Arithmetic Right Shift */

%inline uop:
  | DASH  { Neg }
  | BANG  { Lognot }
  | TILDE { Bitnot }

gexp:
  | t=rty NULL  { loc $startpos $endpos @@ CNull t }
  | i=INT      { loc $startpos $endpos @@ CInt i } 
  /* Added: */
  | s=STRING   { loc $startpos $endpos @@ CStr s }
  | TRUE   { loc $startpos $endpos @@ CBool true }
  | FALSE { loc $startpos $endpos @@ CBool false }
  | NEW t=ty LBRACKET RBRACKET LBRACE gexp_list=separated_list(COMMA, gexp) RBRACE
                { loc $startpos $endpos @@ CArr (t, gexp_list) }
                

exp: // Expressions
  | i=INT               { loc $startpos $endpos @@ CInt i } // integer literal 
  | t=rty NULL           { loc $startpos $endpos @@ CNull t } // null
  | e1=exp b=bop e2=exp { loc $startpos $endpos @@ Bop (b, e1, e2) } // binary operation
  | u=uop e=exp         { loc $startpos $endpos @@ Uop (u, e) } // unary operation
  | id=IDENT            { loc $startpos $endpos @@ Id id }      // identifier
  | e=exp LBRACKET i=exp RBRACKET  { loc $startpos $endpos @@ Index (e, i) }  // array indexing
  | e=exp LPAREN es=separated_list(COMMA,exp) RPAREN { loc $startpos $endpos @@ Call (e,es) }  // function call
  | LPAREN e=exp RPAREN { e }   // Expression in parenthesis
  /* Added: */
  | s=STRING     { loc $startpos $endpos @@ CStr s }  // string
  | TRUE        { loc $startpos $endpos @@ CBool true }  // true
  | FALSE       { loc $startpos $endpos @@ CBool false } // false
  | NEW t=ty LBRACKET RBRACKET LBRACE es=separated_list(COMMA, exp) RBRACE { loc $startpos $endpos @@ CArr (t, es) }
  | NEW t=ty LBRACKET e=exp RBRACKET { loc $startpos $endpos @@ NewArr (t, e) }

// Moved
lhs:  
  | id=IDENT  { loc $startpos $endpos @@ Id id }
  | e=exp LBRACKET i=exp RBRACKET  { loc $startpos $endpos @@ Index (e, i) }

vdecl:
  | VAR id=IDENT EQ init=exp { (id, init) }

stmt: // Statements
  | d=vdecl SEMI        { loc $startpos $endpos @@ Decl(d) } // variable declaration
  | l=lhs EQ e=exp SEMI { loc $startpos $endpos @@ Assn(l,e) } // assignment
  | e=exp LPAREN es=separated_list(COMMA, exp) RPAREN SEMI { loc $startpos $endpos @@ SCall (e, es) } // function call
  | ifs=if_stmt         { ifs } // if statement
  | RETURN SEMI         { loc $startpos $endpos @@ Ret(None) } // return statement
  | RETURN e=exp SEMI   { loc $startpos $endpos @@ Ret(Some e) } // return statement
  | WHILE LPAREN e=exp RPAREN b=block { loc $startpos $endpos @@ While(e, b) }  // while loop
  /* Added: */
  | FOR LPAREN vdecls=separated_list(COMMA, vdecl) SEMI expopt=option(exp) SEMI stmtopt=option(stmt) RPAREN b=block
                        { loc $startpos $endpos @@ For( vdecls, expopt, stmtopt, b) } // for loop


block:
  | LBRACE stmts=list(stmt) RBRACE { stmts }

if_stmt: // If statement
  | IF LPAREN e=exp RPAREN b1=block b2=else_stmt { loc $startpos $endpos @@ If(e,b1,b2) }

else_stmt: // Else statement
  | (* empty *)       { [] }
  | ELSE b=block      { b }
  | ELSE ifs=if_stmt  { [ ifs ] }



