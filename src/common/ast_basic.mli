

val of_listr : ('a -> 'a -> 'a) -> 'a list -> 'a
val of_listl : ('a -> 'a -> 'a) -> 'a list -> 'a

val list_of :
  ([< `And of 'b * 'a * 'a
    | `App of 'c * 'a * 'a
    | `Bar of 'd * 'a * 'a
    | `Com of 'e * 'a * 'a
    | `Dot of 'f * 'a * 'a
    | `Sem of 'g * 'a * 'a
    | `Sta of 'h * 'a * 'a ]
   as 'a) ->
  'i -> 'i

val list_of :
    ([> `And of 'b * 'a * 'a
     | `App of 'c * 'a * 'a
     | `Bar of 'd * 'a * 'a
     | `Com of 'e * 'a * 'a
     | `Dot of 'f * 'a * 'a
     | `Sem of 'g * 'a * 'a
     | `Sta of 'h * 'a * 'a ]
       as 'a) ->
         'a list -> 'a list
      
val list_of_and : ([> `And of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val list_of_com : ([> `Com of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val list_of_star : ([> `Sta of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val list_of_bar : ([> `Bar of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val list_of_sem : ([> `Sem of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val list_of_dot : ([> `Dot of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val list_of_app : ([> `App of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val listr_of_arrow :
  ([> `Arrow of 'b * 'a * 'a ] as 'a) -> 'a list -> 'a list
val view_app : 'a list -> ([> `App of 'c * 'b * 'a ] as 'b) -> 'b * 'a list
