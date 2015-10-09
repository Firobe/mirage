(*
 * Copyright (c) 2015 Nicolas Ojeda Bar <n.oje.bar@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(** Configuration and runtime command-line arguments. *)

(** Cross-stage argument converters. *)
module Conv: sig

  type 'a t
  (** The type for argument converters. *)

  val create:
    'a Cmdliner.Arg.converter -> (Format.formatter -> 'a -> unit) -> string ->
    'a t
  (** [create conf emit run] is the argument converter using [conf] to
      convert argument into OCaml value, [emit] to convert OCaml
      values into interpretable strings, and the function named [run]
      to transform these strings into OCaml values again. See
      {!configure}, {!emit} and {!runtime} for details.*)

  (** {2 Predefined descriptions} *)

  val string: string t
  (** [string] converts strings. *)

  val bool: bool t
  (** [bool] converts booleans. *)

  val int: int t
  (** [int] converts integers. *)

  val list: 'a t -> 'a list t
  (** [list t] converts lists of [t]s. *)

  val some: 'a t -> 'a option t
  (** [some t] converts [t] options. *)

  (** {2 Accessors} *)

  val configure: 'a t -> 'a Cmdliner.Arg.converter
  (** [configure t] converts the command-line arguments passed during
      the configuration step into OCaml values. *)

  val emit: 'a t -> Format.formatter -> 'a -> unit
  (** [emit] allows to persist OCaml values across stages, ie. it
      takes values (which might be parsed with {!configure} at
      configuration time) and produce a valid string representation
      which can be used at runtime, once the generated code is
      compiled. *)

  val runtime: 'a t -> string
  (** [runtime] is the name of the function called at runtime to parse
      the command-line arguments. Usually, it is a [Cmdliner]'s
      combinator such as {i Cmdliner.Arg.string}. *)

end

(** Cross-stage argument information. See
    {{!http://erratique.ch/software/cmdliner/doc/Cmdliner.Arg.html#arginfo}Cmdliner.Arg}
    for the context. *)
module Info: sig

  type t
  (** The type for information about command-line arguments. *)

  val create:
    ?docs:string -> ?docv:string -> ?doc:string -> ?env:string ->
    string list -> t
  (** Define cross-stage information for an argument. See {!Cmdliner.Arg.info} for details. *)

  val to_cmdliner: t -> Cmdliner.Arg.info

  (** Emit the documentation as OCaml code. *)
  val emit: Format.formatter -> t -> unit

end

module Set: Functoria_misc.SET
(** A Set of keys. *)

type +'a value
(** Value available at configure time.
    Values have dependencies, which are a set of keys.

    Values are resolved to their content when all
    their dependencies are resolved.
*)

val pure: 'a -> 'a value
(** [pure x] is a value without any dependency. *)

val app: ('a -> 'b) value -> 'a value -> 'b value
(** [app f x] is the value resulting from the application of [f] to [v].
    Its dependencies are the union of the dependencies. *)

val ($): ('a -> 'b) value -> 'a value -> 'b value
(** [f $ v] is [app f v]. *)

val map: ('a -> 'b) -> 'a value -> 'b value
(** [map f v] is [pure f $ v]. *)

val pipe: 'a value -> ('a -> 'b) -> 'b value
(** [pipe v f] is [map f v]. *)

val if_: bool value -> 'a -> 'a -> 'a value
(** [if_ v x y] is [pipe v @@ fun b -> if b then x else y]. *)

val with_deps: keys:Set.t -> 'a value -> 'a value
(** [with_deps deps v] is the value [v] with added dependencies. *)

val default: 'a value -> 'a
(** [default v] returns the default value for [v]. *)

type 'a key
(** Keys are dynamic values that can be used to
    - Set options at configure and runtime on the command line.
    - Switch implementation dynamically, using {!Functoria_dsl.if_impl}.

    Their content is then made available at runtime in the [Bootvar_gen] module.

    Keys are resolved to their content during command line parsing.
*)

val value: 'a key -> 'a value
(** [value k] is the value which depends on [k] and will take its content. *)

type stage = [
  | `Configure
  | `Run
  | `Both
]
(** The stage at which a key is available.
    - [`Configure] means writable at configure time and readable at runtime.
    - [`Run] means writable and readable only at runtime
    - [`Both] means writable and readable at configure and run time.
*)

val create:
  ?stage:stage -> doc:Doc.t -> default:'a -> string -> 'a Conv.t -> 'a key
(** [create ~doc ~stage ~default name conv] creates a new
    configuration key with docstring [doc], default value [default],
    name [name] and type descriptor [desc]. Default [stage] is
    [`Both].  It is an error to use more than one key with the same
    [name]. *)

val flag: ?stage:stage -> doc:Doc.t -> string -> bool key
(** [flag ~stage ~doc name] creates a new flag. A flag is a key that doesn't
    take argument. The boolean value represents if the flag was passed
    on the command line.
*)

(** {3 Proxy} *)

(** Setters allow to set other keys. *)
module Setters: sig

  type 'a t

  val empty: 'a t
  (** The empty setter. *)

  val add: 'b key -> ('a -> 'b option) -> 'a t -> 'a t
  (** [add k f setters] Add a new setter to [setters].
      It will set [k] to the value generated by [f].
      If [f] returns [None], no value is set.
  *)

end

val proxy: doc:Doc.t -> setters:bool Setters.t -> string -> bool key
(** [proxy ~doc ~setters name] creates a new flag that will call [setters]
    when enabled.

    Proxies are only available during configuration.
*)

(** {2 Oblivious keys} *)

type t = Set.elt
(** Keys which types has been forgotten. *)

val hidden: 'a key -> t
(** Hide the type of keys. Allows to put them in a set/list. *)

(** {2 Advanced functions} *)

val pp: t Fmt.t
(** [pp fmt k] prints the name of [k]. *)

val pp_deps: 'a value Fmt.t
(** [pp_deps fmt v] prints the name of the dependencies of [v]. *)

val deps: 'a value -> Set.t
(** [deps v] is the dependencies of [v]. *)

val setters: t -> Set.t
(** [setters k] returns the set of keys for which [k] has a setter. *)

(** {3 Accessors} *)

val is_runtime: t -> bool
(** [is_runtime k] is true if [k]'s stage is [`Run] or [`Both]. *)

val is_configure: t -> bool
(** [is_configure k] is true if [k]'s stage is [`Configure] or [`Both]. *)

val filter_stage: stage:stage -> Set.t -> Set.t
(** [filter_stage ~stage set] filters [set] with the appropriate keys. *)

(** {3 Key resolution} *)

type map

val is_resolved: map -> 'a value -> bool
(** [is_reduced map v] returns [true] iff all the dependencies of [v] have
    been resolved. *)

val peek: map -> 'a value -> 'a option
(** [peek map v] returns [Some x] if [v] has been resolved to [x]
    and [None] otherwise. *)

val eval: map -> 'a value -> 'a
(** [eval map v] resolves [v], using default values if necessary. *)

val get: map -> 'a key -> 'a
(** [get map k] resolves [k], using default values if necessary. *)

val pp_map: map -> Set.t Fmt.t
(** [pp_map map fmt set] prints the keys in [set] with the values in [map]. *)

(** {3 Code emission} *)

val ocaml_name: t -> string
(** [ocaml_name k] is the ocaml name of [k]. *)

val emit_call: t Fmt.t
(** [emit_call fmt k] prints the OCaml code needed to get the value of [k]. *)

val emit: map -> t Fmt.t
(** [emit fmt k] prints the OCaml code needed to define [k]. *)


(** {3 Cmdliner} *)

val term: ?stage:stage -> Set.t -> map Cmdliner.Term.t
(** [term l] is a [Cmdliner.Term.t] that, when evaluated, sets the value of the
    the keys in [l]. *)

val term_value: ?stage:stage -> 'a value -> 'a Cmdliner.Term.t
(** [term_value v] is [term @@ deps v] and returns the content of [v]. *)

(**/**)

val module_name: string
(** Name of the generated module containing the keys. *)
