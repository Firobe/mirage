open Functoria.DSL

type mclock = MCLOCK

let mclock = typ MCLOCK

let default_monotonic_clock =
  let packages_v =
    let open Key in
    match_ (value target) @@ function
    | #mode_unix | #mode_unikraft ->
        [ package ~min:"4.1.0" ~max:"5.0.0" "mirage-clock-unix" ]
    | #mode_solo5 | #mode_xen ->
        [ package ~min:"4.2.0" ~max:"5.0.0" "mirage-clock-solo5" ]
  in
  impl ~packages_v "Mclock" mclock
