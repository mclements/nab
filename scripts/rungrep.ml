(*                                  *)
(* mws  multihop wireless simulator *)
(*                                  *)

(* ocaml unix.cma -I misc -I mws scripts/rungrep.ml 2> /tmp/log.out  *)

open Printf
open Misc
open Script_utils


type trafficmatrix = HOTSPOT  | BIDIR | UNIDIR

    
  let string_of_tmat tmat = 
    match tmat with 
      | HOTSPOT -> "hotspot "
      | BIDIR  -> "bidirectional"
      | UNIDIR -> "unidirectional"


let quickrun = [
  (*  repeats hotspot speed rate nodes srcs pktssend *)
  (2, UNIDIR,  0.0,  4,   100,  4,  20);
  (2, UNIDIR,  1.0,  4,   100,  4,  20);
  (2, UNIDIR,  2.0,  4,   100,  4,  20);
  (2, UNIDIR,  4.0,  4,   100,  4,  20);
]

let r1 = [
  (*  repeats hotspot speed rate nodes srcs pktssend *)
  (10, UNIDIR,  0.0,  4,   1000,  40,  20);
  (10, UNIDIR,  1.0,  4,   1000,  40,  20);
  (10, UNIDIR,  2.0,  4,   1000,  40,  20);
  (10, UNIDIR,  4.0,  4,   1000,  40,  20);
  (10, UNIDIR,  6.0,  4,   1000,  40,  20);
  (10, UNIDIR,  8.0,  4,   1000,  40,  20);
  (10, UNIDIR,  12.0,  4,   1000,  40,  20);
  (10, UNIDIR,  16.0, 4,   1000,  40,  20);
]

let r5 = [
  (* repeats hotspot speed rate nodes srcs pktssend *)
  (10, HOTSPOT,  0.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  1.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  2.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  4.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  6.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  8.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  12.0,  4,   1000,  40,  20);
  (10, HOTSPOT,  16.0,  4,   1000,  40,  20);
]

let r6 = [
  (* repeats hotspot speed rate nodes srcs pktssend *)
  (10, BIDIR,  0.0,  4,   1000,  40,  20);
  (10, BIDIR,  1.0,  4,   1000,  40,  20);
  (10, BIDIR,  2.0,  4,   1000,  40,  20);
  (10, BIDIR,  4.0,  4,   1000,  40,  20);
  (10, BIDIR,  6.0,  4,   1000,  40,  20);
  (10, BIDIR,  8.0,  4,   1000,  40,  20);
  (10, BIDIR,  12.0,  4,   1000,  40,  20);
  (10, BIDIR,  16.0,  4,   1000,  40,  20);
]  


let r2 = [
(* repeats hotspot speed rate nodes srcs pktssend *)
  (10, UNIDIR,  0.0,  4,   1000,  1,  200);
  (10, UNIDIR,  1.0,  4,   1000,  1,  200);
  (10, UNIDIR,  4.0,  4,   1000,  1,  200);
  (10, UNIDIR,  8.0,  4,   1000,  1,  200);
]

let r4 = [
(* repeats hotspot speed rate nodes srcs pktssend *)
  (10, BIDIR,  0.0,  4,   1000,  1,  200);
  (10, BIDIR,  1.0,  4,   1000,  1,  200);
  (10, BIDIR,  4.0,  4,   1000,  1,  200);
  (10, BIDIR,  8.0,  4,   1000,  1,  200);
]


let r3 = [
  (* repeats hotspot speed rate nodes srcs pktssend *)
  (10, HOTSPOT,  8.0,  4,   50,  40,  20);
  (10, HOTSPOT,  8.0,  4,   100,  40,  20);
  (10, HOTSPOT,  8.0,  4,   200,  40,  20);
  (10, HOTSPOT,  8.0,  4,   400,  40,  20);
  (10, HOTSPOT,  8.0,  4,   600,  40,  20);
  (10, HOTSPOT,  8.0,  4,   800,  40,  20);
  (10, HOTSPOT,  8.0,  4,   1000,  40,  20);
]  

let r7 = [
(* repeats hotspot speed rate nodes srcs pktssend *)
  (1, UNIDIR,  12.0,  4,   200,  10,  10);
]



let () = 

  List.iter 
    (fun (repeats, tmat, sp, rate, nodes, srcs, pktssend) ->
      for i = 1 to repeats do 

	  let s = 
	    Printf.sprintf 
	      "bin/mws -pktssend %d -speed %f -loglevel info -mac null -nodes %d -sources %d -tmat %s -rate %d -agent aodv -run %d"
	      pktssend
	      sp
	      nodes
	      srcs
	      (string_of_tmat tmat)
	      rate
	      i
	  in
	  print_endline s;
	  flush stdout;
	  ignore (Sys.command s);
	  let s = 
	    Printf.sprintf 
	      "bin/mws -pktssend %d -speed %f -loglevel info -mac null -nodes %d -sources %d -tmat %s -rate %d -agent aodv -run %d"
	      pktssend
	      sp
	      nodes
	      srcs
	      (string_of_tmat tmat)
	      rate
	      i
	  in
	  print_endline s;
	  flush stdout;
	  ignore (Sys.command s)


	done
    ) r5
    
  