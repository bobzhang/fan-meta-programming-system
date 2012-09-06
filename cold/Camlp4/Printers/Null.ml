module Id =
 struct
  let name = "Camlp4.Printers.Null"

  let version = Sys.ocaml_version

 end

module Make =
       functor (Syntax : Sig.Syntax) ->
        struct
         let print_interf =
          fun ?input_file:_ -> fun ?output_file:_ -> fun _ -> ()

         let print_implem =
          fun ?input_file:_ -> fun ?output_file:_ -> fun _ -> ()

        end