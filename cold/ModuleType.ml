let app mt1 mt2 =
  match (mt1, mt2) with
  | ((`Id (_loc,i1) : Ast.module_type),(`Id (_,i2) : Ast.module_type)) ->
      (`Id (_loc, (`App (_loc, i1, i2))) : Ast.module_type )
  | _ -> invalid_arg "Fan_module_type app"

let acc mt1 mt2 =
  match (mt1, mt2) with
  | ((`Id (_loc,i1) : Ast.module_type),(`Id (_,i2) : Ast.module_type)) ->
      (`Id (_loc, (`Dot (_loc, i1, i2))) : Ast.module_type )
  | _ -> invalid_arg "ModuleType.acc"