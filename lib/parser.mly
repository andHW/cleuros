%{ open Ast %}

%token PLUS MINUS TIMES DIVIDE MOD ISEQUALTO ASNTO EOF
%token SEMI LPAREN RPAREN COMMA PRINT EXCHANGE WITH BE
%token LBRACE RBRACE IF ELSE LESS WHILE GREATER
%token NEWTYPE
%token FOR TO 
%token INDENT DEDENT COLON NEWLINE
%token RETURN
%token INT BOOL FLOAT
%token <bool> BOOLVAR
%token <int> INTLITERAL
%token <float> FLOATLITERAL
%token <string> VARIABLE
%token <string> FUNCTION
%token <string> CUSTOMTYPENAME

%left SEMI
%right ASNTO

%left LESS GREATER ISEQUALTO
%left PLUS MINUS
%left TIMES DIVIDE MOD

%start program_EOF
%type <Ast.program> program_EOF

%%

program_EOF: program EOF {  $1 }

program: 
| /* nothing*/ {[]}
| custom_type program {(CustomTypeDef $1::$2)}
| fdecl program {(FuncDef $1::$2)}

custom_type: 
NEWTYPE CUSTOMTYPENAME COLON NEWLINE INDENT custom_var_list DEDENT NEWLINE { { name = $2; vars = $6}}

custom_var_list: 
| /* nothing */ {[]}
| typ_binding {[$1]}
| typ_binding NEWLINE custom_var_list {$1::$3}

typ:
| INT   { Int }
| BOOL  { Bool }
| FLOAT { Float }

fdecl:
FUNCTION LPAREN formals_opt RPAREN NEWLINE INDENT stmt_list DEDENT
{
    {
        rtyp = Void;
        fname = $1;
        args = $3;
        body = $7;
    }
}
| typ FUNCTION LPAREN formals_opt RPAREN NEWLINE INDENT stmt_list DEDENT
{
    {
        rtyp = $1;
        fname = $2;
        args = $4;
        body = $8;
    }
}
;

/* function arguments */
formals_opt:
  /*nothing*/ { [] }
  | formals_list { $1 }
;

formals_list:
  typ_binding { [$1] }
  | typ_binding COMMA formals_list { ($1)::$3 }
;

typ_binding:
  VARIABLE BE typ { ($3, $1) }
/* end function arguments */

stmt_list:
/* nothing */ { [] }
| stmt stmt_list  { $1::$2 }
;


/* if-else are bound at this point */
stmt:
| expr NEWLINE { Expr($1) }
| IF expr NEWLINE INDENT stmt_list DEDENT { If($2, Block $5, Block []) }
| IF expr NEWLINE INDENT stmt_list DEDENT ELSE NEWLINE INDENT stmt_list DEDENT { If($2, Block $5, Block $10) }
| WHILE expr NEWLINE INDENT stmt_list DEDENT { While($2, Block $5) }
| FOR VARIABLE ASNTO INTLITERAL TO INTLITERAL NEWLINE INDENT stmt_list DEDENT { For($2, $4, $6, Block $9)}
| RETURN expr NEWLINE { Return($2)}
;

expr:
/* arithmetic */
| expr PLUS   expr    { Binop($1, Add, $3) }
| expr MINUS  expr    { Binop($1, Sub, $3) }
| expr TIMES  expr    { Binop($1, Mul, $3) }
| expr DIVIDE expr    { Binop($1, Div, $3) }
| expr MOD    expr    { Binop($1, Mod, $3) }
/* logical */
| expr LESS expr      { Binop($1, Less, $3) }
| expr GREATER expr   { Binop($1, Greater, $3) }
| expr ISEQUALTO expr { Binop($1, Eq, $3) }
| VARIABLE            { Var($1) }
| INTLITERAL          { ILit($1) }
| FLOATLITERAL        { FLit($1) }
| BOOLVAR             { BLit($1) }
| VARIABLE ASNTO expr { Asn($1, $3) }
| EXCHANGE VARIABLE WITH VARIABLE { Swap($2, $4)}
| FUNCTION LPAREN args_opt RPAREN { Call($1, $3)}
| LPAREN expr RPAREN  { $2 }
;

args_opt: 
/* nothing */ {[]}
| args { $1 }
;

args: 
 expr { [$1] }
| expr COMMA args { $1::$3 }
;
