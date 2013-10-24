
open Tokenf
  
type 'a t = 'a Gentry.t

type assoc = [ `LA | `NA | `RA ]

type position =
    [ `After of string
    | `Before of string
    | `First
    | `Last
    | `Level of string ]

val filter: stream -> stream      

(** Basially a filter attached to the stream lexer *)    
type gram = Gstructure.gram = {
  annot:string;
  gfilter : FanTokenFilter.t;
}

module Action : sig
  type t = Gaction.t
  val mk : 'a -> t
  val get : t -> 'a
  val getf : t -> 'a -> 'b
  val getf2 : t -> 'a -> 'b -> 'c
end

      
type word =
   [`Any
   |`A of string
   |`Empty]
and data = (int * word) (* FIXME duplicate in gram_def *)      
type descr = data
      

      
type token_pattern = ((Tokenf.t -> bool) * descr * string )

type entry = Gstructure.entry 
and desc = Gstructure.desc
and level =Gstructure.level 
and symbol = Gstructure.symbol
and tree = Gstructure.tree 
and node = Gstructure.node 

type anno_action = int * symbol list * string * Action.t       

type production = symbol list * (string * Action.t)
      
type label = string option

(* FIXME duplicate with Grammar/Gstructure *)      
type olevel =label * assoc option * production list
type extend_statment = position option * olevel list
type single_extend_statement = position option * olevel      
type delete_statment = symbol list

      
val name: 'a t -> string

val print: Format.formatter -> 'a t -> unit
    
val dump: Format.formatter -> 'a t -> unit

val trace_parser: bool ref

val parse_origin_tokens:  'a t -> stream -> 'a
      
val setup_parser:  'a t ->  (stream -> 'a) -> unit
    
val clear: 'a t -> unit

(* val using: gram -> string -> unit *)

val mk_action: 'a -> Action.t

val string_of_token:[> Tokenf.t ] -> string

val obj: 'a t -> entry         
val repr: entry -> 'a t
    
(* val removing: gram -> string -> unit *)

val gram: gram

(** create a standalone gram
    {[

    {:new| (g:Gramf.t)
    include_quot
    |}
    ]}
 *)
val create_lexer:
    ?filter:Tokenf.filter ->
      annot:string -> keywords: string list -> unit -> gram

val mk_dynamic: gram -> string -> 'a t

val gram_of_entry: 'a t -> gram
    
val mk: string -> 'a t

val of_parser:  string ->  (stream -> 'a) ->  'a t

val get_filter: unit -> FanTokenFilter.t


val lex_string: Locf.t -> string -> Tokenf.stream


val parse:  'a t -> Locf.t -> char Streamf.t -> 'a

val parse_string:
    ?lexer:(Locf.t -> char Streamf.t -> Tokenf.stream ) -> 
    ?loc:Locf.t -> 'a t  -> string -> 'a
      
val debug_origin_token_stream: 'a t -> Tokenf.t Streamf.t -> 'a

val debug_filtered_token_stream: 'a t -> Tokenf.t Streamf.t -> 'a

val parse_string_safe:  ?loc:Locf.t -> 'a t ->  string -> 'a

val wrap_stream_parser: ?loc:Locf.t -> (loc:Locf.t -> 'a -> 'b) -> 'a -> 'b

(* val parse_file_with: rule:'a t -> string -> 'a *)

val delete_rule:  'a t -> symbol list -> unit

(* val srules: production list  ->  [> `Stree of tree ] *)

val sfold0:  ('a -> 'b -> 'b) ->  'b -> 'c -> 'd -> ('e Streamf.t -> 'a) -> 'e Streamf.t -> 'b


val sfold1:  ('a -> 'b -> 'b) ->  'b -> 'c -> 'd -> ('e Streamf.t -> 'a) -> 'e Streamf.t -> 'b
      
val sfold0sep:
    ('a -> 'b -> 'b) ->  'b -> 'a t -> symbol list -> ('c Streamf.t -> 'a) ->
      ('c Streamf.t -> unit) ->
        'c Streamf.t -> 'b

val sfold1sep:
    ('a -> 'b -> 'b) ->  'b -> 'a t -> symbol list -> (stream -> 'a) ->
      (stream -> unit) ->
        stream -> 'b
            

val extend:  'a t -> extend_statment -> unit
val unsafe_extend:  'a t -> extend_statment -> unit

val extend_single: 'a t -> single_extend_statement -> unit
val unsafe_extend_single: 'a t -> single_extend_statement -> unit    

val eoi_entry: 'a t -> 'a t

    
val levels_of_entry: 'a t -> level list option

(* val find_level: ?position:position ->  'a t -> level *)
    
val token_stream_of_string : string -> stream



val parse_include_file : 'a t -> string -> 'a    
