(*

  Copyright (C) 2004 Swiss Federal Institute of Technology Lausanne (EPFL),
  Laboratory of Audiovisual Communications (LCAV) and 
  Laboratory for Computer Communications and Applications (LCA), 
  CH-1015 Lausanne, Switzerland

  Author: Henri Dubois-Ferriere 

  This file is part of mws (multihop wireless simulator).

  Mws is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.
  
  Mws is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with mws; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


*)







open Printf
open Misc
open Script_utils

type trafficmatrix = HOTSPOT  | BIDIR | UNIDIR
type agent_type = AODV | GREP

module Config = 
struct
  let agent_of_string = function
    | "aodv" | "AODV" -> AODV
    | "grep" | "GREP" -> GREP
    | _ -> raise (Failure "Invalid format for agent type")

  let agent = Param.stringcreate
    ~name:"agent"
    ~cmdline:true
    ~default:"grep"
    ~doc:"Routing protocol"
    ~checker:(fun s -> ignore (agent_of_string s))
    ()

  let string_of_tmat tmat = 
    match tmat with 
      | HOTSPOT -> "hotspot "
      | BIDIR  -> "bidirectional"
      | UNIDIR -> "unidirectional"

  let tmat_of_string tmat = 
    match (String.lowercase tmat) with 
      | "hotspot" | "hot" -> HOTSPOT
      | "bidirectional" | "bi" | "bidir" -> BIDIR  
      | "unidirectional" | "uni" | "unidir" -> UNIDIR  
      | _ -> raise (Failure "Invalid format for traffic type")

  let tmat = 
    Param.stringcreate  ~name:"tmat" ~default:"Hotspot" 
      ~cmdline:true
      ~doc:"Traffic Type" ~checker:(fun s -> ignore (tmat_of_string s))
      ()

  let sources = 
    Param.intcreate  ~name:"sources" ~default:1
      ~cmdline:true
      ~doc:"Number of sources"  ()
      
  let run = Param.intcreate ~name:"run" ~default:1
    ~cmdline:true
    ~doc:"Run number" ()

  let packet_rate = 
    Param.floatcreate ~name:"rate" ~default:4.
      ~cmdline:true
      ~doc:"Orig rate [pkt/s]"  ()

  let speed = 
    Param.floatcreate ~name:"speed" 
      ~cmdline:true
      ~default:8.0
      ~doc:"Node Speed [m/s]"  ()

  let pktssend = 
    Param.intcreate ~name:"pktssend" 
      ~cmdline:true
      ~doc:"Packets originated"  ()

    
end


let install_tsources () = 
  let sources = (Param.get Config.sources) in
  let rndstream = Random.State.copy (Random.get_state()) in

  Nodes.iter (fun n ->
    if (n#id < sources) then (
      let dst = 
	match Config.tmat_of_string (Param.get Config.tmat) with
	  | HOTSPOT -> ((Param.get Params.nodes)  - 1 )
	  | UNIDIR -> (((Param.get Params.nodes)  - 1 ) - n#id)
	  | BIDIR -> (sources - n#id)
      in
      if (dst <> n#id) then (
	(* in case we have n nodes, n sources, then the n/2'th node would have
	   itself as destination*)
	let pkt_reception() = 
	  n#set_trafficsource 
	    ~gen:(Tsource.make_cbr
	      ~pkts_per_sec:(Param.get Config.packet_rate)
	      ()
	    )
	    ~dst 
	in
	(* start sessions jittered out over an interval equivalent to the
	   inter-packet interval *)
	let t = Random.State.float rndstream  (1. /. (Param.get Config.packet_rate)) in
	(Sched.s())#sched_in ~f:pkt_reception ~t;
      )
    )
  )
