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



(** Node class, encapsulates most of the state and constituent objects
  (routing agent, mac layer, traffic source) that are in a node.

  @author Henri Dubois-Ferriere. 
*)




type node_state_t
    (** This type is used for storing node state to file *)

val state_pos : node_state_t -> Coord.coordf_t


(** Node: Encapsulates most of the state and constituent objects
  (routing agent, mac layer, traffic source) that model a node.

  {b On multiple stacks:}

  Some methods and functions have an optional [?stack] argument, allowing to
  indicate which stack is being used. This optional argument
  defaults to 0; therefore one need never specify it if running only one
  stack (and can hence can safely ignore this passage).

  We explain the notion of multiple stacks below:

  It is possible in nab to simultaneously run multiple protocol stacks on each
  node. These are completely oblivious to, and independent of, each
  other. Running multiple stacks can be helpful for example when comparing
  different routing protocols, parameters, MAC layers, or combinations
  thereof: instead of scripting as many simulation runs as configurations, and
  running them sequentially, it is possible to do them all together. This can
  remove quite some scripting hassle, and allows to be confident that each
  protocol is being presented with {i exactly} the same conditions in terms of
  mobility, traffic, etc.

  Using multiple stacks together can also be faster, since all the
  computations related to node mobility, computing node neighbors, etc (which
  can be quite CPU-intensive)  are done once only, rather than repeating
  these computations in as many separate runs.

  Note that since a stack includes the MAC layer, and since contention happens in
  the MAC layer, multiple stacks will not interfere with each other in terms
  of contention/collisions.

 *)
class node : Common.nodeid_t ->

object ('a)
  
  inherit Log.inheritable_loggable 

  method dump_state : node_state_t 
    
  method id : Common.nodeid_t

  (** Installing/removing components of a protocol stack. *)

  method install_mac : ?stack:int -> Mac.t -> unit
    (** Install a {!Mac.t} object in the given [stack] (stack 0 if not specified). *)

  method mac : ?stack:int -> unit -> Mac.t
    (** Returns the node's {!Mac.t} object from the given [stack] (stack 0 if not specified). *)

  method remove_mac : ?stack:int -> unit -> unit
    (** Remove {!Mac.t} from given [stack] (stack 0 if not specified). *)

  method install_rt_agent : ?stack:int -> Rt_agent.t -> unit
    (** Install a {!Rt_agent.t} object in the given [stack] (stack 0 if not specified). *)

  method agent : ?stack:int -> unit -> Rt_agent.t
    (** Returns the node's routing agent from the given [stack] (stack
      0 if not specified). Note that the routing agent is coerced to a
      {!Rt_agent.t}, so any additional methods than those in the {!Rt_agent.t}
      type are hidden. 
    *)
    
  method remove_rt_agent : ?stack:int -> unit -> unit
    (** Remove {!Rt_agent.t} from given [stack] (stack 0 if not specified). 
      Caution: may cause errors if you do this in the middle of a simulation,
      ie if there are outstanding events (e.g., sending a hello message) which
      will then arrive at a node where the routing agent to handle them has
      been removed.
    *)
    
  method remove_stack : ?stack:int -> unit -> unit
    (** Remove entire protocol stack [stack] (stack 0 if not specified). 
      Same note of caution applies for [remove_rt_agent].
    *)
    

  (** Sending/receiving packets. *)

  method set_trafficsource :  gen:Trafficgen.t ->  dst:Common.nodeid_t -> unit
    (** Installs a traffic source and uses it to generate application packets
      to node dst. 

      Multiple trafficsources to multiple destinations can be installed (XXX not
      tested though)
    *)

  method clear_trafficsources : unit -> unit
    (** Removes all trafficsources from this node. *)

  method mac_recv_pkt : ?stack:int -> L2pkt.t -> unit

  method mac_send_pkt : 
    ?stack:int -> 
    Common.nodeid_t -> 
    L3pkt.t ->  unit
    (** Send packet to neighboring node. *)

  method mac_bcast_pkt : ?stack:int -> L3pkt.t -> unit
    (** Broadcast packet to all neighbors. *)
    
  method originate_app_pkt : l4pkt:L4pkt.t -> dst:Common.nodeid_t -> unit
    (** Originates a packet from an application on this node to dst:
      create the packet and push it down the app_send_pkt_hooks *)

  method mac_send_failure : ?stack:int -> L2pkt.t -> unit
    (** A MAC implementation may call this method when  a unicast transmission
      fails. If and when a MAC layer detects a unicast transmission failure
      depends on the type of MAC. For example, a MACAW mac would call
      [unicast_failure] when the RTS/CTS/DATA/ACK cycle fails. Or a MACA mac,
      which does not have ACKs, will never call [unicast_failure]. 
      
      Note that in a typical IP over 802.11b stack, there is no such callback
      from the device driver to the IP layer when a packet transmission
      fails. So a simulation wanting to faithfully mimic the behavior of a
      IP over 802.11b device should consider ignoring these callbacks.
    *)

  (** Inserting hooks. *)
    
  method add_pktin_mhook : ?stack:int -> (L2pkt.t -> 'a -> unit) -> unit
    (** Any monitoring application can register here to see all packets entering
      the node.
      If multiple apps, order in which called is unspecified.*)
    
  method add_pktout_mhook : ?stack:int -> (L2pkt.t -> 'a -> unit) -> unit
    (** Any monitoring application can register here to see all packets leaving
      the node.
      If multiple apps, order in which called is unspecified.*)
    
  method clear_pkt_mhooks : ?stack:int -> unit -> unit 
    (** clears pktin and pktout mhooks *)

  method pos : Coord.coordf_t
    (** Returns the position of this node. *)

end
  
val max_nstacks : int

(**/**)  
    
    
    
