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


(** High-level GUI drawing operations *)


val draw_ler_route : 
  ?lines:bool ->
  ?anchors:bool ->
  ?disks:bool ->
  ?portion:float ->
  (Coord.coordi_t, Coord.coordi_t) Route.ler_route_t
  -> unit
  (** Draw LER route. 
    Optional arguments [lines] [anchors] [disks] specify respectively which
    information to represent. Default to [true].
    Optional argument [portion] (default 1.0) can indicate that only a first
    fraction of the route is to be drawn.
  *)


val draw_grep_route : 
  Coord.coordi_t Route.grep_route_t
  -> unit
  (** Draw grep route.  *)

val draw_tree :   ?col:GDraw.color ->          
  Coord.coordi_t NaryTree.t -> unit
  (** Draw a tree. *)

val draw_node :  
  ?emphasize:bool ->
  Common.nodeid_t -> 
  unit
  (** Draw a node. If optional [emphasize] is [true], node is highlighted
    (this is suitable for making the source and destination stand out, for
    example). *)  


val draw_nodes : 
  Common.nodeid_t list 
  -> unit
  (** Draw some nodes *)

val connect_nodes : 
  ?col:GDraw.color ->          
  (Common.nodeid_t * Common.nodeid_t)  list 
  -> unit
  (** Connect pairs of nodes. *)

val draw_connectivity : 
  unit -> unit
  (** Draw full connectivity mesh. *)

val draw_all_nodes : 
  unit ->
  unit
  (** Draw all nodes. *)

val user_pick_node : 
  ?msg:string ->
  node_picked_cb:(Common.nodeid_t -> unit)
  -> unit
  -> unit
  (** Ask the user to pick a node by clicking on the drawing area. 
    Once the user has picked, the provided callback [node_picked_cb] is called
    with the chosen nodeid as argument.
  *)

val dialog_pick_node : 
  ?default:Common.nodeid_t ->
  node_picked_cb:(Common.nodeid_t -> unit) ->
  unit ->
  unit
  (** Ask user for a node id via a dialog box. Checks that id is valid before
    accepting. If provided, optional parameter [default] will be displayed in 
    box. Once chosen, the provided callback [node_picked_cb] is called
    with the chosen nodeid as argument.
  *)
  

(**/**)

val draw_all_boxes : 
  unit ->
  unit

val draw_all_routes : 
  unit ->
  unit

