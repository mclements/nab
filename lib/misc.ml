(*
 *
 *  NAB - Network in a Box
 *  Henri Dubois-Ferriere, LCA/LCAV, EPFL
 * 
 *  Copyright (C) 2004 Laboratory of Audiovisual Communications (LCAV), and
 *  Laboratory for Computer Communications and Applications (LCA), 
 *  Ecole Polytechnique Federale de Lausanne (EPFL),
 *  CH-1015 Lausanne, Switzerland
 *
 *  This file is part of NAB. NAB is free software; you can redistribute it 
 *  and/or modify it under the terms of the GNU General Public License as 
 *  published by the Free Software Foundation; either version 2 of the License,
 *  or (at your option) any later version. 
 *
 *  NAB is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 *  details (enclosed in the file GPL). 
 *
 *)

(* $Id$ *)



(** Miscellaneous stuff that is useful everywhere *)

open Printf

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **)
(*                                                                                     **)
(* Shorthands                                                                          **)
(*                                                                                     **)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * **)



(** Type converters. *)

let i2f i = float_of_int i
let f2i f = int_of_float f
let int = int_of_float
let char = char_of_int

let s2i s = int_of_string s
let s2f s = float_of_string s

let i2s i = string_of_int i
let f2s f = string_of_float f


(** Arithmetic and related. *)

let (+=) a b = a := !a + b
let (-=) a b = a := !a - b
let (+=.) a b = a := !a +. b
let (-=.) a b = a := !a -. b

(* xor *)
let (|||) a b = (a || b) && not (a && b)

let isint x = (floor x) = x
let round x = if (x -. floor x) < 0.5 then (floor x) else (ceil x)

let powi ~num ~exp = f2i ((i2f num) ** (i2f exp))
let nth_root ~num ~n = f2i (num ** (1.0/.(i2f n)))

let sign x = if x < 0.0 then (-1.0) else (1.0)
let signi x = if x < 0 then (-1) else (1)

let ispower ~pow ~num = isint ((i2f num) ** (1.0 /. i2f pow))
let issquare = ispower ~pow:2

let ininterval ~num ~left ~right = (num >=left) && num <= right

let norm a = let n = ref 0.0 in Array.iter (fun x -> n := !n +. (x ** 2.0)) a; sqrt !n
let normdot a = let n = ref 0.0 in Array.iter (fun x -> n := !n +. ((i2f x) ** 2.0)) a; sqrt !n

let id x = x
let const x = fun _ -> x

let facto n = 
  let rec tailrec x n = 
    match x with
      | 0 -> n
      | _ -> tailrec (x - 1) (x * n)
  in
  tailrec n 1

let binomial ~pick ~outof = (facto outof) / ((facto pick)  * (facto (outof - pick)))

let facto_f n = 
  let rec tailrec x n = 
    match x with
      | 0. -> n
      | _ -> tailrec (x -. 1.) (x *. n)
  in
  tailrec n 1.

let binomial_f ~pick ~outof = (facto_f outof) /. ((facto_f pick)  *. (facto_f (outof -. pick)))

let pi = 4. *. atan 1.

let rad2deg rad = (rad /. pi) *. 180.

let qfunct z =
  1. /. 2. *. (1. -. Gsl_sf.erf(z /. (sqrt 2.)))



let is_finite x =
  let cx = classify_float x in
  cx <> FP_infinite && cx <> FP_nan

let isin value (left, right) = value >= left && value <= right

let minus flt = 0. -. flt

let expo ~rand ~lambda = minus (log (1. -. rand))/.lambda
  (** Turn a uniform [0,1] r.v into an exponential RV of mean 1/lambda *)


(**  Lists *)

let rec range a b =
  if a > b then []
  else a :: range (a+1) b

let listlast l = List.nth l (List.length l - 1)
  
let rnd_from_list l = List.nth l (Random.int (List.length l))
  
let list_same l1 l2 = (List.sort compare l1 = List.sort compare l2) 

let list_without l el = List.filter (fun x -> x <> el) l
			  
let list_unique_elements l = 
  let hash = Hashtbl.create (List.length l) in
  List.iter (fun x -> Hashtbl.replace hash x "") l;
  Hashtbl.fold (fun key _ list -> key :: list ) hash []

let list_count_element ~l ~el = List.length (List.filter (fun x -> x = el) l)
let list_count_int ~l el:int = List.length (List.filter (fun (x:int) -> (x = el)) l)

let sprintlist ~fmt:fmt ~l:l = List.fold_left (fun a b -> a ^ (Printf.sprintf fmt b)) "" l
let printlist ~fmt:fmt ~l:l = Printf.printf "%s" (sprintlist ~fmt:fmt ~l:l)


(**  Arrays *)

let array_f2i a = Array.map (fun x -> f2i x ) a
let array_i2f a = Array.map (fun x -> i2f x ) a

(* copied from array.mli
   val iteri : (int -> 'a -> unit) -> 'a array -> unit 
   val iter : ('a -> unit) -> 'a array -> unit *)
let array_rev_iteri f a = 
  for i = Array.length a - 1 downto 0 do f i (Array.unsafe_get a i) done

let array_rev_iter f a = 
  for i = Array.length a - 1 downto 0 do f (Array.unsafe_get a i) done


let mapi2 f arr1 arr2 = Array.mapi (fun i v -> f v arr2.(i)) arr1
let (|+|) = mapi2 (+)
let (|+.|) = mapi2 (+.)

let int_of_bool = function true -> 1 | false -> 0

let array_mem arr v = Array.fold_left 
  (fun boolean item -> boolean || (item = v)) 
  false
  arr

(* count the number of elements e for which (f e) is true *)
let array_count_filt f a = Array.fold_left 
  (fun c item -> c + int_of_bool (f item)) 
  0
  a


(* val array_count : 'a -> 'a array -> int = <fun> *)
let array_count elt a = array_count_filt (fun x -> x = elt) a

let array_same a1 a2 = list_same (Array.to_list a1) (Array.to_list a2)

let sprintarr ~fmt:fmt ~l:l = Array.fold_left (fun a b -> a ^ (Printf.sprintf fmt b)) "" l
let printarr ~fmt:fmt ~l:l = Printf.printf "%s" (sprintarr ~fmt:fmt ~l:l)

(**  Iterators *)

let matrix_iter f m = 
  let iter_row r = Array.iter f r in
    Array.iter iter_row m

let repeat n f = begin
  let ctr = ref 0 in 
    while (!ctr < n) do f (); incr ctr  done;
end

let foreach l f = List.iter f l    

(**  Options *)

let o2v = function 
    None -> raise (Failure "Misc.o2v : None")
  | Some v -> v
      (** Deprecated. Use functions from the Opt module in lib/contrib.*)

(** Hashes *)

let hash_tuple_list h = 
  Hashtbl.fold (fun k v l -> (k, v)::l) h []

let hash_values h = 
  Hashtbl.fold (fun _ v l -> v::l) h []

let hash_keys h = 
  Hashtbl.fold (fun k _ l -> k::l) h []

let hashlen h = Hashtbl.fold (fun _ _ l -> l + 1) h 0


(** Error Handling and Exceptions *)


exception Impossible_Case of string
exception Not_Implemented
exception Break
exception BreakInt of int (* afaik can't have polymorphic exceptions .. *)

exception Fatal of string
exception Transient of string

let equal_or_print a b ~equal ~print =
  if not (equal a b) then (
    print a;
    print b;
    false
  ) else true
	

(** Random *)
let wait_for_line() = (
  Printf.printf "Press enter to continue...\n" ; 
  flush stdout;
  ignore (read_line())
)
  
(** String Handling *)
  
let padto ?(ch=' ') s len = 
  let l = len - (String.length s) in 
  if l <= 0 then s else s ^ String.make l ch
    
let chopper = (Str.regexp "[ \t]+$")
  
let chop s = Str.global_replace chopper "" s

let slashify s = if (Mods.String.last s) = '/' then s else s^"/"


(** I/O *)

let for_stdin_lines f = 
  try (while true do (f (input_line stdin)) done) with End_of_file -> ()

let for_channel_lines chan f = 
  try (while true do (f (input_line chan)) done) with End_of_file -> ()

let lines_of_chan chan = 
  begin 
    let accum = ref [] in for_channel_lines chan (fun ss -> accum := ss ::
      !accum); 
    List.rev !accum; 
  end

let lines_of_file fname = 
  begin 
    let accum = ref [] in 
    let infile = open_in fname in 
    begin
      for_channel_lines infile (fun ss -> accum := ss :: !accum); 
      close_in infile; 
      List.rev !accum; 
    end 
  end

let file_map_list fname f = 
  begin 
    let accum = ref [] in 
    let infile = open_in fname in 
    begin
      for_channel_lines infile (fun ss -> accum := ss :: !accum); 
      close_in infile; 
      List.rev_map f !accum; 
    end 
  end

let list_to_chan chan l = 
  List.iter (output_string chan) l

let list_to_chan_endline chan l = 
  List.iter (fun line -> output_string chan (line^"\n")) l

let file_map_array fname f = 
  Array.of_list (file_map_list fname f)

let dirstack = Stack.create()
let pushd dir = 
  let curdir = Sys.getcwd() in  
  Sys.chdir dir; 
  Stack.push curdir dirstack 
let popd () = let dir = Stack.pop dirstack in Sys.chdir dir


let command_output cmd = 
  let name = Filename.temp_file "" "" in
  let status = Sys.command (cmd^" > "^name) in
  status, lines_of_file name



(** Common Functorized modules. *)

module OrderedType = 
  struct
    type t 
    let compare = Pervasives.compare
  end

module SimpleSet = Set.Make(OrderedType)


