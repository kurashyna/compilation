open Util
open Ast

(*
    Réalisez ici l’analyse de type d’un programme. Faites une sous-fonction récursive pour les expressions et les statements.

    L’idée est la même que dans le langage du cours : pour chaque élément, commencez par typer ses sous-éléments. Ensuite, en fonction de l’élément et du type de ses sous-éléments, déterminez son type, et placez-le dans l’annotation qui l’accompagne.
    Seules les expressions peuvent ainsi être typées.

    Les fonctions devront manipuler un environnement qui associera chaque variable à son type. Les déclarations fixent ces types et ces types sont vérifiés lors de chaque utilisation d’une variable.

    Attention, les déclarations sont locales à un bloc, vous devez donc utiliser les fonctions Environment.add_layer et Environment.remove_layer pour le gérer.

    Cette fonction doit également effectuer les rapports d’erreur et d’avertissement dans [report].

    Ces fonction font un pattern matching sur leur argument principal et traitent chaque cas séparément. Elles font uniquement des effet de bord.
    Par exemple : type_expression : Ast.type_expr annotation -> Util.Error_report.t -> Ast.expression -> unit

    Vous pouvez également effectuer ici (en même temps ou dans une fonction séparée) une analyse d’initialisation des variables (auquel cas, il faut ajouter un argument supplémentaire à ce qui est décrit ci-dessus).

    Vous préciserez ce que vous avez traité dans votre rapport.
*)
   
  let wildcard_type_list = [Type_list(Type_int); Type_list(Type_float); Type_list(Type_bool); Type_list(Type_color); Type_list(Type_point)]

  let type_of_binop = function
  | Add -> [Type_int; Type_float; Type_pos; Type_color; Type_point]
  | Sub | Mul | Div | Mod -> [Type_int; Type_float; Type_pos; Type_color; Type_point]
  | And | Or -> [Type_bool]
  | Eq | Ne -> [Type_int; Type_float; Type_bool; Type_pos; Type_color; Type_point]
  | Lt | Gt | Le | Ge -> [Type_int; Type_float]

  let rec type_expression report env expression =

    match expression with
    | Constant_i(_,a) -> Annotation.set_type a Type_int
    | Constant_f(_,a) -> Annotation.set_type a Type_float
    | Constant_b(_,a) -> Annotation.set_type a Type_bool
    | Variable(name,a) -> (
      match Environment.get env name with
      | Some t -> Annotation.set_type a t
      | None -> Error_report.add_error report ("No type found for the desired variable", Annotation.get_pos a); a
    )
    | Pos(x,y,a) -> (
      let type_x = Annotation.get_type (type_expression report env x) in
      let type_y = Annotation.get_type (type_expression report env y) in

      match type_x,type_y with
      | Some Type_int, Some Type_int -> Annotation.set_type a Type_pos
      | _ -> Error_report.add_error report ("Pos(x,y) should have Integers as arguments",Annotation.get_pos a); a
    )
    | Color(r,g,b,a) -> (
      let type_r = Annotation.get_type (type_expression report env r) in
      let type_g = Annotation.get_type (type_expression report env g) in
      let type_b = Annotation.get_type (type_expression report env b) in

      match type_r,type_g,type_b with
      | Some Type_int, Some Type_int, Some Type_int -> Annotation.set_type a Type_color
      | _ -> Error_report.add_error report ("Color(r,g,b) should have Integers as arguments",Annotation.get_pos a); a
    )
    | Point(pos,color,a) -> (
      let type_pos = Annotation.get_type (type_expression report env pos) in
      let type_color = Annotation.get_type (type_expression report env color) in

      match type_pos,type_color with
      | Some Type_pos, Some Type_color -> Annotation.set_type a Type_point
      | _ -> Error_report.add_error report ("Point(position,color) should have a position and a color as arguments",Annotation.get_pos a); a
    )
    | Unary_operator(unop,e,a) -> (
      let type_e = Annotation.get_type (type_expression report env e) in
      match unop, type_e with
      | USub, Some Type_int -> Annotation.set_type a Type_int  
      | USub, Some Type_float -> Annotation.set_type a Type_float  
      | USub, _ -> Error_report.add_error report ("Minus operator only accept Int or Float type", Annotation.get_pos a);a
      | Not, Some Type_bool -> Annotation.set_type a Type_bool
      | Not, _ -> Error_report.add_error report ("Not operator only accept Bool type",Annotation.get_pos a); a
      | Head, Some Type_list(t) -> Annotation.set_type a (Type_list(t))
      | Head, _ -> Error_report.add_error report ("Head operator only accept List type", Annotation.get_pos a); a
      | Tail, Some Type_list(t) -> Annotation.set_type a (Type_list(t))
      | Tail, _ -> Error_report.add_error report ("Tail operator only accept List type", Annotation.get_pos a); a
      | Floor, Some Type_float -> Annotation.set_type a Type_float
      | Floor, _ -> Error_report.add_error report ("Floor operator only accept Float type", Annotation.get_pos a); a
      | Float_of_int, Some Type_float -> Annotation.set_type a Type_float
      | Float_of_int, _ -> Error_report.add_error report ("Float_of_int operator only accept Float type", Annotation.get_pos a); a
      | Cos, Some Type_float -> Annotation.set_type a Type_float
      | Cos, _ -> Error_report.add_error report ("Cos operator only accept Float type", Annotation.get_pos a); a
      | Sin, Some Type_float -> Annotation.set_type a Type_float
      | Sin, _ -> Error_report.add_error report ("Sin operator only accept Float type", Annotation.get_pos a); a 
    )
    | Binary_operator(binop,e1,e2,a) -> (
      let type_e1 = Annotation.get_type (type_expression report env e1) in
      let type_e2 = Annotation.get_type (type_expression report env e2) in
      
      match type_e1, type_e2 with
      | Some t1, Some t2 ->
          let t_binop = type_of_binop binop in

          (* Is a list | equivalent type | is the same type as the binop *)
          (match (List.exists (fun e -> (t1 == e || t2 == e)) wildcard_type_list), (t1==t2), (List.exists (fun e -> (t1 == e || t2 = e)) t_binop) with
          | true, false, true -> Error_report.add_error report (Format.sprintf "Invalid List type between %s and %s for %s operator" (string_of_type_expr t1) (string_of_type_expr t2) (string_of_binary_operator binop), Annotation.get_pos a); a
          | false, true, false -> Error_report.add_error report (Format.sprintf "invalid type %s for %s operator" (string_of_type_expr t1) (string_of_binary_operator binop), Annotation.get_pos a); a
          | false, false, true -> Error_report.add_error report (Format.sprintf "Invalid types %s and %s for %s operator" (string_of_type_expr t1) (string_of_type_expr t2) (string_of_binary_operator binop), Annotation.get_pos a); a
          | _ -> Annotation.set_type a t1)
      | _ -> Error_report.add_warning report ("Non-typed expression found, there could be an issue with a variable declaration", Annotation.get_pos a); a
    )
    | Field_accessor(fa,e,a) -> (
      let type_e = Annotation.get_type (type_expression report env e) in
      (match type_e with
        | Some t -> (
          match fa, t with
          | (Color_accessor | Position_accessor), Type_point -> Annotation.set_type a Type_point
          | (X_accessor | Y_accessor), Type_pos -> Annotation.set_type a Type_pos
          | (Red_accessor | Green_accessor | Blue_accessor ), Type_color -> Annotation.set_type a Type_color
          | _ -> Error_report.add_error report (Format.sprintf "Cannot use accessor %s on %s" (string_of_field_accessor fa) (string_of_type_expr t), Annotation.get_pos a); a
        )
        | None -> Error_report.add_warning report ("Non-typed expression found, there could be an issue with a variable declaration", Annotation.get_pos a); a
      )
    )
    | List(elist,a) -> (
      let t_list = Annotation.get_type a in
      (List.iter (fun e -> (
        let type_e = Annotation.get_type (type_expression report env e) in
        (match type_e, t_list with
        | Some t, Some tl -> (
            if(t <> tl) then
              Error_report.add_error report (Format.sprintf "Invalid type %s in a list of type %s" (string_of_type_expr t) (string_of_type_expr tl), Annotation.get_pos a)
          )
        | None,_ -> Error_report.add_warning report ("Non-typed expression found, there could be an issue with a variable declaration", Annotation.get_pos a)
        | _, None -> () (*Empty list*)
        )
      )) elist); a
    )
    | Cons(e1,e2,a) -> (
      let opt_type_e1 = Annotation.get_type (type_expression report env e1) in
      let opt_type_e2 = Annotation.get_type (type_expression report env e2) in

      match opt_type_e1, opt_type_e2 with
      | Some type_element, Some type_list -> (
        match type_list with
        | Type_list(inner_type) -> if inner_type == type_element then
                                    Annotation.set_type a type_list
                                  else (
                                    Error_report.add_error report (Format.sprintf "Cannot add element of type %s to a list that contains the type %s" (string_of_type_expr type_element) (string_of_type_expr inner_type), Annotation.get_pos a); 
                                    a)
        | _ -> Annotation.set_type a type_list)
      | Some type_element, None ->  (match e2 with
                                    | List(elist,_) -> if(List.length elist == 0) then 
                                        Annotation.set_type a (Type_list(type_element))
                                      else (
                                        Error_report.add_error report ("There is an issue with this list declaration", Annotation.get_pos a); a
                                      )
                                    | _ -> a)
      | None, Some type_list -> (match e1 with
                                 | List(elist, _) -> if List.length elist == 0 then
                                              Annotation.set_type a type_list 
                                            else (
                                              Error_report.add_warning report ("Non-typed variable detected", Annotation.get_pos a); a 
                                            )
                                 | _ -> a)
      | None, None -> Error_report.add_error report ("Cannot use Cons operator on untyped or empty list", Annotation.get_pos a); a
    )

  let rec type_statement report env statement =
    match statement with
    | Assignment(id,e,a) -> (
      let type_e = Annotation.get_type (type_expression report env e) in
      match id with
      | Variable(name,_) -> (match (Environment.get env name), type_e with
                             | Some resolved_type, Some expr_type -> if resolved_type <> expr_type then
                                                                      Error_report.add_error report (Format.sprintf "Variable %s was declared as a %s but the assignement value is a %s" name (string_of_type_expr resolved_type) (string_of_type_expr expr_type), Annotation.get_pos a)                                                      
                             | None,_ -> Error_report.add_error report ("Variable isn't declared in this context", Annotation.get_pos a)
                             | Some _, None -> ()
                            )
      | _ -> Error_report.add_error report ("Copy only works when the first argument is a variable.", Annotation.get_pos a)
    )
    | Variable_declaration(name, expression_type, a) -> (
      let variable_decl = Environment.get env name in
      
      match variable_decl with
      | Some _ -> Error_report.add_error report (Format.sprintf "A variable with the name %s is already declared" name, Annotation.get_pos a)
      | None -> Environment.add env name expression_type
    )
    | Block(content,_) -> (
      Environment.add_layer env;
      List.iter (fun s -> type_statement report env s) content;
      Environment.remove_layer env
    )
    | IfThenElse(cond,s_then,s_else,a) -> (
      let test_cond = Annotation.get_type (type_expression report env cond) in
      match test_cond with
      | Some Type_bool -> (
        type_statement report env s_then; 
        type_statement report env s_else              
      )
      | _ -> Error_report.add_error report ("If condition need to be of type bool", Annotation.get_pos a)
    )
    | For(var_name, init, target, step, body, a) -> (
      let decl_var = Environment.get env var_name in
      (match decl_var with
      | Some _ -> Error_report.add_error report (Format.sprintf "Variable %s is already defined" var_name, Annotation.get_pos a)
      | None -> (
        let type_init = Annotation.get_type (type_expression report env init) in
        let type_target = Annotation.get_type (type_expression report env target) in
        let type_step = Annotation.get_type (type_expression report env step) in
        
        (match type_init, type_target, type_step with
            | Some ti, Some tt, Some ts -> (match ti,tt,ts with
                                            | (Type_int | Type_float), (Type_int | Type_float), (Type_int | Type_float) -> (
                                                if (ti == tt) && (tt == ts) then
                                                (
                                                  Environment.add_layer env;
                                                  Environment.add env var_name ti;
                                                  type_statement report env body;
                                                  Environment.remove_layer env;
                                                ) 
                                                else
                                                  Error_report.add_error report (
                                                    Format.sprintf "Invalid signature detected, types mismatch init : %s, target : %s, step : %s" (string_of_type_expr ti) (string_of_type_expr tt) (string_of_type_expr ts), 
                                                    Annotation.get_pos a)
                                        )
                                      | _ -> Error_report.add_error report (
                                        Format.sprintf "For loop only support Int and Float type in it's signature", 
                                        Annotation.get_pos a)
                                      )
            | _ -> Error_report.add_warning report ("Undeclared variable or empty list detected", Annotation.get_pos a)
          )
        )
      )
    )
    | Foreach(name,list,body,a) -> (
      let type_list = Annotation.get_type (type_expression report env list) in

      match type_list with
      | Some Type_list(inner_type) -> (
        let var_decl = Environment.get env name in
        match var_decl with
        | Some _ -> Error_report.add_error report (Format.sprintf "A variable with the name %s is already declared" name, Annotation.get_pos a)
        | None -> (
          Environment.add_layer env;
          Environment.add env name inner_type;
          Environment.add_ref env name (ref(inner_type));
          type_statement report env body;
          Environment.remove_layer env
        ) 
      )
      | _ -> Error_report.add_error report ("Second argument should be of type List", Annotation.get_pos a)
    )  
    | Draw(e,a) -> (
      let type_e = Annotation.get_type (type_expression report env e) in
      match type_e with
      | Some Type_point -> ()
      | _ -> Error_report.add_error report ("Draw can only be used with an argument of type point.", Annotation.get_pos a)
    )
    | Nop -> ()
    | Print(e,_) -> (
      let _ = type_expression report env e in
      ()
    )
  
  let type_analyser report program =
    let type_environment = Environment.new_environment () in
      match program with 
      | Program(al,s) -> (
        List.iter (fun arg -> match arg with
        | Argument(name,t,a) -> type_statement report type_environment (Variable_declaration(name,t,a))
        ) al;
        type_statement report type_environment s
      )