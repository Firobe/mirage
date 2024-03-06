open Mirage

let opt = Runtime_arg.create "Key.opt"
let opt_all = Runtime_arg.create "Key.opt_all"
let flag = Runtime_arg.create "Key.flag"
let required = Runtime_arg.create "Key.required"

let test () =
  let context = Key.add_to_context Key.target `Unix Context.empty in
  let sigs = conduit @-> random @-> job in
  let network = default_network in
  let etif = etif network in
  let arp = arp etif in
  let ipv4 = create_ipv4 etif arp in
  let ipv6 = create_ipv6 network etif in
  let ipv4_only = Runtime_arg.ipv4_only () in
  let ipv6_only = Runtime_arg.ipv6_only () in
  let stackv4v6 =
    direct_stackv4v6 ~ipv4_only ~ipv6_only network etif arp ipv4 ipv6
  in
  let init = Functoria.(keys sys_argv) in
  let job =
    main "App.Make" sigs $ conduit_direct ~tls:true stackv4v6 $ default_random
  in

  let job =
    let connect _ _ _ = code ~pos:__POS__ "return ()" in
    Functoria.impl
      ~runtime_args:Runtime_arg.[ v opt; v opt_all; v flag; v required ]
      ~extra_deps:[ dep job; dep init ]
      "Functoria_runtime" ~connect Functoria.job
  in
  Functoria_test.run ~project_name:"mirage" context job

let () =
  match Functoria.Action.run (test ()) with
  | Ok () -> ()
  | Error (`Msg e) -> failwith e
