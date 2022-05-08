open Ast
open Sast

let f_sym_table = Hashtbl.create 64 (* map of "{func}#{var}" -> type *)
(* f_param_table stores types of the arguments. The function's type is stored
   in f_sym_table *)
let f_param_table = Hashtbl.create 64 

(*
 Stores information about custom types
 Custom type names are stored as name --> name#, e.g "MyCustType" --> "MyCustType#"
 Custom type vars are stored as CustType#var --> type, e.g. "MyCustType#myInt" --> int
*)
(* Stores all custom types defined in a set *)
let cust_type_table = Hashtbl.create 64  
(* Stores all custom type vars in map of "typeName#varName" --> type *)
let cust_type_vars_table = Hashtbl.create 64
(* Stores variables to their custom type*)
let var_to_cust_type_table = Hashtbl.create 64

let make_key fn id = fn ^ "#" ^ id

let set_cust_type name = 
  let curr = Hashtbl.find_opt cust_type_table name in 
  let key = make_key name "" in
  match curr with 
  | None -> Hashtbl.add cust_type_table key key 
  | Some _ -> raise (Failure ("Custom type " ^ name ^ "is already defined"))

let set_cust_type_var name (typ, id) = 
  let key = make_key name id in  
  let curr = Hashtbl.find_opt cust_type_vars_table key in 
  match curr with 
    | None -> print_endline (key ^ ": " ^ string_of_typ typ);
      Hashtbl.add cust_type_vars_table key typ 
    | Some _ -> raise (Failure ("Custom type var " ^ key ^ "is already defined"))

let rec set_cust_type_vars name vars = 
  match vars with 
  | [] -> ignore(); 
  | f::r -> set_cust_type_var name f; set_cust_type_vars name r 

let set_var_to_cust_type cfunc var cust_type = 
  let key = make_key cfunc var in
  let curr = Hashtbl.find_opt var_to_cust_type_table key in 
  match curr with 
  | None -> Hashtbl.add var_to_cust_type_table key cust_type 
  | Some t -> raise (Failure ("Variable " ^ var ^ " in function " ^ cfunc ^ " already has type " ^ t ))

(******* f_sym_table helpers *******)
let set key typ tbl = 
  let curr = Hashtbl.find_opt tbl key in 
  match curr with 
  | None -> Hashtbl.add tbl key typ 
  | Some curr_type -> if curr_type != typ then raise 
    (Failure ("identifier " ^ key ^ " has type " ^ string_of_typ curr_type ^
               " and is being set to " ^ string_of_typ typ))

let set_id fn id typ tbl =
  let key = make_key fn id in 
  set key typ tbl

let set_fn fn typ tbl =
  let key = make_key fn "" in 
  set key typ tbl

let try_get key tbl = 
  Hashtbl.find_opt tbl key

let get key tbl =
  try Hashtbl.find tbl key 
  with Not_found -> raise (Failure ("undeclared identifier " ^ key))

let get_id fn id tbl =
  let key = make_key fn id in 
  get key tbl 

let get_fn fn tbl =
  let key = make_key fn "" in
  get key tbl

let builtin = [
  FuncDef {rtyp = Void; fname = "print"; args = [(Int, "valToPrint")]; body = [] };
]

(******* f_param_table helpers *******)
let verify_args fn arg_type_list tbl =
  let curr = Hashtbl.find_opt tbl fn in
  match curr with
  | None -> raise (Failure ("Undefined function call to " ^ fn ^" table size: " ^ (string_of_int (Hashtbl.length tbl))))
  | Some param_type_list -> if param_type_list = arg_type_list then ignore ()
    else raise (Failure ("For function call to " ^ fn ^ ", arguments type (" ^ (String.concat ", "
    (List.map string_of_typ arg_type_list)) ^ ") don't match parameters (" ^
    (String.concat ", " (List.map string_of_typ param_type_list)) ^ ")"))

let set_func_param_table fn param_list tbl =
  let curr = Hashtbl.find_opt tbl fn in
  match curr with
  | None -> Hashtbl.add tbl fn param_list
  | Some _ -> raise (Failure ("Duplicated definition of function " ^ fn))


let check_func_def f = 
  (* cfunc == "containing function" *)
  let rec check_expr cfunc = function
  | Binop (e1, bop, e2) -> 
    let (t1, e1') as se1 = check_expr cfunc e1 in
    let (t2, e2') as se2 = check_expr cfunc e2 in 
    let err = "illegal binary op" in 
    if t1 = t2 then 
      let t = match bop with
        Add | Sub | Mul | Div | Mod when t1 = Int   -> Int
      | Or  | And                   when t1 = Int   -> raise (Failure err)
      | Add | Sub | Mul | Div       when t1 = Float -> Float
      | Or  | And                   when t1 = Float -> raise (Failure err)
      | Add | Sub | Mul | Div | Mod | Less| Greater when t1 = Bool  -> raise (Failure err)
      | Or  | And                   when t1 = Bool  -> Bool
      | Neq | Eq | Less | Greater                   -> Bool
      | _ -> raise (Failure err)
      in
      (t, SBinop(se1, bop, se2))
    else
      if t1 = Float then
        if t2 = Int then
          let t = match bop with
              Add | Sub | Mul | Div     -> Float
            | Neq | Eq | Less | Greater -> Bool
          | _ -> raise (Failure err)
          in
          (t, SBinop(se1, bop, se2))
        else raise (Failure err)
      else
        if t1 = Int then
          if t2 = Float then
            let t = match bop with
                Add | Sub | Mul  | Div      -> Float
              | Neq | Eq  | Less | Greater -> Bool
            | _ -> raise (Failure err)
            in
            (t, SBinop(se1, bop, se2))
          else raise (Failure err)
        else (raise (Failure err))
  | BLit b -> (Bool, SBLit b)
  | ILit i -> (Int, SILit i)
  | FLit f -> (Float, SFLit f)
  | Asn (id, expr) ->
      let key = make_key cfunc id in 
      let curr = try_get key var_to_cust_type_table in (
        match curr with 
        | None ->  let typ, v = check_expr cfunc expr in 
          set_id cfunc id typ f_sym_table;
          (Void, SAsn (id, (typ, v)))
        | Some t -> raise (Failure ("var " ^ key ^ " already defined"))
      )
  | CustDecl (id, cust) ->
    let key = make_key cfunc id in 
    let curr = try_get key f_sym_table in (
      match curr with 
      | None -> set_var_to_cust_type cfunc id cust; (Void, SCustDecl (id, cust))
      | Some t -> raise (Failure ("var " ^ key ^ " already defined"))
    )
  | Var id -> (get_id cfunc id f_sym_table, SVar id)
  | Swap (id1, id2) ->
      let t1 = get_id cfunc id1 f_sym_table in
      let t2 = get_id cfunc id2 f_sym_table in
      if t1 = t2 then (Void, SSwap (id1, id2))
      else raise (Failure ("Incompatible type swapping (" ^
            string_of_typ t1 ^ ", " ^ string_of_typ t2 ^ ") of variables (" ^
            id1 ^ ", " ^ id2 ^ ")"))
  | Call (fname, arg_list) ->
    let sarg_list = List.map (check_expr cfunc) arg_list in
    let arg_type_list = List.map (function (t, _) -> t) sarg_list in
      verify_args fname arg_type_list f_param_table;
      (get_fn fname f_sym_table, SCall(fname, sarg_list))
  | CustVar(id, var) -> 
    let key = make_key cfunc id in 
    let opt_cust_type = try_get key var_to_cust_type_table in 
    (
      match opt_cust_type with 
      | None -> raise (Failure ("var " ^ key ^ " is not declared as a custom type"))
      | Some c -> ( 
        let var_key = make_key c var in 
        let opt_type = try_get var_key cust_type_vars_table in 
        match opt_type with
        | None -> raise (Failure ("var " ^ var_key ^ " is not declared for this custom type " ^ c))
        | Some t -> (t, SCustVar(id, var))
        )
    )
  | CustAsn(id, var , e) -> 
    let key = make_key cfunc id in 
    let opt_cust_type = try_get key var_to_cust_type_table in 
    (
      match opt_cust_type with 
      | None ->  raise (Failure ("var " ^ key ^ " is not declared as a custom type"))
      | Some c -> 
        let var_key = make_key c var in 
        let opt_type = try_get var_key cust_type_vars_table in 
        (
          match opt_type with 
          | None -> raise (Failure ("var " ^ var_key ^ " is not declared for this custom type " ^ c))
          | Some t ->
            let typ, v = check_expr cfunc e in 
            if t = typ then
              (Void, SCustAsn(id, var, (typ, v))) 
            else 
              raise (Failure ("var " ^ var_key ^ " is being assigned to a mismatched type, expected: " 
              ^ (string_of_typ typ) ^ " but received " ^ (string_of_typ t)))
        )
    )
  in

  let rec check_stmt_list cfunc all_stmt =
    let rec check_stmt cfunc = function
      | Block sub_stmts -> SBlock (check_stmt_list cfunc sub_stmts)
      | Expr expr -> SExpr (check_expr cfunc expr)
      (* TODO: need to check whether expr of SIf/SWhile is boolean *)
      | If (expr, stmt1, stmt2) ->
          let sexpr = check_expr cfunc expr in
          let expr_typ = fst sexpr in
          if expr_typ != Bool then raise (Failure
            ("Condition in if statement must be of type bool, but "
            ^ string_of_typ (expr_typ) ^ " is provided"))
          else SIf (sexpr, check_stmt cfunc stmt1, check_stmt cfunc stmt2)
      | While (expr, stmt) ->
          let sexpr = check_expr cfunc expr in
          let expr_typ = fst sexpr in
          if expr_typ != Bool then raise (Failure
            ("Condition in while statement must be of type bool, but "
            ^ string_of_typ (expr_typ) ^ " is provided"))
          else SWhile (check_expr cfunc expr, check_stmt cfunc stmt)
      | For (id, lo, hi, stmt) ->  
          (set_id cfunc id Int f_sym_table; SFor (id, lo, hi, check_stmt cfunc stmt))
      | Return expr -> SReturn (check_expr cfunc expr)
    in
    List.map (check_stmt cfunc) all_stmt
  in

  let check_func func =
    {
      srtyp = func.rtyp;
      sfname = func.fname;
      sargs = func.args;
      sbody = check_stmt_list func.fname func.body;
    }
  in
  set_fn f.fname f.rtyp f_sym_table;
  let set_arg_ids (typ, id) = set_id f.fname id typ f_sym_table in
  ignore (List.map set_arg_ids f.args);
  set_func_param_table f.fname ((List.map (function (t, _) -> t) f.args))
                                  f_param_table;
  let checked_func = check_func f
  in 
  checked_func

let add_custom_type c = 
  set_cust_type c.name;
  set_cust_type_vars c.name c.vars;
  SCustomTypeDef ({sname=c.name; svars=c.vars})


let check_part part = 
  match part with 
  | FuncDef(func) -> SFuncDef (check_func_def func)
  | CustomTypeDef(cust) ->  (add_custom_type cust)

let rec check_program prog = List.map check_part (List.append builtin prog)
