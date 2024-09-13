open Functoria.DSL

type pclock = PCLOCK

let pclock = typ PCLOCK

let default_posix_clock =
  let packages_v =
    let open Key in
    match_ (value target) @@ function
    | #mode_unix | #mode_unikraft ->
        [ package ~min:"3.0.0" ~max:"5.0.0" "mirage-clock-unix" ]
    | #mode_solo5 | #mode_xen ->
        [ package ~min:"4.2.0" ~max:"5.0.0" "mirage-clock-solo5" ]
  in
  impl ~packages_v "Pclock" pclock
