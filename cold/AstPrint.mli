val prefix_symbols : char list
val infix_symbols : char list
val operator_chars : char list
val numeric_chars : char list
val special_infix_strings : string list
val fixity_of_string : string -> [> `Infix of string | `Prefix ]
val view_fixity_of_exp :
  Parsetree.expression -> [> `Infix of string | `Prefix ]
val is_infix : [> `Infix of 'a ] -> bool
val is_predef_option : Longident.t -> bool
type space_formatter = (unit, Format.formatter, unit) format
val override : Asttypes.override_flag -> string
val type_variance : bool * bool -> string
type construct =
    [ `cons of Parsetree.expression list
    | `list of Parsetree.expression list
    | `nil
    | `normal
    | `simple of Longident.t
    | `tuple ]
val view_expr :
  Parsetree.expression ->
  [> `cons of Parsetree.expression list
   | `list of Parsetree.expression list
   | `nil
   | `normal
   | `simple of Longident.t
   | `tuple ]
val is_simple_construct : construct -> bool
val pp : Format.formatter -> ('a, Format.formatter, unit) format -> 'a
val is_irrefut_patt : Parsetree.pattern -> bool
class printer :
  unit ->
  object ('b)
    val pipe : bool
    val semi : bool
    method binding :
      Format.formatter -> Parsetree.pattern * Parsetree.expression -> unit
    method bindings :
      Format.formatter ->
      (Parsetree.pattern * Parsetree.expression) list -> unit
    method case_list :
      Format.formatter ->
      (Parsetree.pattern * Parsetree.expression) list -> unit
    method class_expr : Format.formatter -> Parsetree.class_expr -> unit
    method class_field : Format.formatter -> Parsetree.class_field -> unit
    method class_params_def :
      Format.formatter -> (string Asttypes.loc * (bool * bool)) list -> unit
    method class_signature :
      Format.formatter -> Parsetree.class_signature -> unit
    method class_structure :
      Format.formatter -> Parsetree.class_structure -> unit
    method class_type : Format.formatter -> Parsetree.class_type -> unit
    method class_type_declaration_list :
      Format.formatter -> Parsetree.class_type_declaration list -> unit
    method constant : Format.formatter -> Asttypes.constant -> unit
    method constant_string : Format.formatter -> string -> unit
    method core_type : Format.formatter -> Parsetree.core_type -> unit
    method core_type1 : Format.formatter -> Parsetree.core_type -> unit
    method direction_flag :
      Format.formatter -> Asttypes.direction_flag -> unit
    method directive_argument :
      Format.formatter -> Parsetree.directive_argument -> unit
    method exception_declaration :
      Format.formatter -> string * Parsetree.exception_declaration -> unit
    method expression : Format.formatter -> Parsetree.expression -> unit
    method expression1 : Format.formatter -> Parsetree.expression -> unit
    method expression2 : Format.formatter -> Parsetree.expression -> unit
    method label_exp :
      Format.formatter ->
      Asttypes.label * Parsetree.expression option * Parsetree.pattern ->
      unit
    method label_x_expression_param :
      Format.formatter -> Asttypes.label * Parsetree.expression -> unit
    method list :
      ?sep:space_formatter ->
      ?first:space_formatter ->
      ?last:space_formatter ->
      (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a list -> unit
    method longident : Format.formatter -> Longident.t -> unit
    method longident_loc :
      Format.formatter -> Longident.t Asttypes.loc -> unit
    method module_expr : Format.formatter -> Parsetree.module_expr -> unit
    method module_type : Format.formatter -> Parsetree.module_type -> unit
    method mutable_flag : Format.formatter -> Asttypes.mutable_flag -> unit
    method option :
      ?first:space_formatter ->
      ?last:space_formatter ->
      (Format.formatter -> 'a -> unit) ->
      Format.formatter -> 'a option -> unit
    method paren :
      bool ->
      (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a -> unit
    method pattern : Format.formatter -> Parsetree.pattern -> unit
    method pattern1 : Format.formatter -> Parsetree.pattern -> unit
    method private_flag : Format.formatter -> Asttypes.private_flag -> unit
    method rec_flag : Format.formatter -> Asttypes.rec_flag -> unit
    method reset : 'b
    method reset_semi : 'b
    method signature :
      Format.formatter -> Parsetree.signature_item list -> unit
    method signature_item :
      Format.formatter -> Parsetree.signature_item -> unit
    method simple_expr : Format.formatter -> Parsetree.expression -> unit
    method simple_pattern : Format.formatter -> Parsetree.pattern -> unit
    method string_quot : Format.formatter -> Asttypes.label -> unit
    method structure :
      Format.formatter -> Parsetree.structure_item list -> unit
    method structure_item :
      Format.formatter -> Parsetree.structure_item -> unit
    method sugar_expr : Format.formatter -> Parsetree.expression -> bool
    method toplevel_phrase :
      Format.formatter -> Parsetree.toplevel_phrase -> unit
    method type_declaration :
      Format.formatter -> Parsetree.type_declaration -> unit
    method type_def_list :
      Format.formatter ->
      (string Asttypes.loc * Parsetree.type_declaration) list -> unit
    method type_param :
      Format.formatter -> (bool * bool) * string Asttypes.loc option -> unit
    method type_var_option :
      Format.formatter -> string Asttypes.loc option -> unit
    method type_with_label :
      Format.formatter -> Asttypes.label * Parsetree.core_type -> unit
    method tyvar : Format.formatter -> string -> unit
    method under_pipe : 'b
    method under_semi : 'b
    method value_description :
      Format.formatter -> Parsetree.value_description -> unit
    method virtual_flag : Format.formatter -> Asttypes.virtual_flag -> unit
  end
val default : printer
val toplevel_phrase : Format.formatter -> Parsetree.toplevel_phrase -> unit
val expression : Format.formatter -> Parsetree.expression -> unit
val string_of_expression : Parsetree.expression -> string
val top_phrase : Format.formatter -> Parsetree.toplevel_phrase -> unit
val core_type : Format.formatter -> Parsetree.core_type -> unit
val pattern : Format.formatter -> Parsetree.pattern -> unit
val signature : Format.formatter -> Parsetree.signature -> unit
val structure : Format.formatter -> Parsetree.structure -> unit
